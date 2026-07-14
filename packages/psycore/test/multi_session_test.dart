import 'package:psychemas/psychemas.dart';
import 'package:psycore/psycore.dart';
import 'package:test/test.dart';

void main() {
  group('ClinicalEncyclopedia', () {
    const entry = ClinicalEncyclopediaEntry(
      id: 'brumosis_somatic_marker',
      titleKey: 'encyclopedia.brumosis.title',
      noteKey: 'encyclopedia.brumosis.note',
      clueToken: 'brumosis-marker',
      relatedDrug: 'brumaxine',
      fieldKey: 'field.somatic_studies',
    );

    test('looks up entries by clue token', () {
      final encyclopedia = ClinicalEncyclopedia([entry]);
      expect(encyclopedia.lookupByClue('brumosis-marker'), entry);
      expect(encyclopedia.lookupByClue('unknown'), isNull);
    });

    test('lists unlocked entries from collected clues', () {
      final encyclopedia = ClinicalEncyclopedia([entry]);
      expect(
        encyclopedia.unlocked(['brumosis-marker', 'unknown']),
        [entry],
      );
    });

    test('round-trips through canonical JSON', () {
      final encyclopedia = ClinicalEncyclopedia([entry]);
      final decoded = ClinicalEncyclopedia.fromJson(
        CanonicalJson.decode(encyclopedia.toCanonicalBytes())
            as Map<String, Object?>,
      );
      expect(decoded.all, [entry]);
    });
  });

  group('CaseHistoryEnvelope', () {
    test('adds clues and derangements idempotently', () {
      const envelope = CaseHistoryEnvelope();
      final withClue = envelope.withClue('clue-a').withClue('clue-a');
      expect(withClue.collectedClues, ['clue-a']);

      final withMutation = withClue
          .withDerangement(DerangementMutation.somaticFixation)
          .withDerangement(DerangementMutation.somaticFixation);
      expect(withMutation.derangements, [DerangementMutation.somaticFixation]);
    });
  });

  group('MultiSessionDigestCompiler', () {
    const compiler = MultiSessionDigestCompiler();

    test('emit is bounded regardless of envelope size', () {
      final envelope = CaseHistoryEnvelope(
        priorSessionCount: 5,
        derangements: DerangementMutation.values,
        collectedClues: ['a', 'b', 'c', 'd', 'e'],
        inheritedMedication: const MedicationState(
          drug: FictionalDrug.vexanil,
          dosage: 10,
          dependency: 20,
          tolerance: 30,
        ),
      );
      final encyclopedia = ClinicalEncyclopedia([
        const ClinicalEncyclopediaEntry(
          id: 'a',
          titleKey: 't.a',
          noteKey: 'n.a',
          clueToken: 'a',
          fieldKey: 'field.a',
        ),
      ]);
      final digest = compiler.compile(
        envelope: envelope,
        state: const SimState(seed: 1, turn: 0),
        encyclopedia: encyclopedia,
      );
      // Four sentences max; the compiler should not emit a wall of text.
      final sentenceCount = digest
          .split(RegExp(r'\.\s'))
          .where((s) => s.trim().isNotEmpty)
          .length;
      expect(sentenceCount,
          lessThanOrEqualTo(MultiSessionDigestCompiler.maxSentences));
    });
  });

  group('MultiSessionResolver', () {
    const resolver = MultiSessionResolver();

    test('applies derangement baseline shifts to starting state', () {
      final state = resolver.startingState(
        initialState: const {'trust': 50, 'agitation': 30},
        rootSeed: 1,
        envelope: const CaseHistoryEnvelope(
          derangements: [DerangementMutation.trustCollapse],
        ),
      );
      expect(state.trustScore, 35);
    });

    test('carries over inherited medication', () {
      const medication = MedicationState(
        drug: FictionalDrug.torpidol,
        dosage: 10,
        dependency: 5,
        tolerance: 5,
      );
      final state = resolver.startingState(
        initialState: const {},
        rootSeed: 1,
        envelope: const CaseHistoryEnvelope(
          inheritedMedication: medication,
        ),
      );
      expect(state.medication, medication);
    });

    test('builds next envelope with clues and session count', () {
      const manifestClues = ['ferve-axine'];
      const output = TurnOutput(
        nextState: SimState(seed: 1, turn: 1),
        deltas: [],
        requiredClueTokens: ['ferve-axine'],
        outcome: SessionOutcome.ongoing,
      );
      final next = resolver.buildNextEnvelope(
        memoryClass: MemoryClass.persistent,
        previous: const CaseHistoryEnvelope(),
        sessionOutputs: [output],
        manifestClueTokens: manifestClues,
      );
      expect(next.priorSessionCount, 1);
      expect(next.collectedClues, ['ferve-axine']);
    });

    test('records derangement on low-trust manipulative trauma', () {
      const output = TurnOutput(
        nextState: SimState(seed: 1, turn: 1),
        deltas: [
          StructuredDelta(
            rulesetVersion: '0.1.0',
            axis: StateAxis.trauma,
            deltaMillis: 2,
            reasonKey: 'deltas.reframe.trauma',
            cardType: CardType.manipulative,
            cardSignature: CardSignature.gambit,
            contextFit: ContextFit.mismatched,
          ),
        ],
        requiredClueTokens: [],
        outcome: SessionOutcome.ongoing,
      );
      final next = resolver.buildNextEnvelope(
        memoryClass: MemoryClass.persistent,
        previous: const CaseHistoryEnvelope(),
        sessionOutputs: [output],
        manifestClueTokens: const [],
      );
      expect(next.derangements, [DerangementMutation.trustCollapse]);
    });

    test('stateless cases carry no history envelope', () {
      expect(
        resolver.envelopeForCase(MemoryClass.stateless),
        CaseHistoryEnvelope.empty,
      );

      final next = resolver.buildNextEnvelope(
        memoryClass: MemoryClass.stateless,
        previous: const CaseHistoryEnvelope(
          priorSessionCount: 3,
          collectedClues: ['should-not-persist'],
        ),
        sessionOutputs: [
          const TurnOutput(
            nextState: SimState(seed: 1, turn: 1),
            deltas: [],
            requiredClueTokens: ['should-not-persist'],
            outcome: SessionOutcome.ongoing,
          ),
        ],
        manifestClueTokens: const ['should-not-persist'],
      );
      expect(next.priorSessionCount, 0);
      expect(next.collectedClues, isEmpty);
    });

    test('persistent cases begin with a fresh carry-over envelope', () {
      final envelope = resolver.envelopeForCase(MemoryClass.persistent);
      expect(envelope.priorSessionCount, 0);
      expect(envelope.collectedClues, isEmpty);
      expect(envelope.derangements, isEmpty);
    });
  });

  group('Multi-session siege integration', () {
    const resolver = MultiSessionResolver();
    const compiler = MultiSessionDigestCompiler();
    const grader = ClinicalGradingCalculator();

    test('two-session case is unsolvable in one, solvable after study', () {
      // A persistent siege case whose breakthrough requires the Bull's Eye card.
      final manifest = PatientManifest(
        rulesetVersion: '0.1.0',
        id: 'siege.brumosis',
        contentChecksum: 'sha256:ignored-for-test',
        memoryClass: MemoryClass.persistent,
        nameKey: 'case.siege.brumosis.title',
        displayNameKey: 'case.siege.brumosis.display',
        styleArchetype: StyleArchetype.torpida,
        initialState: const {'trust': 40, 'agitation': 30, 'trauma': 0},
        interactionPatterns: const [
          InteractionPattern.openQuestion,
          InteractionPattern.reframe,
        ],
        clueTokens: const ['brumosis-marker'],
        maxHistoryTurns: 4,
        modelFacingTemplate: 'siege-template',
      );

      // Session 1: gather the clue but do not resolve the case.
      final envelope1 = resolver.envelopeForCase(manifest.memoryClass);
      final session1Outputs = [
        TurnOutput(
          nextState: const SimState(seed: 1, turn: 1, sessionProgress: 30),
          deltas: const [
            StructuredDelta(
              rulesetVersion: '0.1.0',
              axis: StateAxis.trust,
              deltaMillis: 10000,
              reasonKey: 'deltas.openQuestion.trust',
              cardType: CardType.relatable,
              cardSignature: CardSignature.buffer,
              contextFit: ContextFit.aligned,
            ),
          ],
          requiredClueTokens: const ['brumosis-marker'],
          outcome: SessionOutcome.ongoing,
        ),
      ];
      final envelope2 = resolver.buildNextEnvelope(
        memoryClass: manifest.memoryClass,
        previous: envelope1,
        sessionOutputs: session1Outputs,
        manifestClueTokens: manifest.clueTokens,
      );
      expect(envelope2.priorSessionCount, 1);
      expect(envelope2.collectedClues, ['brumosis-marker']);
      expect(envelope2.collectedClues, contains('brumosis-marker'));

      // Between sessions: spend study points to unlock the breakthrough card.
      final catalog = StudyCatalog([
        const StudyUnlockEntry(
          cardId: 'bulls_eye',
          studyCost: 10,
          subspecialtyCost: 0,
          fieldKey: 'field.somatic_studies',
        ),
      ]);
      final spendResult = const StudySpend().unlock(
        catalog: catalog,
        cardId: 'bulls_eye',
        studyPoints: 15,
        subspecialtyPoints: 0,
        unlockedCardIds: {},
      );
      expect(spendResult.status, StudySpendStatus.success);
      expect(spendResult.remainingStudy, 5);

      // Session 2: with the breakthrough card owned, the case resolves.
      final session2Outputs = [
        TurnOutput(
          nextState: const SimState(seed: 1, turn: 2, sessionProgress: 100),
          deltas: const [
            StructuredDelta(
              rulesetVersion: '0.1.0',
              axis: StateAxis.sessionProgress,
              deltaMillis: 70000,
              reasonKey: 'deltas.bullsEye.breakthrough',
              cardType: CardType.manipulative,
              cardSignature: CardSignature.gambit,
              contextFit: ContextFit.aligned,
            ),
          ],
          requiredClueTokens: const [],
          outcome: SessionOutcome.succeed,
        ),
      ];
      final envelope3 = resolver.buildNextEnvelope(
        memoryClass: manifest.memoryClass,
        previous: envelope2,
        sessionOutputs: session2Outputs,
        manifestClueTokens: manifest.clueTokens,
      );
      expect(envelope3.priorSessionCount, 2);

      // The history digest is bounded no matter how many sessions ran.
      final digest = compiler.compile(
        envelope: envelope3,
        state: const SimState(seed: 1, turn: 2, sessionProgress: 100),
      );
      final sentenceCount = digest
          .split(RegExp(r'\.\s'))
          .where((s) => s.trim().isNotEmpty)
          .length;
      expect(sentenceCount,
          lessThanOrEqualTo(MultiSessionDigestCompiler.maxSentences));

      // Clinical grading is deterministic and scores the completed siege.
      final receipt = SessionReceipt(
        id: 'siege-receipt-1',
        rulesetVersion: '0.1.0',
        patientId: manifest.id,
        idempotencyKey: 'ik-1',
        correlationId: 'corr-1',
        turnCount: 2,
        startState: manifest.initialState,
        actions: const [
          InteractionPattern.openQuestion,
          InteractionPattern.reframe,
        ],
        deltas: [
          ...session1Outputs.first.deltas,
          ...session2Outputs.first.deltas,
        ],
      );
      final report = grader.calculate(receipt);
      expect(report.pathEfficiency.score, greaterThan(0));
    });
  });

  group('StudySpend', () {
    final catalog = StudyCatalog([
      const StudyUnlockEntry(
        cardId: 'bulls_eye',
        studyCost: 10,
        subspecialtyCost: 2,
        fieldKey: 'field.somatic_studies',
      ),
    ]);

    test('unlocks when currency is sufficient', () {
      const spend = StudySpend();
      final result = spend.unlock(
        catalog: catalog,
        cardId: 'bulls_eye',
        studyPoints: 15,
        subspecialtyPoints: 5,
        unlockedCardIds: {},
      );
      expect(result.status, StudySpendStatus.success);
      expect(result.remainingStudy, 5);
      expect(result.remainingSubspecialty, 3);
    });

    test('rejects insufficient study points', () {
      const spend = StudySpend();
      final result = spend.unlock(
        catalog: catalog,
        cardId: 'bulls_eye',
        studyPoints: 5,
        subspecialtyPoints: 5,
        unlockedCardIds: {},
      );
      expect(result.status, StudySpendStatus.insufficientStudy);
    });
  });

  group('ClinicalGradingCalculator', () {
    test('scores alliance from trust and rapport plays', () {
      final receipt = SessionReceipt(
        id: 'r1',
        rulesetVersion: '0.1.0',
        patientId: 'p1',
        idempotencyKey: 'k1',
        correlationId: 'c1',
        turnCount: 2,
        startState: {},
        actions: [InteractionPattern.validate, InteractionPattern.reflect],
        deltas: [
          StructuredDelta(
            rulesetVersion: '0.1.0',
            axis: StateAxis.trust,
            deltaMillis: 30000,
            reasonKey: 'deltas.validate.trust',
            cardType: CardType.relatable,
            cardSignature: CardSignature.buffer,
            contextFit: ContextFit.aligned,
          ),
        ],
      );
      final report = const ClinicalGradingCalculator().calculate(receipt);
      expect(report.alliance.score, greaterThan(50));
    });

    test('penalises pharmacological safety for dependency deltas', () {
      final receipt = SessionReceipt(
        id: 'r1',
        rulesetVersion: '0.1.0',
        patientId: 'p1',
        idempotencyKey: 'k1',
        correlationId: 'c1',
        turnCount: 1,
        startState: {},
        actions: [InteractionPattern.openQuestion],
        deltas: [
          StructuredDelta(
            rulesetVersion: '0.1.0',
            axis: StateAxis.medicationDependency,
            deltaMillis: 10000,
            reasonKey: 'deltas.medication.dependency',
            cardType: CardType.disclosing,
            cardSignature: CardSignature.breaker,
            contextFit: ContextFit.aligned,
          ),
        ],
      );
      final report = const ClinicalGradingCalculator().calculate(receipt);
      expect(report.pharmacologicalSafety.score, lessThan(100));
    });
  });
}
