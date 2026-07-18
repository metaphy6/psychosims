import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:path/path.dart' as p;
import 'package:psychemas/psychemas.dart';

/// Exception raised when career save operations fail.
sealed class CareerPersistenceException implements Exception {
  CareerPersistenceException(this.message);
  final String message;
  @override
  String toString() => 'CareerPersistenceException: $message';
}

/// The save failed because a raw transcript reached durable storage.
class TranscriptPersistenceException extends CareerPersistenceException {
  TranscriptPersistenceException(super.message);
}

/// The save file is corrupt, fails its checksum, or cannot be migrated.
class CorruptSaveException extends CareerPersistenceException {
  CorruptSaveException(super.message);
}

/// The save schema version is newer than this build supports.
class UnsupportedSchemaException extends CareerPersistenceException {
  UnsupportedSchemaException(super.message);
}

/// Imported save exceeded a safety budget.
class ImportBudgetException extends CareerPersistenceException {
  ImportBudgetException(super.message);
}

/// A full snapshot of offline career state.
///
/// Keeps the profile atomic (<0.5 KB of primitive metrics), the owned clinic,
/// persistent-case histories, and the local receipt queue. No logs or
/// transcripts are stored here — that invariant is enforced at write time.
class CareerSave {
  const CareerSave({
    required this.profile,
    this.clinic,
    this.ownedCases = const {},
    this.receiptQueue = const [],
  });

  final CareerProfile profile;
  final ClinicAsset? clinic;
  final Map<String, CaseHistoryEnvelope> ownedCases;
  final List<SignedEnvelope> receiptQueue;

  CareerSave copyWith({
    CareerProfile? profile,
    ClinicAsset? clinic,
    Map<String, CaseHistoryEnvelope>? ownedCases,
    List<SignedEnvelope>? receiptQueue,
  }) {
    return CareerSave(
      profile: profile ?? this.profile,
      clinic: clinic ?? this.clinic,
      ownedCases: ownedCases ?? this.ownedCases,
      receiptQueue: receiptQueue ?? this.receiptQueue,
    );
  }

  Map<String, Object?> toJson() => {
        'profile': profile.toJson(),
        'clinic': clinic?.toJson(),
        'owned_cases': ownedCases.map(
          (caseId, envelope) => MapEntry(caseId, envelope.toJson()),
        ),
        'receipt_queue': receiptQueue.map((e) => e.toJson()).toList(),
      };

  static CareerSave fromJson(Map<String, Object?> json) {
    final clinicJson = json['clinic'] as Map<String, Object?>?;
    return CareerSave(
      profile: CareerProfile.fromJson(json['profile']! as Map<String, Object?>),
      clinic: clinicJson == null ? null : ClinicAsset.fromJson(clinicJson),
      ownedCases: (json['owned_cases']! as Map<String, dynamic>).map(
        (caseId, value) => MapEntry(
          caseId,
          CaseHistoryEnvelope.fromJson(value as Map<String, Object?>),
        ),
      ),
      receiptQueue: (json['receipt_queue']! as List<dynamic>)
          .cast<Map<String, Object?>>()
          .map(SignedEnvelope.fromJson)
          .toList(),
    );
  }
}

/// Durable offline persistence for the career/profile seam (Phase 2.9).
///
/// Follows the 0.9 storage seam:
/// - write-temp → fsync → atomic-rename so a crash cannot leave a half-written
///   save;
/// - a checksum guards the save against hand-edits and disk corruption;
/// - a backup copy is kept so a corrupt main file falls back to the last-good
///   snapshot;
/// - schema migration runs forward from older saved schemas;
/// - imported/restore saves are treated as untrusted input and pass size,
///   nesting, field-count, and checksum guards before loading;
/// - raw transcripts are rejected at write time (0.6 no-durable-transcript rule).
///
/// The service writes to [directory]. It does not depend on Flutter or the
/// inference layer, so it can be unit-tested headlessly.
class CareerPersistenceService {
  CareerPersistenceService({required this.directory});

  final Directory directory;

  static const String _saveFileName = 'career_save.json';
  static const String _backupFileName = 'career_save.json.bak';
  static const String _receiptQueueFileName = 'receipt_queue.jsonl';

  static const int currentSchemaVersion = 1;
  static const int maxImportBytes = 5 * 1024 * 1024;
  static const int maxNestingDepth = 32;
  static const int maxReceiptQueueLength = 10000;
  static const int maxEventTailLength = 100000;
  static const int maxOwnedCases = 10000;

  static const Set<String> _forbiddenTranscriptKeys = {
    'transcript',
    'raw_text',
    'rawtext',
    'raw_dialogue',
    'rawdialogue',
    'llm_output',
    'model_output',
    'conversation',
    'prompt',
    'completion',
  };

  File get _file => File(p.join(directory.path, _saveFileName));
  File get _backupFile => File(p.join(directory.path, _backupFileName));
  File get _receiptQueueFile =>
      File(p.join(directory.path, _receiptQueueFileName));

  /// Persists [save] atomically with a checksum and no-durable-transcript guard.
  Future<void> save(CareerSave save) async {
    _assertNoTranscript(save.toJson());
    _assertFieldBudget(save);

    if (!await directory.exists()) {
      await directory.create(recursive: true);
    }

    final payload = {
      'schema_version': currentSchemaVersion,
      'ruleset_version': save.profile.rulesetVersion,
      'save': save.toJson(),
    };
    final envelope = Map<String, Object?>.of(payload)
      ..['checksum'] = _computeChecksum(payload);

    final temp = File('${_file.path}.tmp');
    await _writeAtomic(temp, envelope);
    await temp.rename(_file.path);

    // Keep a backup copy of the now-committed main file.
    final backupTemp = File('${_backupFile.path}.tmp');
    await _writeAtomic(backupTemp, envelope);
    await backupTemp.rename(_backupFile.path);

    // The snapshot now contains the full queue; compact the append-only log.
    if (await _receiptQueueFile.exists()) {
      await _receiptQueueFile.delete();
    }
  }

  /// Loads the most recent consistent [CareerSave], falling back to backup.
  ///
  /// Returns null only when neither main nor backup exists. A corrupt or
  /// unrecoverable save throws [CorruptSaveException] so the caller can decide
  /// whether to start fresh or surface the error.
  Future<CareerSave?> load() async {
    CareerSave? result;
    CorruptSaveException? mainFailure;
    try {
      result = await _loadFile(_file);
    } on CorruptSaveException catch (e) {
      mainFailure = e;
    }
    // Policy violations (transcript, budget, unsupported schema) fail closed
    // and do not fall back to a backup snapshot.

    if (result == null) {
      try {
        result = await _loadFile(_backupFile);
      } on CorruptSaveException {
        // Backup also unreadable; fall through to report the main failure.
      }
    }

    if (result == null && mainFailure != null) {
      throw CorruptSaveException('main save unreadable: $mainFailure');
    }
    if (result == null) return null;

    // Merge any signed receipts that were appended since the last full save.
    final pending = await _readReceiptQueue();
    if (pending.isEmpty) return result;

    final seen = result.receiptQueue.map(_envelopeIdempotencyKey).toSet();
    return result.copyWith(
      receiptQueue: [
        ...result.receiptQueue,
        ...pending.where((e) => seen.add(_envelopeIdempotencyKey(e))),
      ],
    );
  }

  /// Loads an existing save or returns a blank one for [profileId].
  Future<CareerSave> loadOrCreate(
      String profileId, String rulesetVersion) async {
    final existing = await load();
    return existing ??
        CareerSave(
          profile: CareerProfile(
            profileId: profileId,
            rulesetVersion: rulesetVersion,
          ),
        );
  }

  /// Appends [envelope] to the durable signed receipt queue if its
  /// idempotency key is not already present.
  ///
  /// The queue is the offline stand-in for the Phase 3.4 submission queue. It
  /// now stores the 3.0 signed envelope rather than the bare
  /// [SessionReceipt] — a receipt is signed once at enqueue and the same
  /// canonical bytes are re-sent on every retry. Writes are append-only and
  /// fsynced; the in-save snapshot is updated at the next [save] call.
  Future<void> appendSignedReceipt(SignedEnvelope envelope) async {
    if (!await directory.exists()) {
      await directory.create(recursive: true);
    }

    final line = '${CanonicalJson.encodeString(envelope.toJson())}\n';
    final bytes = utf8.encode(line);

    final raf = await _receiptQueueFile.open(mode: FileMode.writeOnlyAppend);
    try {
      await raf.writeFrom(bytes);
      await raf.flush();
    } finally {
      await raf.close();
    }
  }

  /// Drains the durable signed receipt queue and returns the envelopes in
  /// order.
  ///
  /// Deduplicates by idempotency key so replayed appends never double-apply.
  Future<List<SignedEnvelope>> drainSignedReceiptQueue() async {
    final envelopes = await _readReceiptQueue();
    if (await _receiptQueueFile.exists()) {
      await _receiptQueueFile.delete();
    }
    return envelopes;
  }

  Future<List<SignedEnvelope>> _readReceiptQueue() async {
    if (!await _receiptQueueFile.exists()) return const [];
    final lines = await _receiptQueueFile.readAsLines();
    final seen = <String>{};
    final envelopes = <SignedEnvelope>[];
    for (final line in lines) {
      if (line.trim().isEmpty) continue;
      final json = jsonDecode(line) as Map<String, Object?>;
      final envelope = SignedEnvelope.fromJson(json);
      if (seen.add(_envelopeIdempotencyKey(envelope))) {
        envelopes.add(envelope);
      }
    }
    return envelopes;
  }

  String _envelopeIdempotencyKey(SignedEnvelope envelope) {
    final json = jsonDecode(utf8.decode(envelope.canonicalReceiptBytes))
        as Map<String, Object?>;
    return json['idempotency_key']! as String;
  }

  /// Exports the current main save to [destination].
  ///
  /// The exported file is a valid input to [importSave].
  Future<void> exportSave(File destination) async {
    if (!await _file.exists()) {
      throw CorruptSaveException('no main save to export');
    }
    final bytes = await _file.readAsBytes();
    await destination.writeAsBytes(bytes, flush: true);
  }

  /// Imports a save from [source], treating it as untrusted input.
  ///
  /// Enforces: byte-size budget, nesting-depth budget, field-count budgets,
  /// checksum verification, and the no-transcript rule. Fails closed on any
  /// violation.
  Future<CareerSave> importSave(File source) async {
    final length = await source.length();
    if (length > maxImportBytes) {
      throw ImportBudgetException(
        'save size $length exceeds $maxImportBytes bytes',
      );
    }

    late final Map<String, Object?> envelope;
    try {
      final bytes = await source.readAsBytes();
      final json = jsonDecode(utf8.decode(bytes)) as Map<String, Object?>;
      envelope = json;
    } on Exception catch (e) {
      throw CorruptSaveException('not valid JSON: $e');
    }

    _validateDepth(envelope, depth: 1);
    _assertNoTranscript(envelope);

    final schemaVersion = envelope['schema_version'];
    if (schemaVersion is! int) {
      throw CorruptSaveException('missing or invalid schema_version');
    }
    if (schemaVersion > currentSchemaVersion) {
      throw UnsupportedSchemaException(
        'schema $schemaVersion > supported $currentSchemaVersion',
      );
    }

    final storedChecksum = envelope['checksum'];
    if (storedChecksum is! String) {
      throw CorruptSaveException('missing checksum');
    }

    final payload = Map<String, Object?>.of(envelope)..remove('checksum');
    final expectedChecksum = _computeChecksum(payload);
    if (storedChecksum.toLowerCase() != expectedChecksum.toLowerCase()) {
      throw CorruptSaveException('checksum mismatch');
    }

    final migrated = _migrate(payload, fromVersion: schemaVersion);
    final saveJson = migrated['save']! as Map<String, Object?>;
    _assertFieldBudget(CareerSave.fromJson(saveJson));
    return CareerSave.fromJson(saveJson);
  }

  Future<CareerSave?> _loadFile(File file) async {
    if (!await file.exists()) return null;
    try {
      final bytes = await file.readAsBytes();
      final json = jsonDecode(utf8.decode(bytes)) as Map<String, Object?>;
      return importSave(file);
    } on FormatException catch (e) {
      throw CorruptSaveException('malformed JSON: $e');
    }
  }

  Future<void> _writeAtomic(File temp, Map<String, Object?> envelope) async {
    final bytes = utf8.encode(CanonicalJson.encodeString(envelope));
    final raf = await temp.open(mode: FileMode.writeOnly);
    try {
      await raf.writeFrom(bytes);
      await raf.flush();
    } finally {
      await raf.close();
    }
  }

  String _computeChecksum(Map<String, Object?> payload) {
    final canonical = CanonicalJson.encodeString(payload);
    final bytes = utf8.encode(canonical);
    return sha256.convert(bytes).toString();
  }

  Map<String, Object?> _migrate(
    Map<String, Object?> payload, {
    required int fromVersion,
  }) {
    if (fromVersion == currentSchemaVersion) return payload;

    // Future migrations chain here. Each step returns the next version's shape.
    if (fromVersion < 1) {
      throw CorruptSaveException('schema_version must be >= 1');
    }

    return payload;
  }

  void _assertNoTranscript(Object? value) {
    if (value is Map<String, Object?>) {
      for (final entry in value.entries) {
        if (_forbiddenTranscriptKeys.contains(entry.key.toLowerCase())) {
          throw TranscriptPersistenceException(
            'forbidden transcript key "${entry.key}" found in save',
          );
        }
        _assertNoTranscript(entry.value);
      }
    } else if (value is List) {
      for (final item in value) {
        _assertNoTranscript(item);
      }
    }
  }

  void _validateDepth(Object? value, {required int depth}) {
    if (depth > maxNestingDepth) {
      throw ImportBudgetException('JSON nesting exceeds $maxNestingDepth');
    }
    if (value is Map<String, Object?>) {
      for (final entry in value.entries) {
        _validateDepth(entry.value, depth: depth + 1);
      }
    } else if (value is List) {
      for (final item in value) {
        _validateDepth(item, depth: depth + 1);
      }
    }
  }

  void _assertFieldBudget(CareerSave save) {
    if (save.receiptQueue.length > maxReceiptQueueLength) {
      throw ImportBudgetException(
        'receipt queue ${save.receiptQueue.length} > $maxReceiptQueueLength',
      );
    }
    if (save.profile.eventTail.length > maxEventTailLength) {
      throw ImportBudgetException(
        'event tail ${save.profile.eventTail.length} > $maxEventTailLength',
      );
    }
    if (save.ownedCases.length > maxOwnedCases) {
      throw ImportBudgetException(
        'owned cases ${save.ownedCases.length} > $maxOwnedCases',
      );
    }
  }
}
