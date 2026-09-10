import 'dart:convert';
import 'dart:io';
import 'package:crypto/crypto.dart';
import 'package:cryptography/cryptography.dart';
import 'session_persistence.dart';
import 'package:path/path.dart' as p;
import 'package:psychemas/psychemas.dart';
import 'package:psyconfig/psyconfig.dart';
import 'api_client.dart';
import 'secure_storage.dart';
import 'signed_receipt_queue.dart';

/// Account-bound structured outbox. Acknowledgment, feedback, and profile cache
/// share the same atomic snapshot. No transcript or credential enters this file.
class DurableQueuePersistence implements QueuePersistence {
  DurableQueuePersistence(
      {required this.directory,
      required this.accountId,
      required this.storage,
      this.maxEntries = 10000,
      this.maxBytes = 524288,
      NetworkConfig? network})
      : network = network ?? loadConfig(environment: 'prod').network {
    if (accountId.isEmpty || maxEntries < 1 || maxBytes < 1) {
      throw ArgumentError('Invalid outbox bounds');
    }
  }
  final Directory directory;
  final SecretStorage storage;
  final NetworkConfig network;
  final _cipher = AesGcm.with256bits();
  final String accountId;
  final int maxEntries, maxBytes;
  String get _name => sha256.convert(utf8.encode(accountId)).toString();
  @override
  String get scope =>
      p.normalize(p.absolute(directory.path, 'online', '$_name.json'));
  File get _file => File(scope);

  Future<T> _transaction<T>(
          Future<T> Function(Map<String, Object?> state) operation,
          {bool write = false,
          bool Function()? canCommit}) =>
      SerialOperations.run(scope, () async {
        final parent = _file.parent;
        await parent.create(recursive: true);
        if (await parent.resolveSymbolicLinks() !=
            p.normalize(p.absolute(parent.path))) {
          throw const FileSystemException(
              'Symlinked outbox directory is not supported');
        }
        for (final path in [scope, '$scope.lock']) {
          if (await FileSystemEntity.type(path, followLinks: false) ==
              FileSystemEntityType.link) {
            throw const FileSystemException(
                'Symlinked outbox file is not supported');
          }
        }
        final lock = await File('$scope.lock').open(mode: FileMode.append);
        var locked = false;
        try {
          await lock.lock(FileLock.blockingExclusive);
          locked = true;
          Map<String, Object?> state = {
            'version': 1,
            'account_id': accountId,
            'entries': <Object?>[],
            'verdicts': <Object?>[]
          };
          if (await _file.exists()) {
            if (await _file.length() > ((maxBytes + 16) * 4 ~/ 3) + 512) {
              throw const FormatException('Outbox exceeds configured bound');
            }
            final blob =
                jsonDecode(await _file.readAsString()) as Map<String, Object?>;
            if (blob['version'] != 1 || blob['algorithm'] != 'aes-256-gcm') {
              throw const FormatException('Unsupported encrypted outbox');
            }
            final plaintext = await _cipher.decrypt(
                SecretBox(base64Decode(blob['ciphertext'] as String),
                    nonce: base64Decode(blob['nonce'] as String),
                    mac: Mac(base64Decode(blob['mac'] as String))),
                secretKey: await _encryptionKey(create: false),
                aad: _aad);
            if (plaintext.length > maxBytes) {
              throw const FormatException('Outbox exceeds configured bound');
            }
            state = jsonDecode(utf8.decode(plaintext)) as Map<String, Object?>;
            if (state['version'] != 1 ||
                state['account_id'] != accountId ||
                state['entries'] is! List ||
                state['verdicts'] is! List) {
              throw const FormatException('Invalid account outbox');
            }
          }
          for (final raw in state['entries'] as List) {
            final entry = QueueEntry.fromJson(raw as Map<String, Object?>);
            if (_validatedReceipt(entry.envelope).idempotencyKey != entry.id) {
              throw const FormatException('Invalid outbox identity');
            }
          }
          final projectedVerdicts = <Map<String, Object?>>[];
          for (final raw in state['verdicts'] as List) {
            final json = raw as Map<String, Object?>;
            final hash = wireString(json, 'envelope_hash', max: 64);
            if (!RegExp(r'^[0-9a-f]{64}$').hasMatch(hash)) {
              throw const FormatException('Invalid verdict envelope hash');
            }
            projectedVerdicts.add({
              ...ReceiptVerdict.fromJson(json).toJson(),
              'envelope_hash': hash
            });
          }
          if (jsonEncode(projectedVerdicts) != jsonEncode(state['verdicts'])) {
            state['verdicts'] = projectedVerdicts;
            write = true;
          }
          if (state['profile'] != null) {
            final old = state['profile'] as Map<String, Object?>;
            final projected = wireProfile(old);
            if (jsonEncode(old) != jsonEncode(projected)) {
              state['profile'] = projected;
              write =
                  true; // Remove unknown legacy profile fields on first read.
            }
          }
          if (state['pending_start'] != null) {
            _validatedPendingStart(
                state['pending_start'] as Map<String, Object?>);
          }
          final result = await operation(state);
          if (write && (canCommit == null || canCommit())) {
            final bytes = utf8.encode(jsonEncode(state));
            if (bytes.length > maxBytes) {
              throw StateError('Outbox is full; sync before another session');
            }
            final sealed = await _cipher.encrypt(bytes,
                secretKey: await _encryptionKey(create: true), aad: _aad);
            final ciphertext = jsonEncode({
              'version': 1,
              'algorithm': 'aes-256-gcm',
              'nonce': base64Encode(sealed.nonce),
              'mac': base64Encode(sealed.mac.bytes),
              'ciphertext': base64Encode(sealed.cipherText)
            });
            final temp = File('$scope.${ApiClient.newId("tmp")}');
            await temp.create(exclusive: true);
            try {
              await temp.writeAsString(ciphertext, flush: true);
              if (canCommit == null || canCommit()) await temp.rename(scope);
            } finally {
              if (await temp.exists()) await temp.delete();
            }
          }
          return result;
        } finally {
          try {
            if (locked) await lock.unlock();
          } finally {
            await lock.close();
          }
        }
      });
  List<int> get _aad => utf8.encode('psychosims.outbox.v1:$scope:$accountId');
  Future<SecretKey> _encryptionKey({required bool create}) async {
    final name = 'outbox-key.$_name';
    var encoded = await storage.read(name);
    if (encoded == null) {
      if (!create) throw StateError('Secure outbox key is unavailable');
      final key = await _cipher.newSecretKey();
      encoded = base64Encode(await key.extractBytes());
      await storage.write(name, encoded);
    }
    final bytes = base64Decode(encoded);
    if (bytes.length != 32) throw const FormatException('Invalid outbox key');
    return SecretKey(bytes);
  }

  /// Reject unrecognized fields before preserving the original signed bytes.
  /// Parsing and silently dropping a dialogue field would still leak it on disk.
  SessionReceipt _validatedReceipt(SignedEnvelope envelope) {
    if (envelope.canonicalReceiptBytes.length >
        network.maxCanonicalReceiptBytes) {
      throw const FormatException('Receipt exceeds configured byte bound');
    }
    final wire = utf8.decode(envelope.canonicalReceiptBytes);
    final json = jsonDecode(wire) as Map<String, Object?>;
    final receipt = SessionReceipt.fromJson(json);
    final known = receipt.toJson();
    if (json.keys.any((key) => !known.containsKey(key)) ||
        CanonicalJson.encodeString(json) != wire) {
      throw const FormatException(
          'Receipt contains unknown or noncanonical fields');
    }
    for (final key in [
      'id',
      'patient_id',
      'idempotency_key',
      'correlation_id',
      'ruleset_version'
    ]) {
      wireIdentifier(json, key);
    }
    wireIdentifier({'key': envelope.signingKeyId}, 'key');
    if (receipt.schemaVersion != SessionReceipt.currentSchemaVersion ||
        receipt.actions.length > network.maxReceiptActions ||
        receipt.turnCount != receipt.actions.length ||
        receipt.deltas.length > network.maxReceiptDeltas ||
        receipt.ledgerEvents.isNotEmpty) {
      throw const FormatException('Invalid structured receipt bounds');
    }
    for (final delta in receipt.deltas) {
      wireIdentifier({'reason': delta.reasonKey}, 'reason');
      if (delta.rulesetVersion != receipt.rulesetVersion ||
          delta.deltaMillis < -1000 ||
          delta.deltaMillis > 1000) {
        throw const FormatException('Invalid structured delta');
      }
    }
    if (receipt.startState.isNotEmpty) {
      validateWireStartState(receipt.startState);
    }
    if (CanonicalJson.encodeString(known) != CanonicalJson.encodeString(json)) {
      throw const FormatException('Receipt contains unknown nested fields');
    }
    return receipt;
  }

  @override
  Future<String?> get cursor =>
      _transaction((s) async => s['cursor'] as String?);
  @override
  Future<List<ReceiptVerdict>> get verdicts =>
      _transaction((s) async => List.unmodifiable((s['verdicts'] as List)
          .map((v) => ReceiptVerdict.fromJson(v as Map<String, Object?>))));
  @override
  Future<List<QueueEntry>> readAfter(String? cursor) => _transaction((s) async {
        final entries = (s['entries'] as List)
            .map((e) => QueueEntry.fromJson(e as Map<String, Object?>))
            .toList();
        // Resolved entries are compacted atomically; the durable cursor is a receipt
        // tombstone, not an index into a mutable list.
        return List.unmodifiable(entries);
      });
  @override
  Future<void> append(QueueEntry entry) => _transaction((s) async {
        final incoming = _validatedReceipt(entry.envelope);
        if (entry.id != incoming.idempotencyKey) {
          throw StateError('Outbox identity mismatch');
        }
        final entries = s['entries'] as List;
        final verdicts = s['verdicts'] as List;
        final digest = sha256
            .convert(utf8.encode(jsonEncode(entry.envelope.toJson())))
            .toString();
        for (final raw in entries) {
          final existing = QueueEntry.fromJson(raw as Map<String, Object?>);
          if (existing.id != entry.id) continue;
          if (jsonEncode(existing.envelope.toJson()) !=
              jsonEncode(entry.envelope.toJson())) {
            throw StateError('Conflicting receipt identity');
          }
          return;
        }
        for (final raw in verdicts) {
          final verdict = raw as Map<String, Object?>;
          if (verdict['idempotency_key'] != entry.id) continue;
          if (verdict['envelope_hash'] != digest) {
            throw StateError('Conflicting resolved receipt identity');
          }
          return;
        }
        if (entries.length + verdicts.length >= maxEntries) {
          throw StateError('Outbox history limit reached');
        }
        entries.add(entry.toJson());
      }, write: true);
  @override
  Future<void> resolve(String id, ReceiptVerdict verdict) =>
      _transaction((s) async {
        final entries = s['entries'] as List;
        if (entries.isEmpty) throw StateError('No pending receipt');
        final entry =
            QueueEntry.fromJson(entries.first as Map<String, Object?>);
        final receipt = SessionReceipt.fromJson(
            jsonDecode(utf8.decode(entry.envelope.canonicalReceiptBytes))
                as Map<String, Object?>);
        if (entry.id != id ||
            verdict.idempotencyKey != id ||
            verdict.id != receipt.id ||
            verdict.retryable ||
            verdict.status == 'retryable') {
          throw StateError(
              'Cannot acknowledge unresolved or out-of-order receipt');
        }
        (s['verdicts'] as List).add({
          ...ReceiptVerdict.fromJson(verdict.toJson()).toJson(),
          'envelope_hash': sha256
              .convert(utf8.encode(jsonEncode(entry.envelope.toJson())))
              .toString()
        });
        entries.removeAt(0);
        s['cursor'] = id;
        if (verdict.profileVersion != null) {
          final previous = s['required_profile_version'] as int? ?? 0;
          if (verdict.profileVersion! > previous) {
            s['required_profile_version'] = verdict.profileVersion;
          }
        }
      }, write: true);
  @override
  Future<void> advanceCursor(String id) async {
    final entries = await readAfter(await cursor);
    if (entries.isEmpty || entries.first.id != id) {
      throw StateError('Cursor must advance contiguously');
    }
    final receipt = SessionReceipt.fromJson(
        jsonDecode(utf8.decode(entries.first.envelope.canonicalReceiptBytes))
            as Map<String, Object?>);
    await resolve(
        id,
        ReceiptVerdict(
            id: receipt.id,
            idempotencyKey: id,
            status: 'accepted',
            rewardStatus: 'held_unproven'));
  }

  Future<Map<String, Object?>?> get pendingStart =>
      _transaction((s) async => s['pending_start'] == null
          ? null
          : immutableWireMap(s['pending_start'] as Map<String, Object?>));
  Future<void> savePendingStart(Map<String, Object?> request) =>
      _transaction((s) async {
        s['pending_start'] = _validatedPendingStart(request);
      }, write: true);
  Map<String, Object?> _validatedPendingStart(Map<String, Object?> request) {
    if (request.keys.any((key) => !{
          'case_id',
          'card_ids',
          'request_id',
          'authorization'
        }.contains(key))) {
      throw const FormatException('Unknown pending start fields');
    }
    final validated = <String, Object?>{
      'case_id': wireIdentifier(request, 'case_id'),
      'card_ids': wireIdentifiers(request, 'card_ids', max: 6),
      'request_id': wireIdentifier(request, 'request_id')
    };
    if (request['authorization'] != null) {
      final raw = request['authorization'] as Map<String, Object?>;
      final permit = SessionAuthorization.fromJson(raw);
      if (raw.keys.any((key) => !permit.toJson().containsKey(key))) {
        throw const FormatException('Unknown authorization fields');
      }
      validated['authorization'] = permit.toJson();
    }
    return immutableWireMap(validated);
  }

  Future<void> retireDeniedStart(String requestId) => _transaction((s) async {
        final pending = s['pending_start'] as Map<String, Object?>?;
        if (pending?['request_id'] == requestId &&
            pending?['authorization'] == null) {
          s.remove('pending_start');
        }
      }, write: true);
  Future<void> retireStart(String permitId) => _transaction((s) async {
        final pending = s['pending_start'] as Map<String, Object?>?;
        final permit = pending?['authorization'] as Map<String, Object?>?;
        if (permit?['id'] == permitId) {
          s.remove('pending_start');
          s.remove('checkpoint');
        }
      }, write: true);
  Future<Map<String, Object?>?> get cachedProfile =>
      _transaction((s) async => s['profile'] == null
          ? null
          : immutableWireMap(s['profile'] as Map<String, Object?>));
  Future<String?> get profileEtag => _transaction((s) async {
        final current =
            (s['profile'] as Map<String, Object?>?)?['version'] as int?;
        final required = s['required_profile_version'] as int? ?? 0;
        return current == null || current < required
            ? null
            : s['profile_etag'] as String?;
      });
  Future<bool> get profileCurrent => _transaction((s) async {
        final current =
            (s['profile'] as Map<String, Object?>?)?['version'] as int?;
        return current != null &&
            current >= (s['required_profile_version'] as int? ?? 0);
      });
  Future<SessionCheckpoint?> get checkpoint =>
      _transaction((s) async => s['checkpoint'] == null
          ? null
          : SessionCheckpoint.fromJson(
              s['checkpoint'] as Map<String, Object?>));
  Future<void> saveCheckpoint(SessionCheckpoint checkpoint,
          {bool Function()? canCommit}) =>
      _transaction((s) async {
        s['checkpoint'] = checkpoint.toJson();
      }, write: true, canCommit: canCommit);
  Future<void> clearCheckpoint({bool Function()? canCommit}) =>
      _transaction((s) async {
        s.remove('checkpoint');
      }, write: true, canCommit: canCommit);
  Future<void> cacheProfile(Map<String, Object?> profile, String? etag) =>
      _transaction((s) async {
        final version = profile['version'];
        final previous =
            (s['profile'] as Map<String, Object?>?)?['version'] as int? ?? 0;
        final requiredVersion = s['required_profile_version'] as int? ?? 0;
        if (profile['account_id'] != accountId ||
            version is! int ||
            version < previous ||
            version < requiredVersion) {
          throw StateError('Profile is stale or belongs to another account');
        }
        final projected = wireProfile(profile);
        if (etag != null &&
            (etag.length > 128 ||
                !RegExp(r'^[A-Za-z0-9_.:"/\-]+$').hasMatch(etag))) {
          throw const FormatException('Invalid profile ETag');
        }
        s['profile'] = projected;
        s['profile_etag'] = etag;
        s['profile_fetched_at'] = DateTime.now().toUtc().toIso8601String();
      }, write: true);
}

/// Online checkpoints share the encrypted, account-bound atomic snapshot.
class EncryptedSessionPersistence extends SessionPersistenceService {
  EncryptedSessionPersistence(this.outbox) : super(directory: outbox.directory);
  final DurableQueuePersistence outbox;
  @override
  Future<void> save(SessionCheckpoint checkpoint,
          {bool Function()? canCommit}) =>
      outbox.saveCheckpoint(checkpoint, canCommit: canCommit);
  @override
  Future<SessionCheckpoint?> load() => outbox.checkpoint;
  @override
  Future<void> clear({bool Function()? canCommit}) =>
      outbox.clearCheckpoint(canCommit: canCommit);
}
