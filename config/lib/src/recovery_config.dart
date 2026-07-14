/// Configuration constants for the recovery, pressure, and cooldown systems
/// (Phase 2.6).
///
/// Values are placeholders owned by C-4 [BALANCE-SPEC] and tuned in Phase 2.8.
class RecoveryConfig {
  /// Reputation threshold below which Discount Practice becomes available.
  final int discountPracticeReputationThreshold;

  /// XP multiplier while in Discount Practice (fixed-point millis).
  final int discountPracticeXpMultiplierMillis;

  /// Base competency constant for Academic Sabbatical floor.
  final int sabbaticalCompetencyPerFieldMillis;

  /// Pressure accrued per session (fixed-point millis).
  final int pressurePerSessionMillis;

  /// Pressure accrued per high-tier case (fixed-point millis).
  final int pressurePerHighTierMillis;

  /// Natural pressure decay per day (fixed-point millis).
  final int pressureDailyDecayMillis;

  /// Cooldown length for recovery windows, in seconds.
  final int recoveryCooldownSeconds;

  const RecoveryConfig({
    this.discountPracticeReputationThreshold = 30,
    this.discountPracticeXpMultiplierMillis = 500,
    this.sabbaticalCompetencyPerFieldMillis = 200,
    this.pressurePerSessionMillis = 100,
    this.pressurePerHighTierMillis = 150,
    this.pressureDailyDecayMillis = 20,
    this.recoveryCooldownSeconds = 24 * 60 * 60, // 1 day
  });
}
