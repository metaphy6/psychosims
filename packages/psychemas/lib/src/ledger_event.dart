import 'canonical_json.dart';
import 'currency_type.dart';

/// A single append-only, idempotent mutation to the offline career ledger.
///
/// Every balance change is an event first; balances are always a deterministic
/// replay of the event stream. The idempotency key lets retries apply exactly
/// once, which is the local precursor to the Phase 5.1 server economy.
class LedgerEvent {
  /// Stable event type token (e.g. `session_fee`, `study_purchase`).
  final String kind;

  /// Idempotency key: the same key applied twice is a no-op.
  final String idempotencyKey;

  /// Wall-clock timestamp used only for ordering and reputation recency.
  /// The core logic reads an injected authoritative clock, not device time.
  final int timestampSeconds;

  /// Currency being mutated.
  final CurrencyType currency;

  /// Amount in fixed-point micros (1 currency unit = 1000000 micros).
  /// Positive for credit, negative for debit.
  final int amountMicros;

  /// Human-readable reason key for UI/debugging; never parsed by rules.
  final String reasonKey;

  const LedgerEvent({
    required this.kind,
    required this.idempotencyKey,
    required this.timestampSeconds,
    required this.currency,
    required this.amountMicros,
    required this.reasonKey,
  });

  Map<String, Object?> toJson() => {
        'kind': kind,
        'idempotency_key': idempotencyKey,
        'timestamp_seconds': timestampSeconds,
        'currency': currency.toJson(),
        'amount_micros': amountMicros,
        'reason_key': reasonKey,
      };

  factory LedgerEvent.fromJson(Map<String, Object?> json) {
    return LedgerEvent(
      kind: json['kind']! as String,
      idempotencyKey: json['idempotency_key']! as String,
      timestampSeconds: json['timestamp_seconds']! as int,
      currency: CurrencyTypeJson.fromJson(json['currency']! as String),
      amountMicros: json['amount_micros']! as int,
      reasonKey: json['reason_key']! as String,
    );
  }

  LedgerEvent copyWith({
    String? kind,
    String? idempotencyKey,
    int? timestampSeconds,
    CurrencyType? currency,
    int? amountMicros,
    String? reasonKey,
  }) {
    return LedgerEvent(
      kind: kind ?? this.kind,
      idempotencyKey: idempotencyKey ?? this.idempotencyKey,
      timestampSeconds: timestampSeconds ?? this.timestampSeconds,
      currency: currency ?? this.currency,
      amountMicros: amountMicros ?? this.amountMicros,
      reasonKey: reasonKey ?? this.reasonKey,
    );
  }

  List<int> toCanonicalBytes() => CanonicalJson.encode(toJson());

  @override
  bool operator ==(Object other) =>
      other is LedgerEvent &&
      other.kind == kind &&
      other.idempotencyKey == idempotencyKey &&
      other.timestampSeconds == timestampSeconds &&
      other.currency == currency &&
      other.amountMicros == amountMicros &&
      other.reasonKey == reasonKey;

  @override
  int get hashCode => Object.hash(
        kind,
        idempotencyKey,
        timestampSeconds,
        currency,
        amountMicros,
        reasonKey,
      );
}
