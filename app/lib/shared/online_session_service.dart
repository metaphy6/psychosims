import 'dart:convert';
import 'dart:io';
import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:psychemas/psychemas.dart';
import 'package:psyconfig/psyconfig.dart';
import 'api_client.dart';
import 'auth_service.dart';
import 'device_key_store.dart';
import 'durable_queue_persistence.dart';
import 'secure_storage.dart';
import 'session_persistence.dart';
import 'signed_receipt_queue.dart';

class OnlineSessionContext {
  const OnlineSessionContext(
      {required this.accountId, required this.authorization});
  final String accountId;
  final SessionAuthorization authorization;
}

class OnlineSyncStatus {
  const OnlineSyncStatus(
      {this.accountId,
      this.pending = 0,
      this.verdicts = const [],
      this.errorKind,
      this.syncing = false,
      this.profile,
      this.stale = true});
  final String? accountId, errorKind;
  final int pending;
  final List<ReceiptVerdict> verdicts;
  final bool syncing, stale;
  final Map<String, Object?>? profile;
}

/// Connects only server-issued permits to the signed outbox. Offline practice
/// has no entry path into this service and never earns authoritative rewards.
class OnlineSessionService {
  OnlineSessionService(
      {required this.auth, required this.directory, required this.network});
  final AuthService auth;
  final Directory directory;
  final NetworkConfig network;
  final status = ValueNotifier<OnlineSyncStatus>(const OnlineSyncStatus());
  DurableQueuePersistence outbox(String account) => DurableQueuePersistence(
      directory: _accountDirectory,
      accountId: account,
      storage: auth.storage,
      network: network,
      maxBytes: network.maxQueueBytes,
      maxEntries: network.maxQueueEntries);
  SecureDeviceKeyStore keys(String account) => SecureDeviceKeyStore(
      accountId: account,
      storage: auth.storage,
      recover: (public, id, replaces) async => (await auth.authenticated(
                  'POST', '/v1/device-keys/recover',
                  accountId: account,
                  idempotencyKey: id,
                  body: {
                'public_key': base64Encode(public),
                'suite_id': 'ed25519-v1',
                'platform': Platform.operatingSystem,
                'replaces_key_id': replaces
              }))
              .body,
      certify: (public, id) async => (await auth.authenticated(
                  'POST', '/v1/device-keys',
                  accountId: account,
                  idempotencyKey: id,
                  body: {
                'public_key': base64Encode(public),
                'suite_id': 'ed25519-v1',
                'platform': Platform.operatingSystem
              }))
              .body);
  Directory get _accountDirectory => Directory(p.join(
      directory.path,
      'control-plane',
      sha256
          .convert(utf8.encode(Uri.parse(auth.api.baseUrl).origin))
          .toString()));
  SessionPersistenceService checkpoints(String account) =>
      EncryptedSessionPersistence(outbox(account));

  Future<void> recoverDeviceKey() async {
    final pair = await auth.currentSession();
    if (pair == null) {
      throw const ApiException(statusCode: 401, kind: 'signed_out');
    }
    await sync();
    if ((await outbox(pair.accountId).readAfter(null)).isNotEmpty) {
      throw const ApiException(statusCode: 409, kind: 'sync_before_recovery');
    }
    await keys(pair.accountId).recoverKey();
    await refreshStatus();
  }

  Future<OnlineSessionContext> start(
      {required PatientManifest manifest,
      required List<String> cardIds}) async {
    final session = await auth.currentSession();
    if (session == null) {
      throw const ApiException(statusCode: 401, kind: 'signed_out');
    }
    final account = session.accountId;
    return SerialOperations.run('${auth.storage.scope}.$account.session-start',
        () async {
      await keys(account).ensureCertified();
      final store = outbox(account);
      var pending = await store.pendingStart;
      if (pending != null &&
          (pending['case_id'] != manifest.id ||
              jsonEncode(pending['card_ids']) != jsonEncode(cardIds))) {
        throw StateError('Finish or discard the current online session first');
      }
      pending ??= {
        'case_id': manifest.id,
        'card_ids': List<String>.of(cardIds),
        'request_id': ApiClient.newId('session')
      };
      if (pending['authorization'] == null) {
        await store.savePendingStart(pending);
        late ApiResponse response;
        try {
          response = await auth.authenticated('POST', '/v1/sessions',
              accountId: account,
              idempotencyKey: pending['request_id'] as String,
              body: {'case_id': manifest.id, 'card_ids': cardIds});
        } on ApiException catch (error) {
          // Only an explicit denial settles the request. Timeouts, lost or
          // malformed responses and transient failures retain the replay key.
          if (!error.retryable &&
              [400, 403, 404, 410, 422].contains(error.statusCode)) {
            await store.retireDeniedStart(pending['request_id'] as String);
          }
          rethrow;
        }
        _validatePermit(response.body, manifest);
        pending = {...pending, 'authorization': response.body};
        await store.savePendingStart(pending);
      }
      final permit = _validatePermit(
          pending['authorization'] as Map<String, Object?>, manifest);
      if (!permit.expiresAt.isAfter(DateTime.now().toUtc())) {
        throw const ApiException(statusCode: 409, kind: 'expired_permit');
      }
      await refreshStatus();
      return OnlineSessionContext(accountId: account, authorization: permit);
    });
  }

  SessionAuthorization _validatePermit(
      Map<String, Object?> json, PatientManifest manifest) {
    final permit = SessionAuthorization.fromJson(json);
    if (permit.startState['case_id'] != manifest.id ||
        permit.rulesetVersion != manifest.rulesetVersion ||
        permit.startState['manifest_checksum'] != manifest.contentChecksum) {
      throw const ApiException(statusCode: 409, kind: 'content_mismatch');
    }
    return permit;
  }

  Future<void> enqueue(
      OnlineSessionContext context, SessionReceipt receipt) async {
    if ((await auth.currentSession())?.accountId != context.accountId) {
      throw const ApiException(statusCode: 401, kind: 'account_mismatch');
    }
    final stored = await outbox(context.accountId).pendingStart;
    final storedPermit = stored?['authorization'] as Map<String, Object?>?;
    final permit = context.authorization;
    if (storedPermit == null ||
        CanonicalJson.encodeString(
                SessionAuthorization.fromJson(storedPermit).toJson()) !=
            CanonicalJson.encodeString(permit.toJson()) ||
        receipt.id != permit.id ||
        receipt.patientId != permit.patientId ||
        receipt.rulesetVersion != permit.rulesetVersion ||
        receipt.idempotencyKey != 'rcp_${permit.id}' ||
        receipt.ledgerEvents.isNotEmpty ||
        CanonicalJson.encodeString(receipt.startState) !=
            CanonicalJson.encodeString(permit.startState)) {
      throw StateError('Receipt is not bound to this server-issued session');
    }
    if (receipt.toCanonicalBytes().length > network.maxCanonicalReceiptBytes) {
      throw StateError('Receipt exceeds the configured size bound');
    }
    await SignedReceiptQueue(
            deviceKeyStore: keys(context.accountId),
            persistence: outbox(context.accountId))
        .enqueue(receipt);
    await refreshStatus();
  }

  Future<void> finish(OnlineSessionContext context) async {
    await outbox(context.accountId).retireStart(context.authorization.id);
  }

  Future<void> discardExpired() async {
    final pair = await auth.currentSession();
    if (pair == null) return;
    final pending = await outbox(pair.accountId).pendingStart;
    final permitJson = pending?['authorization'] as Map<String, Object?>?;
    if (permitJson == null) return;
    final permit = SessionAuthorization.fromJson(permitJson);
    if (permit.expiresAt.isAfter(DateTime.now().toUtc())) {
      throw StateError('Session is still active');
    }
    await finish(
        OnlineSessionContext(accountId: pair.accountId, authorization: permit));
  }

  Future<void> refreshStatus({String? errorKind, bool stale = true}) async {
    final pair = await auth.currentSession();
    if (pair == null) {
      status.value = const OnlineSyncStatus();
      return;
    }
    final store = outbox(pair.accountId);
    final entries = await store.readAfter(await store.cursor);
    status.value = OnlineSyncStatus(
        accountId: pair.accountId,
        pending: entries.length,
        verdicts: await store.verdicts,
        profile: await store.cachedProfile,
        errorKind: errorKind,
        stale: stale);
  }

  Future<void> sync() async {
    final pair = await auth.currentSession();
    if (pair == null) return;
    final account = pair.accountId;
    await SerialOperations.run('${auth.storage.scope}.$account.sync', () async {
      status.value = OnlineSyncStatus(accountId: account, syncing: true);
      try {
        final store = outbox(account);
        await SignedReceiptQueue(
                deviceKeyStore: keys(account), persistence: store)
            .reconcileBatch((envelopes) async {
          final body = {
            'envelopes': envelopes.map((envelope) => envelope.toJson()).toList()
          };
          final requestId =
              'batch_${sha256.convert(CanonicalJson.encode(body))}';
          final response = await auth.authenticated(
              'POST', '/v1/receipts/batch',
              accountId: account, idempotencyKey: requestId, body: body);
          return ReceiptBatch.fromJson(response.body);
        },
                maxEnvelopes: network.maxBatchEnvelopes,
                maxBytes: network.maxBatchBytes);
        final boot = await auth.authenticated('GET', '/v1/boot',
            accountId: account, etag: await store.profileEtag);
        if (boot.statusCode != 304) {
          final profile = boot.body['profile'] as Map<String, Object?>;
          final profileAccount = profile['account_id'] ?? profile['id'];
          if (profileAccount != account) {
            throw const ApiException(statusCode: 409, kind: 'account_mismatch');
          }
          await store.cacheProfile(
              profile, boot.etag ?? boot.body['etag'] as String?);
        }
        await refreshStatus(stale: !await store.profileCurrent);
      } on ApiException catch (error) {
        await refreshStatus(errorKind: error.kind);
      }
    });
  }

  void dispose() => status.dispose();
}
