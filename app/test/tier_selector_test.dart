import 'package:flutter_test/flutter_test.dart';
import 'package:psyconfig/psyconfig.dart';
import 'package:psychosims/shared/tier_selector.dart';

Config _testConfig() {
  return const Config(
    schemaVersion: '1.0.0',
    network: NetworkConfig(
      apiBaseUrl: '',
      connectTimeoutMillis: 1000,
      receiveTimeoutMillis: 1000,
    ),
    model: ModelConfig(
      tierAPrimaryUrl: 'https://models.example/qwen2.5-1.5b-q4_k_m.gguf',
      tierAFallbackUrl: 'https://models.example/phi-3.5-mini-q4_k_m.gguf',
      tierBUrl: 'https://models.example/smollm2-1.7b-q4_k_m.gguf',
      quantization: 'Q4_K_M',
      nCtx: 2048,
      nBatch: 512,
      modelChecksums: {
        'https://models.example/qwen2.5-1.5b-q4_k_m.gguf': 'sha256:aaa',
        'https://models.example/phi-3.5-mini-q4_k_m.gguf': 'sha256:bbb',
        'https://models.example/smollm2-1.7b-q4_k_m.gguf': 'sha256:ccc',
      },
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
      stopTokens: [],
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
  );
}

const _capability = DeviceCapability(
  totalRamBytes: 8589934592,
  availableRamBytes: 4294967296,
  abi: 'arm64-v8a',
  hasAvx2: false,
  cpuCount: 8,
  isEmulator: false,
);

void main() {
  final selector = TierSelector();
  final config = _testConfig();

  group('TierSelector.select', () {
    test('4 GB RAM device routes to Tier B', () {
      final device =
          _capability.copyWith(totalRamBytes: 4 * 1024 * 1024 * 1024);
      expect(selector.select(device, config), TierSelection.tierB);
    });

    test('8 GB RAM arm64 device routes to Tier A primary', () {
      final device = _capability.copyWith(
        totalRamBytes: 8 * 1024 * 1024 * 1024,
        availableRamBytes: 4 * 1024 * 1024 * 1024,
        abi: 'arm64-v8a',
      );
      expect(selector.select(device, config), TierSelection.tierAPrimary);
    });

    test('x86_64 desktop with AVX2 routes to Tier A primary', () {
      final device = _capability.copyWith(
        totalRamBytes: 16 * 1024 * 1024 * 1024,
        availableRamBytes: 8 * 1024 * 1024 * 1024,
        abi: 'x86_64',
        hasAvx2: true,
      );
      expect(selector.select(device, config), TierSelection.tierAPrimary);
    });

    test('x86_64 desktop without AVX2 routes to Tier B', () {
      final device = _capability.copyWith(
        totalRamBytes: 16 * 1024 * 1024 * 1024,
        availableRamBytes: 8 * 1024 * 1024 * 1024,
        abi: 'x86_64',
        hasAvx2: false,
      );
      expect(selector.select(device, config), TierSelection.tierB);
    });

    test('emulator routes to Tier A fallback', () {
      final device = _capability.copyWith(
        totalRamBytes: 12 * 1024 * 1024 * 1024,
        availableRamBytes: 6 * 1024 * 1024 * 1024,
        isEmulator: true,
      );
      expect(selector.select(device, config), TierSelection.tierAFallback);
    });

    test('low available RAM routes to Tier A fallback', () {
      final device = _capability.copyWith(
        totalRamBytes: 12 * 1024 * 1024 * 1024,
        availableRamBytes: 512 * 1024 * 1024,
      );
      expect(selector.select(device, config), TierSelection.tierAFallback);
    });

    test('32-bit ABI routes to Tier B', () {
      final device = _capability.copyWith(abi: 'armeabi-v7a');
      expect(selector.select(device, config), TierSelection.tierB);
    });
  });

  group('TierSelector.resolveSource', () {
    test('returns primary URL, checksum, and file name', () {
      final source = selector.resolveSource(TierSelection.tierAPrimary, config);
      expect(source.url, config.model.tierAPrimaryUrl);
      expect(source.checksum, 'sha256:aaa');
      expect(source.fileName, 'qwen2.5-1.5b-q4_k_m.gguf');
      expect(source.quantization, 'Q4_K_M');
      expect(source.tier, TierSelection.tierAPrimary);
    });

    test('returns fallback URL and checksum', () {
      final source =
          selector.resolveSource(TierSelection.tierAFallback, config);
      expect(source.url, config.model.tierAFallbackUrl);
      expect(source.checksum, 'sha256:bbb');
      expect(source.fileName, 'phi-3.5-mini-q4_k_m.gguf');
    });

    test('returns Tier B URL and checksum', () {
      final source = selector.resolveSource(TierSelection.tierB, config);
      expect(source.url, config.model.tierBUrl);
      expect(source.checksum, 'sha256:ccc');
      expect(source.fileName, 'smollm2-1.7b-q4_k_m.gguf');
    });

    test('returns null checksum when not pinned', () {
      final unpinned = _testConfig().copyWithModelChecksums({});
      final source = selector.resolveSource(TierSelection.tierB, unpinned);
      expect(source.checksum, isNull);
    });
  });
}

extension _DeviceCapabilityCopy on DeviceCapability {
  DeviceCapability copyWith({
    int? totalRamBytes,
    int? availableRamBytes,
    String? abi,
    bool? hasAvx2,
    int? cpuCount,
    bool? isEmulator,
  }) {
    return DeviceCapability(
      totalRamBytes: totalRamBytes ?? this.totalRamBytes,
      availableRamBytes: availableRamBytes ?? this.availableRamBytes,
      abi: abi ?? this.abi,
      hasAvx2: hasAvx2 ?? this.hasAvx2,
      cpuCount: cpuCount ?? this.cpuCount,
      isEmulator: isEmulator ?? this.isEmulator,
    );
  }
}

extension _ConfigCopy on Config {
  Config copyWithModelChecksums(Map<String, String> checksums) {
    return Config(
      schemaVersion: schemaVersion,
      network: network,
      model: ModelConfig(
        tierAPrimaryUrl: model.tierAPrimaryUrl,
        tierAFallbackUrl: model.tierAFallbackUrl,
        tierBUrl: model.tierBUrl,
        quantization: model.quantization,
        nCtx: model.nCtx,
        nBatch: model.nBatch,
        modelFileSizeBytes: model.modelFileSizeBytes,
        modelChecksums: checksums,
        maxFetchRetries: model.maxFetchRetries,
        minFreeDiskBytes: model.minFreeDiskBytes,
        tierAFloorBytes: model.tierAFloorBytes,
        tierBFloorBytes: model.tierBFloorBytes,
        tierAAvailableHeadroomBytes: model.tierAAvailableHeadroomBytes,
      ),
      inference: inference,
      content: content,
      promptBudget: promptBudget,
      balance: balance,
      featureFlags: featureFlags,
      secretsRefs: secretsRefs,
    );
  }
}
