import 'package:flutter_test/flutter_test.dart';
import 'package:psychosims/shared/model_profile_resolver.dart';
import 'package:psyconfig/psyconfig.dart';

Config _testConfig() {
  return const Config(
    schemaVersion: '1.0.0',
    network: NetworkConfig(
      apiBaseUrl: '',
      connectTimeoutMillis: 1000,
      receiveTimeoutMillis: 1000,
    ),
    model: ModelConfig(
      tierAPrimaryUrl: '',
      tierAFallbackUrl: '',
      tierBUrl: '',
      quantization: 'Q4_K_M',
      nCtx: 2048,
      nBatch: 512,
      tierAFloorBytes: 8 * 1024 * 1024 * 1024,
      tierBFloorBytes: 4 * 1024 * 1024 * 1024,
      tierAAvailableHeadroomBytes: 1 * 1024 * 1024 * 1024,
    ),
    inference: InferenceConfig(
      threadCount: 4,
      seed: 42,
      temperature: 0.7,
      topP: 0.9,
      topK: 40,
      repetitionPenalty: 1.0,
      stopTokens: ['fallback_stop'],
      kvCacheType: 'f16',
      greedyDecode: false,
    ),
    content: ContentConfig(
      bundledManifestPath: '',
      maxManifestBytes: 128 * 1024,
      maxManifestDepth: 8,
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
    secretsRefs: SecretsRefs(apiKeyRef: 'KEY'),
    modelProfiles: {
      'qwen2.5-1.5b': ModelProfile(
        modelKey: 'qwen2.5-1.5b',
        stopTokens: ['<|im_end|>'],
        recommendedNCtx: 2048,
      ),
      'phi-3.5-mini': ModelProfile(
        modelKey: 'phi-3.5-mini',
        stopTokens: ['<|end|>'],
        recommendedNCtx: 2048,
      ),
    },
  );
}

void main() {
  final config = _testConfig();
  const resolver = ModelProfileResolver();

  test('resolves Qwen profile from file name', () {
    final profile = resolver.resolve(
      '/models/qwen2.5-1.5b-instruct-q4_k_m.gguf',
      config,
    );
    expect(profile.modelKey, 'qwen2.5-1.5b');
    expect(profile.stopTokens, ['<|im_end|>']);
  });

  test('resolves Phi profile from file name', () {
    final profile = resolver.resolve(
      '/models/Phi-3.5-mini-instruct-Q4_K_M.gguf',
      config,
    );
    expect(profile.modelKey, 'phi-3.5-mini');
    expect(profile.stopTokens, ['<|end|>']);
  });

  test('falls back to inference stop tokens for unknown model', () {
    final profile = resolver.resolve(
      '/models/unknown-model.gguf',
      config,
    );
    expect(profile.modelKey, 'default');
    expect(profile.stopTokens, ['fallback_stop']);
  });
}
