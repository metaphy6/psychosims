import 'dart:async';
import 'dart:convert';
import 'dart:math';

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
  Future<String?> get cursor;
  Future<void> advanceCursor(String id);
  Future<void> append(QueueEntry entry);
  Future<List<QueueEntry>> readAfter(String? cursor);
}

/// A memory-backed queue persistence implementation for tests.
class MemoryQueuePersistence implements QueuePersistence {
  final List<QueueEntry> _entries = [];
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
    final jitter = Random().nextInt(capped ~/ 4 + 1);
    return Duration(milliseconds: capped + jitter);
  }
}
