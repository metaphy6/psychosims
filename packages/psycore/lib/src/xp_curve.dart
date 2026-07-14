/// Configuration values consumed by [XpCurve].
///
/// Loaded from the central config authority in app code; the core receives
/// this plain value object to avoid a package dependency on config.
class XpCurveConfig {
  final int baseXpPerSession;
  final int difficultyXpExponentMillis;
  final int trivialGrindSessionThreshold;
  final int grindPenaltyMultiplierMillis;

  const XpCurveConfig({
    this.baseXpPerSession = 100,
    this.difficultyXpExponentMillis = 1200,
    this.trivialGrindSessionThreshold = 5,
    this.grindPenaltyMultiplierMillis = 500,
  });
}

/// Difficulty-scaled XP calculation (§9, C-4).
///
/// Harder cases reward proportionally more; repeated trivial grinding is
/// penalised. All math uses fixed-point integers so the outcome replays
/// byte-identically for the same inputs.
class XpCurve {
  final XpCurveConfig config;

  const XpCurve(this.config);

  /// XP for completing a case of [difficultyTier], adjusted for [sessionCount]
  /// to curb trivial grinding.
  ///
  /// [difficultyTier] starts at 1; [sessionCount] is the number of times the
  /// player has already resolved cases at or below this tier.
  int reward({
    required int difficultyTier,
    required int sessionCount,
  }) {
    final base = config.baseXpPerSession;

    // Difficulty scaling: base * tier * (1 + (tier-1)*(exponent-1)).
    // This is a placeholder polynomial curve owned by C-4 and tuned in 2.8.
    final exponent = config.difficultyXpExponentMillis;
    final curveFactor = 1000 + (difficultyTier - 1) * (exponent - 1000) ~/ 100;
    final difficultyScaled = (base * difficultyTier * curveFactor) ~/ 1000;

    // Grind penalty: sessions at/above the trivial threshold earn less.
    final grindSessions = sessionCount >= config.trivialGrindSessionThreshold
        ? sessionCount - config.trivialGrindSessionThreshold + 1
        : 0;
    final penalty = _grindPenalty(grindSessions);

    final reward = (difficultyScaled * penalty) ~/ 1000;
    return reward.clamp(0, 1000000000);
  }

  int _grindPenalty(int grindSessions) {
    if (grindSessions <= 0) return 1000;
    final multiplier = config.grindPenaltyMultiplierMillis;
    var penalty = 1000;
    for (var i = 0; i < grindSessions; i++) {
      penalty = (penalty * multiplier) ~/ 1000;
      if (penalty < 100) break; // floor at 10% to keep any reward nonzero
    }
    return penalty.clamp(100, 1000);
  }
}
