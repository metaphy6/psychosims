import 'package:psychemas/psychemas.dart';

/// Configuration values consumed by [ClinicEconomy].
class ClinicEconomyConfig {
  final int officeRentMicros;
  final int officePurchaseMicros;
  final int officeResaleMultiplierMillis;
  final int monthlyOverheadMicros;
  final List<(int, int)> taxBrackets;
  final int auditProbabilityMillis;
  final int auditOvermedicationPenalty;

  const ClinicEconomyConfig({
    this.officeRentMicros = 5000000,
    this.officePurchaseMicros = 50000000,
    this.officeResaleMultiplierMillis = 700,
    this.monthlyOverheadMicros = 1000000,
    this.taxBrackets = const [
      (0, 0),
      (20000000, 100),
      (100000000, 200),
    ],
    this.auditProbabilityMillis = 50,
    this.auditOvermedicationPenalty = 10,
  });
}

/// Clinic business transactions: rent, buy, sell, overhead, taxes, audits (§22).
class ClinicEconomy {
  final ClinicEconomyConfig config;

  const ClinicEconomy(this.config);

  /// Rent event for a practice office.
  LedgerEvent rentOffice({
    required String officeId,
    required String idempotencyKey,
    required int timestampSeconds,
  }) {
    return LedgerEvent(
      kind: 'office_rent',
      idempotencyKey: idempotencyKey,
      timestampSeconds: timestampSeconds,
      currency: CurrencyType.cash,
      amountMicros: -config.officeRentMicros,
      reasonKey: 'ledger.office.rent',
    );
  }

  /// Purchase event for an owned office.
  LedgerEvent buyOffice({
    required String officeId,
    required String idempotencyKey,
    required int timestampSeconds,
  }) {
    return LedgerEvent(
      kind: 'office_purchase',
      idempotencyKey: idempotencyKey,
      timestampSeconds: timestampSeconds,
      currency: CurrencyType.cash,
      amountMicros: -config.officePurchaseMicros,
      reasonKey: 'ledger.office.purchase',
    );
  }

  /// Resale value for an owned office.
  int resaleValueMicros() {
    return (config.officePurchaseMicros *
            config.officeResaleMultiplierMillis) ~/
        1000;
  }

  /// Sell event for an owned office.
  LedgerEvent sellOffice({
    required String officeId,
    required String idempotencyKey,
    required int timestampSeconds,
  }) {
    return LedgerEvent(
      kind: 'office_sale',
      idempotencyKey: idempotencyKey,
      timestampSeconds: timestampSeconds,
      currency: CurrencyType.cash,
      amountMicros: resaleValueMicros(),
      reasonKey: 'ledger.office.sale',
    );
  }

  /// Monthly overhead event per office.
  LedgerEvent monthlyOverhead({
    required String officeId,
    required String idempotencyKey,
    required int timestampSeconds,
  }) {
    return LedgerEvent(
      kind: 'office_overhead',
      idempotencyKey: idempotencyKey,
      timestampSeconds: timestampSeconds,
      currency: CurrencyType.cash,
      amountMicros: -config.monthlyOverheadMicros,
      reasonKey: 'ledger.office.overhead',
    );
  }

  /// Progressive tax on [taxableIncomeMicros].
  ///
  /// Brackets are (upper_limit_micros, rate_millis); income in each band is
  /// taxed only at that band's rate.
  int taxOwedMicros(int taxableIncomeMicros) {
    var tax = 0;
    var previousLimit = 0;
    for (final bracket in config.taxBrackets) {
      final limit = bracket.$1;
      final rate = bracket.$2;
      if (taxableIncomeMicros <= previousLimit) break;
      final taxable =
          (taxableIncomeMicros - previousLimit).clamp(0, limit - previousLimit);
      tax += (taxable * rate) ~/ 1000;
      previousLimit = limit;
    }
    return tax;
  }

  /// Deterministic audit outcome.
  ///
  /// [rollMillis] is a fixed-point value 0..999 from the seeded PRNG.
  /// [overmedicationDeltaCount] counts medication-dependency/tolerance deltas
  /// in the audited window.
  (bool audited, int reputationPenalty) audit({
    required int rollMillis,
    required int overmedicationDeltaCount,
  }) {
    final audited = rollMillis < config.auditProbabilityMillis;
    final penalty = audited
        ? overmedicationDeltaCount * config.auditOvermedicationPenalty
        : 0;
    return (audited, penalty);
  }
}
