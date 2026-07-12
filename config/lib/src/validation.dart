import 'config.dart';

/// Validates the effective configuration and throws a clear error on mismatch.
void validateConfig(Config cfg) {
  final errors = <String>[];

  if (cfg.schemaVersion.isEmpty) {
    errors.add('schemaVersion must not be empty');
  }

  if (cfg.network.apiBaseUrl.isEmpty) {
    errors.add('network.apiBaseUrl must not be empty');
  }
  if (cfg.network.connectTimeoutMillis <= 0) {
    errors.add('network.connectTimeoutMillis must be positive');
  }
  if (cfg.network.receiveTimeoutMillis <= 0) {
    errors.add('network.receiveTimeoutMillis must be positive');
  }

  if (cfg.model.nCtx <= 0) errors.add('model.nCtx must be positive');
  if (cfg.model.nBatch <= 0) errors.add('model.nBatch must be positive');
  if (cfg.model.nBatch > cfg.model.nCtx) {
    errors.add('model.nBatch must not exceed model.nCtx');
  }

  if (cfg.promptBudget.maxInputTokens <= 0) {
    errors.add('promptBudget.maxInputTokens must be positive');
  }
  if (cfg.promptBudget.maxOutputTokens <= 0) {
    errors.add('promptBudget.maxOutputTokens must be positive');
  }
  if (cfg.promptBudget.maxInputTokens + cfg.promptBudget.maxOutputTokens >
      cfg.model.nCtx) {
    errors.add('prompt budget must fit inside model.nCtx');
  }

  if (cfg.balance.activeCardSlots <= 0) {
    errors.add('balance.activeCardSlots must be positive');
  }
  if (cfg.balance.misfortuneRollPercent < 0 ||
      cfg.balance.misfortuneRollPercent > 100) {
    errors.add('balance.misfortuneRollPercent must be in [0, 100]');
  }
  if (cfg.balance.doubtTransferBasePercent < 0 ||
      cfg.balance.doubtTransferBasePercent > 100) {
    errors.add('balance.doubtTransferBasePercent must be in [0, 100]');
  }
  if (cfg.balance.discountPracticeXpPenaltyPercent < 0 ||
      cfg.balance.discountPracticeXpPenaltyPercent > 100) {
    errors.add('balance.discountPracticeXpPenaltyPercent must be in [0, 100]');
  }
  if (cfg.balance.ownershipLeaseTtlHours <= 0) {
    errors.add('balance.ownershipLeaseTtlHours must be positive');
  }
  if (cfg.balance.rulesetVersionSunsetDays <= 0) {
    errors.add('balance.rulesetVersionSunsetDays must be positive');
  }

  if (cfg.secretsRefs.apiKeyRef.isEmpty) {
    errors.add('secretsRefs.apiKeyRef must not be empty');
  }

  if (errors.isNotEmpty) {
    throw ConfigValidationException(errors.join('; '));
  }
}

class ConfigValidationException implements Exception {
  final String message;
  ConfigValidationException(this.message);

  @override
  String toString() => 'ConfigValidationException: $message';
}
