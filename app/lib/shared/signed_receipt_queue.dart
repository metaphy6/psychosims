import 'dart:async';
import 'dart:math';
import 'dart:convert';
import 'api_client.dart';
import 'secure_storage.dart';

import 'package:psychemas/psychemas.dart';

import 'device_key_store.dart';

/// The durable client-side receipt queue from Phase 3.4.
///
/// Receipts are signed once at enqueue (using the 3.0 signed envelope) and
/// drained in order when connectivity returns. Each envelope carries its own
/// idempotency key so retries are exactly-once at the server.
///
/// The persistent backing store is abstracted by [QueuePersistence] so tests
/// can use memory and production can use the platform secure storage seam
/// (the 2.9 JSONL queue upgraded to hold signed envelopes).
class SignedReceiptQueue {
  SignedReceiptQueue({
    required this.deviceKeyStore,
    required this.persistence,
    this.retryPolicy = const RetryPolicy(),
  });

  final DeviceKeyStore deviceKeyStore;
  final QueuePersistence persistence;
  final RetryPolicy retryPolicy;

  /// Signs [receipt] and appends it to the durable queue.
  Future<void> enqueue(SessionReceipt receipt) async {
    final envelope = await deviceKeyStore.signReceipt(receipt);
    final entry = QueueEntry(
      id: receipt.idempotencyKey,
      envelope: envelope,
      enqueuedAt: DateTime.now().toUtc(),
    );
    await persistence.append(entry);
  }

  /// Resolves only a contiguous prefix. A permanent verdict is written in the
  /// same transaction as its cursor; transient errors leave the receipt pending.
  Future<String?> reconcile(
          Future<ReceiptVerdict> Function(SignedEnvelope) submit) =>
      SerialOperations.run('${persistence.scope}.drain', () async {
        var cursor = await persistence.cursor;
        for (final entry in await persistence.readAfter(cursor)) {
          ReceiptVerdict verdict;
          try {
            verdict = await submit(entry.envelope);
          } on ApiException catch (error) {
            if (error.retryable || error.statusCode == 401) return cursor;
            if (![400, 403, 404, 409, 410, 413, 422]
                .contains(error.statusCode)) {
              rethrow;
            }
            final receipt = SessionReceipt.fromJson(
                jsonDecode(utf8.decode(entry.envelope.canonicalReceiptBytes))
                    as Map<String, Object?>);
            verdict = ReceiptVerdict(
                id: receipt.id,
                idempotencyKey: entry.id,
                status: 'rejected',
                rewardStatus: 'held_unproven',
                code: error.kind);
          }
          if (verdict.retryable || verdict.status == 'retryable') return cursor;
          await persistence.resolve(entry.id, verdict);
          cursor = entry.id;
        }
        return cursor;
      });

  Future<String?> reconcileBatch(
          Future<ReceiptBatch> Function(List<SignedEnvelope>) submit,
          {int maxEnvelopes = 64,
          int maxBytes = 524288}) =>
      SerialOperations.run('${persistence.scope}.drain', () async {
        if (maxEnvelopes < 1 || maxEnvelopes > 64 || maxBytes < 1) {
          throw ArgumentError('Invalid batch bounds');
        }
        var cursor = await persistence.cursor;
        final remaining = await persistence.readAfter(cursor);
        var offset = 0;
        while (offset < remaining.length) {
          final entries = <QueueEntry>[];
          for (final entry in remaining.skip(offset).take(maxEnvelopes)) {
            final candidate = [...entries, entry];
            final bytes = utf8
                .encode(jsonEncode({
                  'envelopes':
                      candidate.map((e) => e.envelope.toJson()).toList()
                }))
                .length;
            if (bytes > maxBytes) break;
            entries.add(entry);
          }
          if (entries.isEmpty) {
            throw StateError('A receipt exceeds the batch transport budget');
          }
          ReceiptBatch batch;
          try {
            batch = await submit(
                entries.map((e) => e.envelope).toList(growable: false));
          } on ApiException catch (error) {
            if (error.retryable || error.statusCode == 401) return cursor;
            rethrow;
          }
          if (batch.results.length != entries.length) {
            throw const FormatException('Batch result count mismatch');
          }
          for (var i = 0; i < entries.length; i++) {
            final entry = entries[i], verdict = batch.results[i];
            if (verdict.idempotencyKey != entry.id) {
              throw const FormatException('Batch result order mismatch');
            }
            if (verdict.retryable || verdict.status == 'retryable') {
              return cursor;
            }
            await persistence.resolve(entry.id, verdict);
            cursor = entry.id;
            offset++;
          }
        }
        return cursor;
      });

  /// Drains the queue by calling [submit] for each entry in order.
  ///
  /// Returns the id of the last successfully-acknowledged entry (the cursor).
  Future<String?> drain(
      Future<void> Function(SignedEnvelope envelope) submit) async {
    var cursor = await persistence.cursor;
    final entries = await persistence.readAfter(cursor);
    for (final entry in entries) {
      var attempt = 0;
      var delivered = false;
      while (attempt <= retryPolicy.maxAttempts && !delivered) {
        try {
          await submit(entry.envelope);
          delivered = true;
        } on Exception catch (_) {
          attempt++;
          if (attempt > retryPolicy.maxAttempts) {
            // Leave cursor at last success; caller can retry later.
            return cursor;
          }
          await Future.delayed(retryPolicy.delayFor(attempt));
        }
      }
      if (delivered) {
        cursor = entry.id;
        await persistence.advanceCursor(cursor);
      }
    }
    return cursor;
  }
}

/// Persistence seam for the durable queue.
abstract interface class QueuePersistence {
  String get scope;
  Future<List<ReceiptVerdict>> get verdicts;
  Future<void> resolve(String id, ReceiptVerdict verdict);
  Future<String?> get cursor;
  Future<void> advanceCursor(String id);
  Future<void> append(QueueEntry entry);
  Future<List<QueueEntry>> readAfter(String? cursor);
}

/// A memory-backed queue persistence implementation for tests.
class MemoryQueuePersistence implements QueuePersistence {
  final List<QueueEntry> _entries = [];
  final List<ReceiptVerdict> _verdicts = [];
  @override
  String get scope => 'memory-queue-${identityHashCode(this)}';
  @override
  Future<List<ReceiptVerdict>> get verdicts async =>
      List.unmodifiable(_verdicts);
  @override
  Future<void> resolve(String id, ReceiptVerdict verdict) async {
    _verdicts.add(verdict);
    _cursor = id;
  }

  String? _cursor;

  @override
  Future<String?> get cursor async => _cursor;

  @override
  Future<void> advanceCursor(String id) async {
    _cursor = id;
  }

  @override
  Future<void> append(QueueEntry entry) async {
    _entries.add(entry);
  }

  @override
  Future<List<QueueEntry>> readAfter(String? cursor) async {
    if (cursor == null || cursor.isEmpty) return List.unmodifiable(_entries);
    final idx = _entries.indexWhere((e) => e.id == cursor);
    if (idx < 0) return List.unmodifiable(_entries);
    return List.unmodifiable(_entries.sublist(idx + 1));
  }
}

/// One queued signed envelope.
class QueueEntry {
  QueueEntry(
      {required this.id, required this.envelope, required this.enqueuedAt});

  final String id;
  final SignedEnvelope envelope;
  final DateTime enqueuedAt;

  Map<String, Object?> toJson() => {
        'id': id,
        'envelope': envelope.toJson(),
        'enqueued_at': enqueuedAt.toIso8601String(),
      };

  factory QueueEntry.fromJson(Map<String, Object?> json) => QueueEntry(
        id: json['id'] as String,
        envelope:
            SignedEnvelope.fromJson(json['envelope'] as Map<String, Object?>),
        enqueuedAt: DateTime.parse(json['enqueued_at'] as String),
      );
}

/// Bounded exponential backoff + jitter (0.10 resilience policy).
class RetryPolicy {
  const RetryPolicy(
      {this.maxAttempts = 5,
      this.baseDelay = const Duration(seconds: 1),
      this.maxDelay = const Duration(minutes: 1)});

  final int maxAttempts;
  final Duration baseDelay;
  final Duration maxDelay;

  Duration delayFor(int attempt) {
    final exponential = baseDelay.inMilliseconds * (1 << (attempt - 1));
    final capped = exponential.clamp(0, maxDelay.inMilliseconds);
    final jitter = Random().nextInt(capped + 1);
    return Duration(milliseconds: jitter);
  }
}
