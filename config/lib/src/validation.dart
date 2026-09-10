import 'config.dart';

/// Validates the effective configuration and throws a clear error on mismatch.
void validateConfig(Config cfg) {
  final errors = <String>[];

  if (cfg.schemaVersion.isEmpty) {
    errors.add('schemaVersion must not be empty');
  }

  final network = cfg.network;
  final endpoint = Uri.tryParse(network.apiBaseUrl);
  final loopback = endpoint != null &&
      const {'localhost', '127.0.0.1', '::1'}.contains(endpoint.host);
  if (endpoint == null ||
      endpoint.host.isEmpty ||
      endpoint.userInfo.isNotEmpty ||
      endpoint.hasQuery ||
      endpoint.hasFragment ||
      !(endpoint.scheme == 'https' ||
          (endpoint.scheme == 'http' &&
              loopback &&
              network.allowInsecureLoopback))) {
    errors.add('network.apiBaseUrl requires HTTPS or enabled loopback HTTP '
        'without credentials, query or fragment');
  }
  void range(String field, int value, int min, int max) {
    if (value < min || value > max) {
      errors.add('network.$field must be in [$min, $max]');
    }
  }

  range('connectTimeoutMillis', network.connectTimeoutMillis, 1, 300000);
  range('receiveTimeoutMillis', network.receiveTimeoutMillis, 1, 300000);
  range('readTimeoutMillis', network.readTimeoutMillis, 1, 300000);
  range('mutationTimeoutMillis', network.mutationTimeoutMillis, 1, 300000);
  range('maxRetries', network.maxRetries, 0, 8);
  range('retryBaseDelayMillis', network.retryBaseDelayMillis, 1, 60000);
  range('retryMaxDelayMillis', network.retryMaxDelayMillis, 1, 60000);
  if (network.retryBaseDelayMillis > network.retryMaxDelayMillis) {
    errors.add(
        'network.retryBaseDelayMillis must not exceed retryMaxDelayMillis');
  }
  range('maxRateLimitRetries', network.maxRateLimitRetries, 0, 1);
  range('maxRetryAfterMillis', network.maxRetryAfterMillis, 1, 60000);
  range('maxResponseBytes', network.maxResponseBytes, 1, 8 * 1024 * 1024);
  range(
      'maxCanonicalReceiptBytes', network.maxCanonicalReceiptBytes, 1, 131072);
  range('maxReceiptActions', network.maxReceiptActions, 1, 120);
  range('maxReceiptDeltas', network.maxReceiptDeltas, 1, 1024);
  range('maxBatchEnvelopes', network.maxBatchEnvelopes, 1, 64);
  range('maxBatchBytes', network.maxBatchBytes, 1, 524288);
  range('maxQueueEntries', network.maxQueueEntries, 1, 10000);
  range('maxQueueBytes', network.maxQueueBytes, 1, 5 * 1024 * 1024);
  range('oauthStateTtlSeconds', network.oauthStateTtlSeconds, 1, 600);
  final hasBrowserConfig = network.oauthChannel.isNotEmpty ||
      network.oauthRedirectUri.isNotEmpty ||
      network.oauthAuthorizationOrigins.isNotEmpty;
  if (hasBrowserConfig) {
    if (!RegExp(r'^[a-z][a-z0-9_]{0,63}$').hasMatch(network.oauthChannel)) {
      errors.add('network.oauthChannel requires a registered channel');
    }
    final redirect = Uri.tryParse(network.oauthRedirectUri);
    if (redirect == null ||
        redirect.host.isEmpty ||
        redirect.userInfo.isNotEmpty ||
        redirect.hasQuery ||
        redirect.hasFragment ||
        !(redirect.scheme == 'https' ||
            (redirect.scheme == 'http' &&
                network.allowInsecureLoopback &&
                const {'localhost', '127.0.0.1', '::1'}
                    .contains(redirect.host)))) {
      errors.add(
          'network.oauthRedirectUri requires a registered HTTPS or enabled loopback callback');
    }
    if (network.oauthAuthorizationOrigins.isEmpty ||
        network.oauthAuthorizationOrigins.length > 8) {
      errors.add(
          'network.oauthAuthorizationOrigins requires 1-8 registered origins');
    }
    for (final value in network.oauthAuthorizationOrigins) {
      final origin = Uri.tryParse(value);
      if (origin == null ||
          origin.scheme != 'https' ||
          origin.host.isEmpty ||
          origin.userInfo.isNotEmpty ||
          origin.hasQuery ||
          origin.hasFragment ||
          origin.path.isNotEmpty ||
          origin.origin != value) {
        errors.add(
            'network.oauthAuthorizationOrigins requires exact HTTPS origins');
      }
    }
  }
  if (!RegExp(r'^[a-z][a-z0-9._-]{0,63}$')
      .hasMatch(network.secureStorageNamespace)) {
    errors.add('network.secureStorageNamespace must be a bounded identifier');
  }

  if (cfg.model.nCtx <= 0) errors.add('model.nCtx must be positive');
  if (cfg.model.nBatch <= 0) errors.add('model.nBatch must be positive');
  if (cfg.model.nBatch > cfg.model.nCtx) {
    errors.add('model.nBatch must not exceed model.nCtx');
  }
  // mmap is a boolean flag; no range validation needed beyond the typed
  // default, but the field must be present in the merged config.
  if (cfg.model.modelFileSizeBytes < 0) {
    errors.add('model.modelFileSizeBytes must be non-negative');
  }
  if (cfg.model.maxFetchRetries < 0) {
    errors.add('model.maxFetchRetries must be non-negative');
  }
  if (cfg.model.minFreeDiskBytes < 0) {
    errors.add('model.minFreeDiskBytes must be non-negative');
  }
  if (cfg.model.tierAFloorBytes < cfg.model.tierBFloorBytes) {
    errors.add('model.tierAFloorBytes must be >= model.tierBFloorBytes');
  }
  if (cfg.model.tierBFloorBytes <= 0) {
    errors.add('model.tierBFloorBytes must be positive');
  }
  if (cfg.model.tierAAvailableHeadroomBytes < 0) {
    errors.add('model.tierAAvailableHeadroomBytes must be non-negative');
  }

  if (cfg.inference.threadCount <= 0) {
    errors.add('inference.threadCount must be positive');
  }
  if (cfg.inference.temperature < 0) {
    errors.add('inference.temperature must be non-negative');
  }
  if (cfg.inference.topP < 0 || cfg.inference.topP > 1) {
    errors.add('inference.topP must be in [0, 1]');
  }
  if (cfg.inference.topK < 0) {
    errors.add('inference.topK must be non-negative');
  }
  if (cfg.inference.repetitionPenalty < 0) {
    errors.add('inference.repetitionPenalty must be non-negative');
  }
  if (cfg.inference.kvCacheType.isEmpty) {
    errors.add('inference.kvCacheType must not be empty');
  }

  for (final entry in cfg.modelProfiles.entries) {
    if (entry.key.isEmpty) {
      errors.add('modelProfiles keys must not be empty');
    }
    if (entry.value.modelKey.isEmpty) {
      errors.add('modelProfiles[${entry.key}].modelKey must not be empty');
    }
  }

  if (cfg.promptBudget.maxInputTokens <= 0) {
    errors.add('promptBudget.maxInputTokens must be positive');
  }
  if (cfg.promptBudget.maxOutputTokens <= 0) {
    errors.add('promptBudget.maxOutputTokens must be positive');
  }
  if (cfg.promptBudget.maxRegenerationRetries < 0 ||
      cfg.promptBudget.maxRegenerationRetries > 2) {
    errors.add('promptBudget.maxRegenerationRetries must be in [0, 2]');
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
