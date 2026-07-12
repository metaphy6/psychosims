/// Immutable, typed configuration object.
///
/// All modules receive this via DI. No raw environment reads outside `config/`.
class Config {
  /// Schema version of this config. Increment when the shape changes.
  final String schemaVersion;

  final NetworkConfig network;
  final ModelConfig model;
  final InferenceConfig inference;
  final ContentConfig content;
  final PromptBudgetConfig promptBudget;
  final BalanceConfig balance;
  final FeatureFlags featureFlags;
  final SecretsRefs secretsRefs;

  const Config({
    this.schemaVersion = '1.0.0',
    required this.network,
    required this.model,
    required this.inference,
    required this.content,
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

  /// Expected final model file size, in bytes. Zero means unknown.
  final int modelFileSizeBytes;

  /// SHA-256 checksums keyed by tier URL. Empty placeholders are allowed
  /// until a manifest pins the real hashes.
  final Map<String, String> modelChecksums;

  /// Maximum retry attempts for a failed or corrupt model download.
  final int maxFetchRetries;

  /// Minimum free disk space required when the model size is unknown.
  final int minFreeDiskBytes;

  /// RAM floor for the Tier A primary model, in bytes.
  /// Devices below this total RAM are routed to Tier B.
  final int tierAFloorBytes;

  /// RAM floor for the Tier B fallback model, in bytes.
  /// Devices below this floor are considered unsupported.
  final int tierBFloorBytes;

  /// Minimum available RAM headroom required to keep Tier A primary.
  /// Devices with less available RAM are routed to the Tier A fallback.
  final int tierAAvailableHeadroomBytes;

  const ModelConfig({
    required this.tierAPrimaryUrl,
    required this.tierAFallbackUrl,
    required this.tierBUrl,
    required this.quantization,
    required this.nCtx,
    required this.nBatch,
    this.modelFileSizeBytes = 0,
    this.modelChecksums = const {},
    this.maxFetchRetries = 3,
    this.minFreeDiskBytes = 3221225472, // 3 GiB
    this.tierAFloorBytes = 8589934592, // 8 GiB
    this.tierBFloorBytes = 4294967296, // 4 GiB
    this.tierAAvailableHeadroomBytes = 1073741824, // 1 GiB
  });
}

class InferenceConfig {
  final int threadCount;
  final int seed;
  final double temperature;
  final double topP;
  final int topK;
  final double repetitionPenalty;
  final List<String> stopTokens;
  final String kvCacheType;
  final bool greedyDecode;
  final String? grammarPath;

  const InferenceConfig({
    required this.threadCount,
    required this.seed,
    required this.temperature,
    required this.topP,
    required this.topK,
    required this.repetitionPenalty,
    required this.stopTokens,
    required this.kvCacheType,
    required this.greedyDecode,
    this.grammarPath,
  });
}

class ContentConfig {
  /// Asset key or filesystem path for the bundled PoC manifest.
  final String bundledManifestPath;

  /// Maximum manifest byte budget.
  final int maxManifestBytes;

  /// Maximum nesting depth for JSON decoding.
  final int maxManifestDepth;

  const ContentConfig({
    required this.bundledManifestPath,
    required this.maxManifestBytes,
    required this.maxManifestDepth,
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
