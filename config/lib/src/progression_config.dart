/// Configuration constants for the offline progression, economy, and recovery
/// systems (Phase 2.5–2.7).
///
/// All values are placeholders owned by C-4 [BALANCE-SPEC] and tuned in the
/// Phase 2.8 sandbox. The core consumes this object so numbers are never
/// hard-coded in rules code.
class ProgressionConfig {
  /// Base XP awarded for the easiest case; harder cases scale up from here.
  final int baseXpPerSession;

  /// Exponent for difficulty→XP scaling (fixed-point thousandths).
  /// 1000 = linear, 1500 = quadratic-ish, 500 = square-root.
  final int difficultyXpExponentMillis;

  /// XP earned at or above this session count is reduced to curb grinding.
  final int trivialGrindSessionThreshold;

  /// Multiplier applied to XP beyond the grind threshold (fixed-point millis).
  final int grindPenaltyMultiplierMillis;

  /// Study points earned per session on average.
  final int baseStudyPointsPerSession;

  /// Subspecialty points earned for high-tier cases.
  final int baseSubspecialtyPointsPerSession;

  /// Half-life for reputation recency weighting, in seconds.
  final int reputationHalfLifeSeconds;

  /// Decay table resolution: number of buckets covering one half-life each.
  final int reputationDecayBuckets;

  /// Credential-based reputation floor formula: base competency per study field.
  final int reputationCompetencyPerFieldMillis;

  /// Currencies tracked by the offline ledger.
  final List<String> currencyTypes;

  /// Patient-attraction vector weights (sum need not be 1; normalized later).
  final AttractionVectorWeights attractionWeights;

  /// New-clinician safe-practice thresholds.
  final OnboardingConfig onboarding;

  const ProgressionConfig({
    this.baseXpPerSession = 100,
    this.difficultyXpExponentMillis = 1200,
    this.trivialGrindSessionThreshold = 5,
    this.grindPenaltyMultiplierMillis = 500,
    this.baseStudyPointsPerSession = 3,
    this.baseSubspecialtyPointsPerSession = 1,
    this.reputationHalfLifeSeconds = 7 * 24 * 60 * 60, // 1 week
    this.reputationDecayBuckets = 4,
    this.reputationCompetencyPerFieldMillis =
        100, // 0.1 rep per field in millis
    this.currencyTypes = const [
      'cash',
      'study',
      'subspecialty',
      'xp',
      'reputation',
      'prestige',
    ],
    this.attractionWeights = const AttractionVectorWeights(),
    this.onboarding = const OnboardingConfig(),
  });
}

/// Weights for the three-factor patient-attraction vector.
class AttractionVectorWeights {
  final int reputationWeight;
  final int priceAccessibilityWeight;
  final int studyFieldCoverageWeight;

  const AttractionVectorWeights({
    this.reputationWeight = 1,
    this.priceAccessibilityWeight = 1,
    this.studyFieldCoverageWeight = 1,
  });
}

/// New-clinician onboarding parameters.
class OnboardingConfig {
  /// Maximum case tier visible in safe-practice mode.
  final int safePracticeMaxTier;

  /// Failure-impact multiplier in safe practice (fixed-point millis).
  final int safePracticeFailureMultiplierMillis;

  const OnboardingConfig({
    this.safePracticeMaxTier = 1,
    this.safePracticeFailureMultiplierMillis = 500,
  });
}
