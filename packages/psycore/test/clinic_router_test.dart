import 'package:psychemas/psychemas.dart';
import 'package:psycore/psycore.dart';
import 'package:test/test.dart';

void main() {
  group('ClinicEconomy', () {
    const economy = ClinicEconomy(ClinicEconomyConfig(
      officeRentMicros: 5000000,
      officePurchaseMicros: 50000000,
      officeResaleMultiplierMillis: 700,
      monthlyOverheadMicros: 1000000,
      taxBrackets: [
        (20000000, 0),
        (100000000, 100),
        (9223372036854775807, 200),
      ],
      auditProbabilityMillis: 50,
      auditOvermedicationPenalty: 10,
    ));

    test('rent and purchase produce keyed debit events', () {
      final rent = economy.rentOffice(
        officeId: 'office-1',
        idempotencyKey: 'ik-rent',
        timestampSeconds: 1,
      );
      expect(rent.kind, 'office_rent');
      expect(rent.amountMicros, -5000000);

      final buy = economy.buyOffice(
        officeId: 'office-1',
        idempotencyKey: 'ik-buy',
        timestampSeconds: 1,
      );
      expect(buy.amountMicros, -50000000);
    });

    test('resale value is a fraction of purchase price', () {
      expect(economy.resaleValueMicros(), 35000000);
    });

    test('progressive tax brackets apply', () {
      expect(economy.taxOwedMicros(10000000), 0);
      expect(economy.taxOwedMicros(30000000), 1000000); // 10% of 10M above 20M
      expect(economy.taxOwedMicros(120000000), greaterThan(1000000));
    });

    test('default brackets stay progressive and tax the top band', () {
      // Regression: the shipped default must keep an open-ended top bracket so
      // income above the top threshold is taxed, not left untaxed.
      const defaultEconomy = ClinicEconomy(ClinicEconomyConfig());
      // 0–20M tax-free allowance.
      expect(defaultEconomy.taxOwedMicros(10000000), 0);
      // 50M: (50-20)M @ 10% = 3M.
      expect(defaultEconomy.taxOwedMicros(50000000), 3000000);
      // 150M: 80M @ 10% + 50M @ 20% = 8M + 10M = 18M.
      expect(defaultEconomy.taxOwedMicros(150000000), 18000000);
      // 250M: 80M @ 10% + 150M @ 20% = 8M + 30M = 38M — the top bracket is
      // open-ended, so income above 100M does not escape tax.
      expect(defaultEconomy.taxOwedMicros(250000000), 38000000);
      // Effective rate is monotonically non-decreasing (genuinely progressive).
      final r50 = defaultEconomy.taxOwedMicros(50000000) / 50000000;
      final r150 = defaultEconomy.taxOwedMicros(150000000) / 150000000;
      final r250 = defaultEconomy.taxOwedMicros(250000000) / 250000000;
      expect(r150, greaterThan(r50));
      expect(r250, greaterThan(r150));
      // Income above the top threshold is taxed (would be equal under the old
      // capped top bracket that let it escape).
      expect(
        defaultEconomy.taxOwedMicros(200000000),
        greaterThan(defaultEconomy.taxOwedMicros(100000000)),
      );
    });

    test('audit triggers deterministically from roll', () {
      final (audited, penalty) = economy.audit(
        rollMillis: 10,
        overmedicationDeltaCount: 2,
      );
      expect(audited, isTrue);
      expect(penalty, 20);

      final (notAudited, _) = economy.audit(
        rollMillis: 900,
        overmedicationDeltaCount: 2,
      );
      expect(notAudited, isFalse);
    });
  });

  group('OfflineCaseRouter', () {
    const router = OfflineCaseRouter(OfflineCaseRouterConfig(
      socialChronicBiasThreshold: 20,
      chaosRollProbabilityMillis: 50,
      chaosTenureGate: 3,
    ));

    test('router seed is deterministic for the same profile and cursor', () {
      final profile = CareerProfile(
        profileId: 'p1',
        rulesetVersion: '0.1.0',
        snapshotBalancesMicros: const {'reputation': 100},
      );
      final a = router.nextCase(
        profile: profile,
        tierBias: 2,
        playerLevel: 5,
        cursor: 7,
        rootSeed: 123,
      );
      final b = router.nextCase(
        profile: profile,
        tierBias: 2,
        playerLevel: 5,
        cursor: 7,
        rootSeed: 123,
      );
      expect(a.seed, b.seed);
      expect(a.tier, b.tier);
      expect(a.memoryClass, b.memoryClass);
    });

    test('low-reputation profiles see more stateless cases', () {
      final profile = CareerProfile(
        profileId: 'p2',
        rulesetVersion: '0.1.0',
        snapshotBalancesMicros: const {'reputation': 10},
      );
      final seed = router.nextCase(
        profile: profile,
        tierBias: 1,
        playerLevel: 1,
        cursor: 0,
        rootSeed: 1,
      );
      expect(seed.memoryClass, MemoryClass.stateless);
    });

    test('chaos roll only fires above tenure gate', () {
      final profile = CareerProfile(
        profileId: 'p3',
        rulesetVersion: '0.1.0',
        snapshotBalancesMicros: const {'reputation': 100},
      );
      final lowLevel = router.nextCase(
        profile: profile,
        tierBias: 2,
        playerLevel: 1,
        cursor: 99,
        rootSeed: 1,
      );
      expect(lowLevel.misfortune, isFalse);
    });
  });

  group('StrategicExitResolver', () {
    const resolver = StrategicExitResolver();

    test('reject is neutral', () {
      final result = resolver.resolve(StrategicExitChoice.reject);
      expect(result.xpDelta, 0);
      expect(result.reputationDelta, 0);
    });

    test('refer gives small XP reward', () {
      final result = resolver.resolve(StrategicExitChoice.refer);
      expect(result.xpDelta, 1);
    });

    test('force penalises reputation and agitation', () {
      final result = resolver.resolve(StrategicExitChoice.force);
      expect(result.reputationDelta, lessThan(0));
      expect(result.agitationDelta, greaterThan(0));
      expect(result.caseLost, isTrue);
    });
  });
}
