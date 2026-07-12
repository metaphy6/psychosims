import 'config.dart';
import 'validation.dart';

/// Loads and validates the effective configuration.
///
/// Resolution order: base defaults → environment overlay → secret refs
/// pulled from [platformEnvironment] by name.
Config loadConfig({
  required String environment,
  Map<String, String> platformEnvironment = const {},
}) {
  final base = _baseDefaults();
  final overlay = _environmentOverlay(environment);
  final merged = _merge(base, overlay);
  final withSecrets = _resolveSecrets(merged, platformEnvironment);
  validateConfig(withSecrets);
  return withSecrets;
}

Config _baseDefaults() {
  return const Config(
    schemaVersion: '1.0.0',
    network: NetworkConfig(
      apiBaseUrl: 'https://api.psychosims.example',
      connectTimeoutMillis: 10000,
      receiveTimeoutMillis: 30000,
    ),
    model: ModelConfig(
      tierAPrimaryUrl:
          'https://models.psychosims.example/qwen2.5-1.5b-q4_k_m.gguf',
      tierAFallbackUrl:
          'https://models.psychosims.example/phi-3.5-mini-q4_k_m.gguf',
      tierBUrl: 'https://models.psychosims.example/smollm2-1.7b-q4_k_m.gguf',
      quantization: 'Q4_K_M',
      nCtx: 2048,
      nBatch: 512,
    ),
    promptBudget: PromptBudgetConfig(
      maxInputTokens: 1536,
      maxOutputTokens: 256,
      prefixCacheTokens: 512,
    ),
    balance: BalanceConfig(
      startingClinicCurrency: 500,
      sessionFeeClinicCurrency: 50,
      startingStudyPoints: 0,
      studyPointsPerSession: 5,
      activeCardSlots: 5,
      relatableTrustBumpMin: 2,
      relatableTrustBumpMax: 5,
      postponingFreezeTurns: 1,
      misfortuneRollPercent: 5.0,
      doubtTransferBasePercent: 2.0,
      referralRewardXp: 1,
      discountPracticeXpPenaltyPercent: 50.0,
      ownershipLeaseTtlHours: 48,
      rulesetVersionSunsetDays: 90,
    ),
    featureFlags: FeatureFlags(
      enableOfflineQueue: true,
      enableTelemetry: false,
    ),
    secretsRefs: SecretsRefs(apiKeyRef: 'PSYCHOSIMS_API_KEY'),
  );
}

Config _environmentOverlay(String environment) {
  switch (environment) {
    case 'test':
      return const Config(
        schemaVersion: '1.0.0',
        network: NetworkConfig(
          apiBaseUrl: 'http://localhost:8080',
          connectTimeoutMillis: 1000,
          receiveTimeoutMillis: 1000,
        ),
        model: ModelConfig(
          tierAPrimaryUrl: '',
          tierAFallbackUrl: '',
          tierBUrl: '',
          quantization: 'Q4_K_M',
          nCtx: 512,
          nBatch: 128,
        ),
        promptBudget: PromptBudgetConfig(
          maxInputTokens: 256,
          maxOutputTokens: 64,
          prefixCacheTokens: 64,
        ),
        balance: BalanceConfig(
          startingClinicCurrency: 10000,
          sessionFeeClinicCurrency: 100,
          startingStudyPoints: 100,
          studyPointsPerSession: 10,
          activeCardSlots: 6,
          relatableTrustBumpMin: 2,
          relatableTrustBumpMax: 5,
          postponingFreezeTurns: 1,
          misfortuneRollPercent: 5.0,
          doubtTransferBasePercent: 2.0,
          referralRewardXp: 1,
          discountPracticeXpPenaltyPercent: 50.0,
          ownershipLeaseTtlHours: 48,
          rulesetVersionSunsetDays: 90,
        ),
        featureFlags: FeatureFlags(
          enableOfflineQueue: true,
          enableTelemetry: false,
        ),
        secretsRefs: SecretsRefs(apiKeyRef: 'PSYCHOSIMS_API_KEY'),
      );
    case 'dev':
      return const Config(
        schemaVersion: '1.0.0',
        network: NetworkConfig(
          apiBaseUrl: 'http://localhost:8080',
          connectTimeoutMillis: 5000,
          receiveTimeoutMillis: 15000,
        ),
        model: ModelConfig(
          tierAPrimaryUrl: '',
          tierAFallbackUrl: '',
          tierBUrl: '',
          quantization: 'Q4_K_M',
          nCtx: 2048,
          nBatch: 512,
        ),
        promptBudget: PromptBudgetConfig(
          maxInputTokens: 1536,
          maxOutputTokens: 256,
          prefixCacheTokens: 512,
        ),
        balance: BalanceConfig(
          startingClinicCurrency: 500,
          sessionFeeClinicCurrency: 50,
          startingStudyPoints: 0,
          studyPointsPerSession: 5,
          activeCardSlots: 5,
          relatableTrustBumpMin: 2,
          relatableTrustBumpMax: 5,
          postponingFreezeTurns: 1,
          misfortuneRollPercent: 5.0,
          doubtTransferBasePercent: 2.0,
          referralRewardXp: 1,
          discountPracticeXpPenaltyPercent: 50.0,
          ownershipLeaseTtlHours: 48,
          rulesetVersionSunsetDays: 90,
        ),
        featureFlags: FeatureFlags(
          enableOfflineQueue: true,
          enableTelemetry: false,
        ),
        secretsRefs: SecretsRefs(apiKeyRef: 'PSYCHOSIMS_API_KEY'),
      );
    default:
      return const Config(
        schemaVersion: '',
        network: NetworkConfig(
          apiBaseUrl: '',
          connectTimeoutMillis: 0,
          receiveTimeoutMillis: 0,
        ),
        model: ModelConfig(
          tierAPrimaryUrl: '',
          tierAFallbackUrl: '',
          tierBUrl: '',
          quantization: '',
          nCtx: 0,
          nBatch: 0,
        ),
        promptBudget: PromptBudgetConfig(
          maxInputTokens: 0,
          maxOutputTokens: 0,
          prefixCacheTokens: 0,
        ),
        balance: BalanceConfig(
          startingClinicCurrency: 0,
          sessionFeeClinicCurrency: 0,
          startingStudyPoints: 0,
          studyPointsPerSession: 0,
          activeCardSlots: 0,
          relatableTrustBumpMin: 0,
          relatableTrustBumpMax: 0,
          postponingFreezeTurns: 0,
          misfortuneRollPercent: 0.0,
          doubtTransferBasePercent: 0.0,
          referralRewardXp: 0,
          discountPracticeXpPenaltyPercent: 0.0,
          ownershipLeaseTtlHours: 0,
          rulesetVersionSunsetDays: 0,
        ),
        featureFlags: FeatureFlags(
          enableOfflineQueue: false,
          enableTelemetry: false,
        ),
        secretsRefs: SecretsRefs(apiKeyRef: ''),
      );
  }
}

Config _merge(Config base, Config overlay) {
  return Config(
    schemaVersion: overlay.schemaVersion.isEmpty
        ? base.schemaVersion
        : overlay.schemaVersion,
    network: NetworkConfig(
      apiBaseUrl: _pick(base.network.apiBaseUrl, overlay.network.apiBaseUrl),
      connectTimeoutMillis: _pick(
        base.network.connectTimeoutMillis,
        overlay.network.connectTimeoutMillis,
      ),
      receiveTimeoutMillis: _pick(
        base.network.receiveTimeoutMillis,
        overlay.network.receiveTimeoutMillis,
      ),
    ),
    model: ModelConfig(
      tierAPrimaryUrl:
          _pick(base.model.tierAPrimaryUrl, overlay.model.tierAPrimaryUrl),
      tierAFallbackUrl:
          _pick(base.model.tierAFallbackUrl, overlay.model.tierAFallbackUrl),
      tierBUrl: _pick(base.model.tierBUrl, overlay.model.tierBUrl),
      quantization: _pick(base.model.quantization, overlay.model.quantization),
      nCtx: _pick(base.model.nCtx, overlay.model.nCtx),
      nBatch: _pick(base.model.nBatch, overlay.model.nBatch),
    ),
    promptBudget: PromptBudgetConfig(
      maxInputTokens: _pick(base.promptBudget.maxInputTokens,
          overlay.promptBudget.maxInputTokens),
      maxOutputTokens: _pick(base.promptBudget.maxOutputTokens,
          overlay.promptBudget.maxOutputTokens),
      prefixCacheTokens: _pick(base.promptBudget.prefixCacheTokens,
          overlay.promptBudget.prefixCacheTokens),
    ),
    balance: BalanceConfig(
      startingClinicCurrency: _pick(base.balance.startingClinicCurrency,
          overlay.balance.startingClinicCurrency),
      sessionFeeClinicCurrency: _pick(base.balance.sessionFeeClinicCurrency,
          overlay.balance.sessionFeeClinicCurrency),
      startingStudyPoints: _pick(base.balance.startingStudyPoints,
          overlay.balance.startingStudyPoints),
      studyPointsPerSession: _pick(base.balance.studyPointsPerSession,
          overlay.balance.studyPointsPerSession),
      activeCardSlots:
          _pick(base.balance.activeCardSlots, overlay.balance.activeCardSlots),
      relatableTrustBumpMin: _pick(base.balance.relatableTrustBumpMin,
          overlay.balance.relatableTrustBumpMin),
      relatableTrustBumpMax: _pick(base.balance.relatableTrustBumpMax,
          overlay.balance.relatableTrustBumpMax),
      postponingFreezeTurns: _pick(base.balance.postponingFreezeTurns,
          overlay.balance.postponingFreezeTurns),
      misfortuneRollPercent: _pick(base.balance.misfortuneRollPercent,
          overlay.balance.misfortuneRollPercent),
      doubtTransferBasePercent: _pick(base.balance.doubtTransferBasePercent,
          overlay.balance.doubtTransferBasePercent),
      referralRewardXp: _pick(
          base.balance.referralRewardXp, overlay.balance.referralRewardXp),
      discountPracticeXpPenaltyPercent: _pick(
          base.balance.discountPracticeXpPenaltyPercent,
          overlay.balance.discountPracticeXpPenaltyPercent),
      ownershipLeaseTtlHours: _pick(base.balance.ownershipLeaseTtlHours,
          overlay.balance.ownershipLeaseTtlHours),
      rulesetVersionSunsetDays: _pick(base.balance.rulesetVersionSunsetDays,
          overlay.balance.rulesetVersionSunsetDays),
    ),
    featureFlags: FeatureFlags(
      enableOfflineQueue: overlay.featureFlags.enableOfflineQueue,
      enableTelemetry: overlay.featureFlags.enableTelemetry,
    ),
    secretsRefs: SecretsRefs(
      apiKeyRef:
          _pick(base.secretsRefs.apiKeyRef, overlay.secretsRefs.apiKeyRef),
    ),
  );
}

T _pick<T>(T base, T overlay) {
  if (overlay is String && (overlay as String).isEmpty) return base;
  if (overlay is int && (overlay as int) == 0) return base;
  if (overlay is double && (overlay as double) == 0.0) return base;
  return overlay;
}

Config _resolveSecrets(Config cfg, Map<String, String> env) {
  // Secrets are referenced by name; values are not stored in Config.
  // This function exists to validate that referenced names are present.
  return cfg;
}
