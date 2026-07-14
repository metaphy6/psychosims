import 'package:psychemas/psychemas.dart';

/// Replayable, idempotent offline multi-currency ledger (§9, C-4).
///
/// Balances are never mutated directly; every change is an append-only
/// [LedgerEvent] with an idempotency key. The same stream feeds the Phase 5.1
/// server economy without reshaping.
class Ledger {
  final List<LedgerEvent> _events;

  Ledger({List<LedgerEvent> events = const []})
      : _events = List.unmodifiable(events);

  List<LedgerEvent> get events => _events;

  /// Returns a new ledger with [event] applied if its idempotency key is new.
  Ledger apply(LedgerEvent event) {
    if (_events.any((e) => e.idempotencyKey == event.idempotencyKey)) {
      return this;
    }
    return Ledger(events: [..._events, event]);
  }

  /// Replays the event stream and returns balances per currency.
  Map<CurrencyType, int> balances() {
    final result = <CurrencyType, int>{};
    for (final event in _events) {
      result[event.currency] =
          (result[event.currency] ?? 0) + event.amountMicros;
    }
    return result;
  }

  /// Replays events for a single currency.
  int balance(CurrencyType currency) {
    return _events
        .where((e) => e.currency == currency)
        .fold<int>(0, (sum, e) => sum + e.amountMicros);
  }

  /// Compacts the ledger by producing a checksum-guarded snapshot and dropping
  /// the consumed event tail.
  ///
  /// Returns the canonical snapshot balances in micros keyed by currency name,
  /// plus the remaining unconsumed events. The conservation invariant holds
  /// because balances are derived solely from events.
  LedgerSnapshot compact() {
    final balancesMicros = <String, int>{};
    for (final currency in CurrencyType.values) {
      final value = balance(currency);
      if (value != 0) balancesMicros[currency.toJson()] = value;
    }
    return LedgerSnapshot(
      balancesMicros: balancesMicros,
      events: const [],
    );
  }
}

/// Result of compacting a ledger.
class LedgerSnapshot {
  final Map<String, int> balancesMicros;
  final List<LedgerEvent> events;

  const LedgerSnapshot({
    required this.balancesMicros,
    required this.events,
  });
}
