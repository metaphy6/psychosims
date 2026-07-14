import 'package:psychemas/psychemas.dart';
import 'package:psycore/psycore.dart';
import 'package:test/test.dart';

void main() {
  group('XpCurve', () {
    const curve = XpCurve(XpCurveConfig(
      baseXpPerSession: 100,
      difficultyXpExponentMillis: 1200,
      trivialGrindSessionThreshold: 3,
      grindPenaltyMultiplierMillis: 500,
    ));

    test('harder cases give more XP', () {
      final t1 = curve.reward(difficultyTier: 1, sessionCount: 0);
      final t3 = curve.reward(difficultyTier: 3, sessionCount: 0);
      expect(t3, greaterThan(t1));
    });

    test('trivial grinding diminishes returns', () {
      final fresh = curve.reward(difficultyTier: 1, sessionCount: 0);
      final grind = curve.reward(difficultyTier: 1, sessionCount: 5);
      expect(grind, lessThan(fresh));
    });
  });

  group('ReputationDecay', () {
    const decay = ReputationDecay(ReputationDecayConfig(
      halfLifeSeconds: 100,
      buckets: 4,
      competencyPerFieldMillis: 100,
    ));

    test('reputation floors by credentials', () {
      final rep = decay.reputationAt(
        events: const [],
        unlockedFieldCount: 5,
        nowSeconds: 0,
      );
      expect(rep, 0); // 5 * 100 / 1000 integer division = 0 in this config
    });

    test('older events decay', () {
      const event = ReputationEvent(amountMillis: 1000, timestampSeconds: 0);
      final early = decay.reputationAt(
        events: const [event],
        unlockedFieldCount: 0,
        nowSeconds: 0,
      );
      final late = decay.reputationAt(
        events: const [event],
        unlockedFieldCount: 0,
        nowSeconds: 350,
      );
      expect(late, lessThan(early));
    });

    test('very old events fall out of table', () {
      final rep = decay.reputationAt(
        events: const [
          ReputationEvent(amountMillis: 1000, timestampSeconds: 0),
        ],
        unlockedFieldCount: 0,
        nowSeconds: 10000,
      );
      expect(rep, 0);
    });
  });

  group('Ledger', () {
    final event = LedgerEvent(
      kind: 'session_fee',
      idempotencyKey: 'ik-1',
      timestampSeconds: 1,
      currency: CurrencyType.cash,
      amountMicros: 1000000,
      reasonKey: 'ledger.session_fee',
    );

    test('applies events idempotently', () {
      final ledger = Ledger().apply(event).apply(event);
      expect(ledger.events.length, 1);
      expect(ledger.balance(CurrencyType.cash), 1000000);
    });

    test('replays balances from events', () {
      final ledger = Ledger()
          .apply(event)
          .apply(event.copyWith(idempotencyKey: 'ik-2', amountMicros: -500000));
      expect(ledger.balance(CurrencyType.cash), 500000);
    });

    test('compaction preserves balances', () {
      final ledger = Ledger().apply(event).apply(event.copyWith(
            idempotencyKey: 'ik-2',
            currency: CurrencyType.study,
            amountMicros: 3000000,
          ));
      final snapshot = ledger.compact();
      expect(snapshot.balancesMicros['cash'], 1000000);
      expect(snapshot.balancesMicros['study'], 3000000);
    });
  });

  group('FieldTrainingSpend', () {
    final tree = FieldTrainingTree([
      const FieldNode(
        fieldKey: 'field.somatic_studies',
        studyCost: 5,
        subspecialtyCost: 0,
      ),
      const FieldNode(
        fieldKey: 'field.somatic_advanced',
        parentFieldKey: 'field.somatic_studies',
        studyCost: 15,
        subspecialtyCost: 5,
      ),
    ]);

    test('unlocks foundational fields', () {
      const spend = FieldTrainingSpend();
      final result = spend.unlock(
        tree: tree,
        fieldKey: 'field.somatic_studies',
        studyPoints: 10,
        subspecialtyPoints: 0,
        unlockedFields: {},
      );
      expect(result.status, FieldTrainingStatus.success);
      expect(result.remainingStudy, 5);
    });

    test('requires parent field for advanced nodes', () {
      const spend = FieldTrainingSpend();
      final result = spend.unlock(
        tree: tree,
        fieldKey: 'field.somatic_advanced',
        studyPoints: 20,
        subspecialtyPoints: 10,
        unlockedFields: {},
      );
      expect(result.status, FieldTrainingStatus.missingPrerequisite);
    });
  });

  group('AttractionVector', () {
    const vector = AttractionVector(AttractionVectorConfig(
      reputationWeight: 2,
      priceAccessibilityWeight: 1,
      studyFieldCoverageWeight: 1,
    ));

    test('score rises with reputation and field coverage', () {
      final low = vector.score(
        reputation: 10,
        maxPrice: 100,
        unlockedFields: 1,
        totalFields: 4,
      );
      final high = vector.score(
        reputation: 900,
        maxPrice: 10,
        unlockedFields: 3,
        totalFields: 4,
      );
      expect(high, greaterThan(low));
    });
  });

  group('OnboardingTrack', () {
    const track = OnboardingTrack(OnboardingConfig(
      safePracticeMaxTier: 1,
      failureMultiplierMillis: 500,
    ));

    test('caps playable tier during onboarding', () {
      expect(track.canPlayTier(1), isTrue);
      expect(track.canPlayTier(2), isFalse);
    });

    test('softens failure penalties', () {
      expect(track.softenedPenalty(-20), -10);
    });

    test('graduates after enough successes', () {
      expect(track.shouldGraduate(2), isFalse);
      expect(track.shouldGraduate(3), isTrue);
    });
  });
}
