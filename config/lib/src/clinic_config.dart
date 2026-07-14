/// Configuration constants for clinic operations and the offline case router
/// (Phase 2.7).
///
/// Values are placeholders owned by C-4 [BALANCE-SPEC] and tuned in Phase 2.8.
class ClinicConfig {
  /// Monthly rent for the smallest office, in cash micros.
  final int officeRentMicros;

  /// Purchase price for the smallest office, in cash micros.
  final int officePurchaseMicros;

  /// Resale value as a fraction of purchase price (fixed-point millis).
  final int officeResaleMultiplierMillis;

  /// Monthly overhead per owned office, in cash micros.
  final int monthlyOverheadMicros;

  /// Tax brackets as (upper_limit_micros, rate_millis) pairs.
  /// Income in (previous_limit, upper_limit] is taxed at [rate_millis].
  final List<(int, int)> taxBrackets;

  /// Fixed-point audit probability millis (e.g. 50 = 5%).
  final int auditProbabilityMillis;

  /// Penalty to reputation for over-medication history found in audit.
  final int auditOvermedicationPenalty;

  /// Chaos Misfortune Roll probability (fixed-point millis).
  final int chaosRollProbabilityMillis;

  /// Minimum career level before chaos roll can fire.
  final int chaosTenureGate;

  /// Social-chronic bias threshold: players at or below this reputation see
  /// more stateless cases.
  final int socialChronicBiasThreshold;

  const ClinicConfig({
    this.officeRentMicros = 5000000, // 5 cash units
    this.officePurchaseMicros = 50000000, // 50 cash units
    this.officeResaleMultiplierMillis = 700,
    this.monthlyOverheadMicros = 1000000, // 1 cash unit
    this.taxBrackets = const [
      (20000000, 0), // 0% up to 20 cash
      (100000000, 100), // 10% from 20 to 100 cash
      (9223372036854775807, 200), // 20% above 100 cash
    ],
    this.auditProbabilityMillis = 50,
    this.auditOvermedicationPenalty = 10,
    this.chaosRollProbabilityMillis = 50, // 5%
    this.chaosTenureGate = 3,
    this.socialChronicBiasThreshold = 20,
  });
}
