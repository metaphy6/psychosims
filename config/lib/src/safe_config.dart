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
    },
    'model': <String, Object?>{
      'tierAPrimaryUrl': cfg.model.tierAPrimaryUrl,
      'tierAFallbackUrl': cfg.model.tierAFallbackUrl,
      'tierBUrl': cfg.model.tierBUrl,
      'quantization': cfg.model.quantization,
      'nCtx': cfg.model.nCtx,
      'nBatch': cfg.model.nBatch,
    },
    'promptBudget': <String, Object?>{
      'maxInputTokens': cfg.promptBudget.maxInputTokens,
      'maxOutputTokens': cfg.promptBudget.maxOutputTokens,
      'prefixCacheTokens': cfg.promptBudget.prefixCacheTokens,
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
