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

  /// Per-model inference profiles keyed by an identifier derived from the
  /// model file name or tier URL. Used to resolve model-specific stop tokens,
  /// EOS tokens, and recommended context/KV-cache settings.
  final Map<String, ModelProfile> modelProfiles;

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
    this.modelProfiles = const {},
  });

  /// Returns a copy with the supplied fields replaced.
  Config copyWith({
    String? schemaVersion,
    NetworkConfig? network,
    ModelConfig? model,
    InferenceConfig? inference,
    ContentConfig? content,
    PromptBudgetConfig? promptBudget,
    BalanceConfig? balance,
    FeatureFlags? featureFlags,
    SecretsRefs? secretsRefs,
    Map<String, ModelProfile>? modelProfiles,
  }) {
    return Config(
      schemaVersion: schemaVersion ?? this.schemaVersion,
      network: network ?? this.network,
      model: model ?? this.model,
      inference: inference ?? this.inference,
      content: content ?? this.content,
      promptBudget: promptBudget ?? this.promptBudget,
      balance: balance ?? this.balance,
      featureFlags: featureFlags ?? this.featureFlags,
      secretsRefs: secretsRefs ?? this.secretsRefs,
      modelProfiles: modelProfiles ?? this.modelProfiles,
    );
  }
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

  /// Load model weights via OS memory mapping (mmap) instead of reading them
  /// into heap. Mmap reduces peak resident memory and cold-start latency, but
  /// may be disabled on memory-constrained or sandboxed targets for
  /// compatibility testing.
  final bool useMmap;

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
    this.useMmap = true,
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

  /// Returns a copy with the supplied fields replaced.
  InferenceConfig copyWith({
    int? threadCount,
    int? seed,
    double? temperature,
    double? topP,
    int? topK,
    double? repetitionPenalty,
    List<String>? stopTokens,
    String? kvCacheType,
    bool? greedyDecode,
    String? grammarPath,
  }) {
    return InferenceConfig(
      threadCount: threadCount ?? this.threadCount,
      seed: seed ?? this.seed,
      temperature: temperature ?? this.temperature,
      topP: topP ?? this.topP,
      topK: topK ?? this.topK,
      repetitionPenalty: repetitionPenalty ?? this.repetitionPenalty,
      stopTokens: stopTokens ?? this.stopTokens,
      kvCacheType: kvCacheType ?? this.kvCacheType,
      greedyDecode: greedyDecode ?? this.greedyDecode,
      grammarPath: grammarPath ?? this.grammarPath,
    );
  }
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

/// Per-model inference profile.
///
/// Tokenizers, chat templates, and stop tokens are model-specific: Qwen2.5,
/// Phi-3.5-mini, and SmolLM2 tokenize differently and expect different chat
/// frames. The active model's profile is resolved from config at runtime so
/// the prompt assembler and generation loop never hard-code one.
class ModelProfile {
  /// Human-readable identifier, e.g. `qwen2.5-1.5b`.
  final String modelKey;

  /// Stop strings used to end generation for this model.
  final List<String> stopTokens;

  /// Optional explicit EOS token if it differs from the GGUF default.
  final String? eosToken;

  /// Recommended context window for this model/quantization combination.
  final int? recommendedNCtx;

  /// Recommended KV-cache quantization type for this model on constrained
  /// devices (e.g. `q8_0`).
  final String? recommendedKvCacheType;

  const ModelProfile({
    required this.modelKey,
    required this.stopTokens,
    this.eosToken,
    this.recommendedNCtx,
    this.recommendedKvCacheType,
  });
}

class SecretsRefs {
  final String apiKeyRef;

  const SecretsRefs({required this.apiKeyRef});
}
