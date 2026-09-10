import 'config.dart';

/// Returns the effective config with secret values redacted.
///
/// Useful for startup logging and reproducibility: it shows what is active
/// without exposing referenced secret values.
Map<String, Object?> safeConfig(Config cfg) {
  return <String, Object?>{
    'schemaVersion': cfg.schemaVersion,
    'network': <String, Object?>{
      'apiBaseUrl': cfg.network.apiBaseUrl,
      'connectTimeoutMillis': cfg.network.connectTimeoutMillis,
      'receiveTimeoutMillis': cfg.network.receiveTimeoutMillis,
      'readTimeoutMillis': cfg.network.readTimeoutMillis,
      'mutationTimeoutMillis': cfg.network.mutationTimeoutMillis,
      'maxRetries': cfg.network.maxRetries,
      'retryBaseDelayMillis': cfg.network.retryBaseDelayMillis,
      'retryMaxDelayMillis': cfg.network.retryMaxDelayMillis,
      'maxRateLimitRetries': cfg.network.maxRateLimitRetries,
      'maxRetryAfterMillis': cfg.network.maxRetryAfterMillis,
      'maxResponseBytes': cfg.network.maxResponseBytes,
      'maxCanonicalReceiptBytes': cfg.network.maxCanonicalReceiptBytes,
      'maxReceiptActions': cfg.network.maxReceiptActions,
      'maxReceiptDeltas': cfg.network.maxReceiptDeltas,
      'maxBatchEnvelopes': cfg.network.maxBatchEnvelopes,
      'maxBatchBytes': cfg.network.maxBatchBytes,
      'maxQueueEntries': cfg.network.maxQueueEntries,
      'maxQueueBytes': cfg.network.maxQueueBytes,
      'allowInsecureLoopback': cfg.network.allowInsecureLoopback,
      'secureStorageNamespace': cfg.network.secureStorageNamespace,
      'oauthStateTtlSeconds': cfg.network.oauthStateTtlSeconds,
      'oauthChannel': cfg.network.oauthChannel,
      'oauthRedirectUri': cfg.network.oauthRedirectUri,
      'oauthAuthorizationOrigins': cfg.network.oauthAuthorizationOrigins,
    },
    'model': <String, Object?>{
      'tierAPrimaryUrl': cfg.model.tierAPrimaryUrl,
      'tierAFallbackUrl': cfg.model.tierAFallbackUrl,
      'tierBUrl': cfg.model.tierBUrl,
      'quantization': cfg.model.quantization,
      'nCtx': cfg.model.nCtx,
      'nBatch': cfg.model.nBatch,
    },
    'content': <String, Object?>{
      'bundledManifestPath': cfg.content.bundledManifestPath,
      'maxManifestBytes': cfg.content.maxManifestBytes,
      'maxManifestDepth': cfg.content.maxManifestDepth,
    },
    'promptBudget': <String, Object?>{
      'maxInputTokens': cfg.promptBudget.maxInputTokens,
      'maxOutputTokens': cfg.promptBudget.maxOutputTokens,
      'prefixCacheTokens': cfg.promptBudget.prefixCacheTokens,
      'maxRegenerationRetries': cfg.promptBudget.maxRegenerationRetries,
    },
    'balance': <String, Object?>{
      'startingClinicCurrency': cfg.balance.startingClinicCurrency,
      'sessionFeeClinicCurrency': cfg.balance.sessionFeeClinicCurrency,
      'startingStudyPoints': cfg.balance.startingStudyPoints,
      'studyPointsPerSession': cfg.balance.studyPointsPerSession,
      'activeCardSlots': cfg.balance.activeCardSlots,
      'relatableTrustBumpMin': cfg.balance.relatableTrustBumpMin,
      'relatableTrustBumpMax': cfg.balance.relatableTrustBumpMax,
      'postponingFreezeTurns': cfg.balance.postponingFreezeTurns,
      'misfortuneRollPercent': cfg.balance.misfortuneRollPercent,
      'doubtTransferBasePercent': cfg.balance.doubtTransferBasePercent,
      'referralRewardXp': cfg.balance.referralRewardXp,
      'discountPracticeXpPenaltyPercent':
          cfg.balance.discountPracticeXpPenaltyPercent,
      'ownershipLeaseTtlHours': cfg.balance.ownershipLeaseTtlHours,
      'rulesetVersionSunsetDays': cfg.balance.rulesetVersionSunsetDays,
    },
    'progression': <String, Object?>{
      'baseXpPerSession': cfg.progression.baseXpPerSession,
      'difficultyXpExponentMillis': cfg.progression.difficultyXpExponentMillis,
      'trivialGrindSessionThreshold':
          cfg.progression.trivialGrindSessionThreshold,
      'grindPenaltyMultiplierMillis':
          cfg.progression.grindPenaltyMultiplierMillis,
      'baseStudyPointsPerSession': cfg.progression.baseStudyPointsPerSession,
      'baseSubspecialtyPointsPerSession':
          cfg.progression.baseSubspecialtyPointsPerSession,
      'reputationHalfLifeSeconds': cfg.progression.reputationHalfLifeSeconds,
      'reputationDecayBuckets': cfg.progression.reputationDecayBuckets,
      'reputationCompetencyPerFieldMillis':
          cfg.progression.reputationCompetencyPerFieldMillis,
      'currencyTypes': cfg.progression.currencyTypes,
      'attractionWeights': <String, Object?>{
        'reputationWeight': cfg.progression.attractionWeights.reputationWeight,
        'priceAccessibilityWeight':
            cfg.progression.attractionWeights.priceAccessibilityWeight,
        'studyFieldCoverageWeight':
            cfg.progression.attractionWeights.studyFieldCoverageWeight,
      },
      'onboarding': <String, Object?>{
        'safePracticeMaxTier': cfg.progression.onboarding.safePracticeMaxTier,
        'safePracticeFailureMultiplierMillis':
            cfg.progression.onboarding.safePracticeFailureMultiplierMillis,
      },
    },
    'featureFlags': <String, Object?>{
      'enableOfflineQueue': cfg.featureFlags.enableOfflineQueue,
      'enableTelemetry': cfg.featureFlags.enableTelemetry,
    },
    'secretsRefs': <String, Object?>{
      'apiKeyRef': redacted(cfg.secretsRefs.apiKeyRef),
    },
  };
}

/// Redacts a secret reference so only its shape is logged.
String redacted(String ref) {
  if (ref.isEmpty) return '<empty>';
  return '${ref.substring(0, ref.length ~/ 2)}***';
}
