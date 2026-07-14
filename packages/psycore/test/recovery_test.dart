import 'package:psychemas/psychemas.dart';
import 'package:psycore/psycore.dart';
import 'package:test/test.dart';

void main() {
  group('RecoveryController', () {
    const controller = RecoveryController(RecoveryControllerConfig(
      discountPracticeReputationThreshold: 30,
      discountPracticeXpMultiplierMillis: 500,
      sabbaticalCompetencyPerFieldMillis: 200,
      recoveryCooldownSeconds: 100,
    ));

    test('allows Discount Practice when reputation is critically low', () {
      expect(
        controller.canEnterDiscountPractice(
          reputation: 20,
          currentMode: RecoveryMode.normal,
        ),
        isTrue,
      );
      expect(
        controller.canEnterDiscountPractice(
          reputation: 50,
          currentMode: RecoveryMode.normal,
        ),
        isFalse,
      );
    });

    test('applies 50% XP penalty in Discount Practice', () {
      expect(controller.discountedXp(100), 50);
    });

    test('restores reputation during Academic Sabbatical', () {
      expect(controller.sabbaticalReputationFloor(5), 1); // 5*200/1000 = 1
    });

    test('mode transitions are atomic and guarded', () {
      expect(
        controller.enterMode(
          target: RecoveryMode.discountPractice,
          currentMode: RecoveryMode.normal,
          reputation: 20,
        ),
        RecoveryMode.discountPractice,
      );
      expect(
        controller.enterMode(
          target: RecoveryMode.discountPractice,
          currentMode: RecoveryMode.normal,
          reputation: 100,
        ),
        RecoveryMode.normal,
      );
    });
  });

  group('PressureCalculator', () {
    const calc = PressureCalculator(PressureCalculatorConfig(
      pressurePerSessionMillis: 100,
      pressurePerHighTierMillis: 150,
      pressureDailyDecayMillis: 20,
    ));

    test('pressure rises with sessions and high-tier cases', () {
      final after = calc.afterSession(
        current: const OperationalPressure(),
        caseTier: 1,
        nowSeconds: 0,
      );
      expect(after.valueMillis, 100);

      final afterHigh = calc.afterSession(
        current: const OperationalPressure(),
        caseTier: 3,
        nowSeconds: 0,
      );
      expect(afterHigh.valueMillis, 250);
    });

    test('pressure caps at 1000', () {
      var current = const OperationalPressure();
      for (var i = 0; i < 20; i++) {
        current = calc.afterSession(
          current: current,
          caseTier: 1,
          nowSeconds: i,
        );
      }
      expect(current.valueMillis, 1000);
      expect(current.category, PressureCategory.atRisk);
    });

    test('pressure decays over time', () {
      final high =
          const OperationalPressure(valueMillis: 500, lastUpdatedSeconds: 0);
      final decayed = calc.decay(current: high, nowSeconds: 2 * 24 * 60 * 60);
      expect(decayed.valueMillis, lessThan(high.valueMillis));
    });
  });

  group('CooldownTracker', () {
    test('is ready only after duration elapses', () {
      final tracker = const CooldownTracker().start(
        nowSeconds: 100,
        durationSeconds: 50,
      );
      expect(tracker.isReady(140), isFalse);
      expect(tracker.isReady(150), isTrue);
      expect(tracker.isReady(200), isTrue);
    });

    test('cannot be skipped by winding clock backward', () {
      final tracker = const CooldownTracker().start(
        nowSeconds: 100,
        durationSeconds: 50,
      );
      expect(tracker.isReady(90), isFalse);
    });
  });
}
