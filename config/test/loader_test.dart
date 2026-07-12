import 'package:psyconfig/psyconfig.dart';
import 'package:test/test.dart';

void main() {
  group('loadConfig', () {
    test('loads a valid test config', () {
      final cfg = loadConfig(environment: 'test');
      expect(cfg.network.apiBaseUrl, equals('http://localhost:8080'));
      expect(cfg.model.nCtx, equals(512));
      expect(cfg.balance.startingClinicCurrency, equals(10000));
    });

    test('rejects a config with nBatch > nCtx', () {
      expect(
        () => validateConfig(
          const Config(
            schemaVersion: '1.0.0',
            network: NetworkConfig(
              apiBaseUrl: 'http://localhost',
              connectTimeoutMillis: 1000,
              receiveTimeoutMillis: 1000,
            ),
            model: ModelConfig(
              tierAPrimaryUrl: '',
              tierAFallbackUrl: '',
              tierBUrl: '',
              quantization: 'Q4_K_M',
              nCtx: 512,
              nBatch: 1024,
            ),
            promptBudget: PromptBudgetConfig(
              maxInputTokens: 256,
              maxOutputTokens: 64,
              prefixCacheTokens: 64,
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
          ),
        ),
        throwsA(isA<ConfigValidationException>()),
      );
    });
  });
}
