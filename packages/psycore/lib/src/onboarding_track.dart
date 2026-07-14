/// Configuration for the New Clinician onboarding track.
class OnboardingConfig {
  /// Maximum case tier visible in safe-practice mode.
  final int safePracticeMaxTier;

  /// Failure-impact multiplier in safe practice (fixed-point millis).
  final int failureMultiplierMillis;

  const OnboardingConfig({
    this.safePracticeMaxTier = 1,
    this.failureMultiplierMillis = 500,
  });
}

/// New Clinician safe-practice mode (§9): low-consequence early cases that
/// teach without punishing.
class OnboardingTrack {
  final OnboardingConfig config;

  const OnboardingTrack(this.config);

  /// True if a case of [tier] is available while onboarding.
  bool canPlayTier(int tier) =>
      config.safePracticeMaxTier <= 0 || tier <= config.safePracticeMaxTier;

  /// Applies the reduced failure impact to a raw reputation/XP penalty.
  int softenedPenalty(int rawPenalty) {
    if (rawPenalty >= 0) return rawPenalty;
    return (rawPenalty * config.failureMultiplierMillis) ~/ 1000;
  }

  /// A profile graduates from onboarding after resolving [completedCaseCount]
  /// successful cases.
  bool shouldGraduate(int completedCaseCount) => completedCaseCount >= 3;
}
