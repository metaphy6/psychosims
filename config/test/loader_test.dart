import 'dart:io';
import 'dart:convert';

import 'package:psyconfig/psyconfig.dart';
import 'package:test/test.dart';
import 'package:yaml/yaml.dart';

void main() {
  group('loadConfig', () {
    test('generation retry policy preserves zero and rejects unbounded values',
        () {
      for (final environment in ['dev', 'test', 'prod']) {
        final cfg = loadConfig(environment: environment);
        expect(cfg.promptBudget.maxRegenerationRetries, 2);
        for (final retries in [0, 1, 2]) {
          final configured = cfg.copyWith(
              promptBudget:
                  cfg.promptBudget.copyWith(maxRegenerationRetries: retries));
          validateConfig(configured);
          expect(configured.promptBudget.copyWith().maxRegenerationRetries,
              retries);
          expect(
              (safeConfig(configured)['promptBudget']
                  as Map)['maxRegenerationRetries'],
              retries);
        }
        for (final retries in [-1, 3]) {
          expect(
              () => validateConfig(cfg.copyWith(
                  promptBudget: cfg.promptBudget
                      .copyWith(maxRegenerationRetries: retries))),
              throwsA(isA<ConfigValidationException>()));
        }
      }
    });
    test('bundled manifest is declared in the actual Flutter asset bundle', () {
      final pubspec = loadYaml(File('../app/pubspec.yaml').readAsStringSync());
      final assets = pubspec['flutter']['assets'] as YamlList;
      for (final environment in ['dev', 'test', 'prod']) {
        expect(
            assets,
            contains(loadConfig(environment: environment)
                .content
                .bundledManifestPath),
            reason: '$environment manifest must load through rootBundle');
      }
    });

    test('loads a valid test config', () {
      final cfg = loadConfig(environment: 'test');
      expect(cfg.network.apiBaseUrl, equals('http://localhost:8080'));
      expect(cfg.model.nCtx, equals(4096));
      expect(cfg.balance.startingClinicCurrency, equals(10000));
    });

    test('receipt limits cover a bounded full session and retain byte limits',
        () {
      final cfg = loadConfig(environment: 'test');
      final network = safeConfig(cfg)['network'] as Map<String, Object?>;
      expect(network['maxReceiptActions'], 120);
      expect(network['maxReceiptDeltas'], 1024);
      expect(network['maxCanonicalReceiptBytes'], 131072);
      final schema = jsonDecode(
          File('../packages/psychemas/schema/receipt.schema.json')
              .readAsStringSync()) as Map<String, dynamic>;
      final properties = schema['properties'] as Map<String, dynamic>;
      expect(network['maxReceiptActions'], properties['actions']['maxItems']);
      expect(network['maxReceiptDeltas'], properties['deltas']['maxItems']);
    });

    test('online policy is bounded and loopback is environment-specific', () {
      final prod = loadConfig(environment: 'prod');
      expect(prod.network.allowInsecureLoopback, isFalse);
      for (final environment in ['dev', 'test']) {
        final network = loadConfig(environment: environment).network;
        expect(network.allowInsecureLoopback, isTrue);
        expect(network.readTimeoutMillis, 10000);
        expect(network.mutationTimeoutMillis, 30000);
        expect(network.maxBatchEnvelopes, 64);
        expect(network.maxQueueBytes, 524288);
      }
      final safe = safeConfig(prod)['network'] as Map<String, Object?>;
      expect(safe['maxResponseBytes'], prod.network.maxResponseBytes);
      expect(safe['maxRetries'], prod.network.maxRetries);
    });

    test('rejects credentials and remote plaintext in API base URLs', () {
      final cfg = loadConfig(environment: 'dev');
      for (final url in [
        'http://example.org',
        'http://localhost.example.org',
        'https://user:password@example.org',
        'https://example.org?token=credential',
        'https://example.org#credential',
        'file:///tmp/service',
        'https://',
      ]) {
        expect(
          () => validateConfig(cfg.copyWith(
            network: cfg.network.copyWith(apiBaseUrl: url),
          )),
          throwsA(isA<ConfigValidationException>()),
          reason: url,
        );
      }
      for (final url in [
        'http://localhost:8080',
        'http://127.0.0.1:8080',
        'http://[::1]:8080',
      ]) {
        expect(
          () => validateConfig(cfg.copyWith(
            network: cfg.network.copyWith(apiBaseUrl: url),
          )),
          returnsNormally,
        );
        expect(
          () => validateConfig(cfg.copyWith(
            network: cfg.network
                .copyWith(apiBaseUrl: url, allowInsecureLoopback: false),
          )),
          throwsA(isA<ConfigValidationException>()),
        );
      }
    });

    test('rejects retry and transport budgets that defeat bounded sync', () {
      final cfg = loadConfig(environment: 'test');
      final network = cfg.network;
      for (final invalid in [
        network.copyWith(readTimeoutMillis: 0),
        network.copyWith(mutationTimeoutMillis: 300001),
        network.copyWith(maxRetries: 100),
        network.copyWith(retryBaseDelayMillis: 9000, retryMaxDelayMillis: 8000),
        network.copyWith(maxRateLimitRetries: 2),
        network.copyWith(maxRetryAfterMillis: 60001),
        network.copyWith(maxResponseBytes: 0),
        network.copyWith(maxCanonicalReceiptBytes: 0),
        network.copyWith(maxReceiptActions: 0),
        network.copyWith(maxReceiptActions: 121),
        network.copyWith(maxReceiptDeltas: 0),
        network.copyWith(maxReceiptDeltas: 1025),
        network.copyWith(maxBatchEnvelopes: 65),
        network.copyWith(maxQueueEntries: 0),
        network.copyWith(maxQueueBytes: 0),
        network.copyWith(maxBatchBytes: 0),
      ]) {
        expect(() => validateConfig(cfg.copyWith(network: invalid)),
            throwsA(isA<ConfigValidationException>()));
      }
      final noRetry = network.copyWith(maxRetries: 0, maxRateLimitRetries: 0);
      final reduced =
          noRetry.copyWith(maxReceiptActions: 100, maxReceiptDeltas: 512);
      expect(reduced.copyWith().maxReceiptActions, 100);
      expect(reduced.copyWith().maxReceiptDeltas, 512);
      expect(noRetry.maxRetries, 0);
      expect(() => validateConfig(cfg.copyWith(network: noRetry)),
          returnsNormally);
    });

    test(
        'browser auth stays disabled until a complete registration is configured',
        () {
      final cfg = loadConfig(environment: 'dev');
      expect(cfg.network.oauthChannel, isEmpty);
      expect(cfg.network.oauthRedirectUri, isEmpty);
      expect(cfg.network.oauthAuthorizationOrigins, isEmpty);
      final configured = cfg.network.copyWith(
        oauthChannel: 'direct_download',
        oauthRedirectUri: 'http://127.0.0.1:8765/callback',
        oauthAuthorizationOrigins: ['https://identity.example.org'],
      );
      expect(() => validateConfig(cfg.copyWith(network: configured)),
          returnsNormally);
      for (final invalid in [
        configured.copyWith(oauthChannel: ''),
        configured.copyWith(oauthRedirectUri: ''),
        configured.copyWith(oauthAuthorizationOrigins: []),
        configured.copyWith(oauthRedirectUri: 'http://example.org/callback'),
        configured.copyWith(
            oauthAuthorizationOrigins: ['http://identity.example.org']),
        configured.copyWith(
            oauthAuthorizationOrigins: ['https://identity.example.org/path']),
      ]) {
        expect(() => validateConfig(cfg.copyWith(network: invalid)),
            throwsA(isA<ConfigValidationException>()));
      }
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
              tierAFloorBytes: 8589934592,
              tierBFloorBytes: 4294967296,
              tierAAvailableHeadroomBytes: 1073741824,
            ),
            inference: const InferenceConfig(
              threadCount: 1,
              seed: 0,
              temperature: 0.0,
              topP: 1.0,
              topK: 1,
              repetitionPenalty: 1.0,
              stopTokens: [],
              kvCacheType: 'f16',
              greedyDecode: true,
            ),
            content: ContentConfig(
              bundledManifestPath: '',
              maxManifestBytes: 128 * 1024,
              maxManifestDepth: 8,
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
