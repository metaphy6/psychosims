/// Immutable, typed configuration object.
///
/// All modules receive this via DI. No raw environment reads outside `config/`.
class Config {
  /// Schema version of this config. Increment when the shape changes.
  final String schemaVersion;

  final NetworkConfig network;
  final ModelConfig model;
  final PromptBudgetConfig promptBudget;
  final BalanceConfig balance;
  final FeatureFlags featureFlags;
  final SecretsRefs secretsRefs;

  const Config({
    this.schemaVersion = '1.0.0',
    required this.network,
    required this.model,
    required this.promptBudget,
    required this.balance,
    required this.featureFlags,
    required this.secretsRefs,
  });
}

class NetworkConfig {
  final String apiBaseUrl;
  final int connectTimeoutMillis;
  final int receiveTimeoutMillis;

  const NetworkConfig({
    required this.apiBaseUrl,
    required this.connectTimeoutMillis,
    required this.receiveTimeoutMillis,
  });
}

class ModelConfig {
  final String tierAPrimaryUrl;
  final String tierAFallbackUrl;
  final String tierBUrl;
  final String quantization;
  final int nCtx;
  final int nBatch;

  const ModelConfig({
    required this.tierAPrimaryUrl,
    required this.tierAFallbackUrl,
    required this.tierBUrl,
    required this.quantization,
    required this.nCtx,
    required this.nBatch,
  });
}

class PromptBudgetConfig {
  final int maxInputTokens;
  final int maxOutputTokens;
  final int prefixCacheTokens;

  const PromptBudgetConfig({
    required this.maxInputTokens,
    required this.maxOutputTokens,
    required this.prefixCacheTokens,
  });
}

class BalanceConfig {
  final int startingClinicCurrency;
  final int sessionFeeClinicCurrency;
  final int startingStudyPoints;
  final int studyPointsPerSession;
  final int activeCardSlots;
  final int relatableTrustBumpMin;
  final int relatableTrustBumpMax;
  final int postponingFreezeTurns;
  final double misfortuneRollPercent;
  final double doubtTransferBasePercent;
  final int referralRewardXp;
  final double discountPracticeXpPenaltyPercent;
  final int ownershipLeaseTtlHours;
  final int rulesetVersionSunsetDays;

  const BalanceConfig({
    required this.startingClinicCurrency,
    required this.sessionFeeClinicCurrency,
    required this.startingStudyPoints,
    required this.studyPointsPerSession,
    required this.activeCardSlots,
    required this.relatableTrustBumpMin,
    required this.relatableTrustBumpMax,
    required this.postponingFreezeTurns,
    required this.misfortuneRollPercent,
    required this.doubtTransferBasePercent,
    required this.referralRewardXp,
    required this.discountPracticeXpPenaltyPercent,
    required this.ownershipLeaseTtlHours,
    required this.rulesetVersionSunsetDays,
  });
}

class FeatureFlags {
  final bool enableOfflineQueue;
  final bool enableTelemetry;

  const FeatureFlags({
    required this.enableOfflineQueue,
    required this.enableTelemetry,
  });

  /// Kill-switch helper: returns true only when the named flag is explicitly
  /// enabled. Unknown flags are treated as disabled.
  bool isEnabled(String name) {
    switch (name) {
      case 'offlineQueue':
        return enableOfflineQueue;
      case 'telemetry':
        return enableTelemetry;
      default:
        return false;
    }
  }
}

class SecretsRefs {
  final String apiKeyRef;

  const SecretsRefs({required this.apiKeyRef});
}
