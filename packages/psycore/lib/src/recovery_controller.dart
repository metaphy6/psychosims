import 'package:psychemas/psychemas.dart';

/// Configuration values consumed by [RecoveryController].
class RecoveryControllerConfig {
  final int discountPracticeReputationThreshold;
  final int discountPracticeXpMultiplierMillis;
  final int sabbaticalCompetencyPerFieldMillis;
  final int recoveryCooldownSeconds;

  const RecoveryControllerConfig({
    this.discountPracticeReputationThreshold = 30,
    this.discountPracticeXpMultiplierMillis = 500,
    this.sabbaticalCompetencyPerFieldMillis = 200,
    this.recoveryCooldownSeconds = 24 * 60 * 60,
  });
}

/// Coordinates recovery-mode transitions and their effects (§14).
///
/// All decisions are deterministic functions of the supplied profile state.
class RecoveryController {
  final RecoveryControllerConfig config;

  const RecoveryController(this.config);

  /// True when the profile is eligible to enter Discount Practice.
  bool canEnterDiscountPractice({
    required int reputation,
    required RecoveryMode currentMode,
  }) {
    return currentMode != RecoveryMode.discountPractice &&
        reputation <= config.discountPracticeReputationThreshold;
  }

  /// True when the profile is eligible to enter Academic Sabbatical.
  bool canEnterSabbatical({required RecoveryMode currentMode}) {
    return currentMode != RecoveryMode.academicSabbatical;
  }

  /// Returns the next mode, or [currentMode] if the transition is invalid.
  RecoveryMode enterMode({
    required RecoveryMode target,
    required RecoveryMode currentMode,
    required int reputation,
  }) {
    return switch (target) {
      RecoveryMode.discountPractice => canEnterDiscountPractice(
              reputation: reputation, currentMode: currentMode)
          ? RecoveryMode.discountPractice
          : currentMode,
      RecoveryMode.academicSabbatical =>
        canEnterSabbatical(currentMode: currentMode)
            ? RecoveryMode.academicSabbatical
            : currentMode,
      RecoveryMode.normal => RecoveryMode.normal,
    };
  }

  /// Applies the Discount Practice XP penalty.
  int discountedXp(int baseXp) {
    return (baseXp * config.discountPracticeXpMultiplierMillis) ~/ 1000;
  }

  /// Computes reputation restored by a sabbatical.
  int sabbaticalReputationFloor(int totalStudyFields) {
    return (totalStudyFields * config.sabbaticalCompetencyPerFieldMillis) ~/
        1000;
  }
}
