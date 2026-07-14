import 'package:psychemas/psychemas.dart';
import 'package:psycore/psycore.dart';
import 'package:test/test.dart';

void main() {
  group('Outcome engine + lifecycle', () {
    const manifest = PatientManifest(
      id: 'outcome-case',
      rulesetVersion: '0.1.0',
      contentChecksum:
          'sha256:0000000000000000000000000000000000000000000000000000000000000000',
      nameKey: 'name',
      displayNameKey: 'display',
      styleArchetype: StyleArchetype.vexa,
      initialState: {'trust': 30, 'agitation': 45, 'resistance': 25},
      interactionPatterns: [
        InteractionPattern.openQuestion,
        InteractionPattern.validate,
        InteractionPattern.reframe,
        InteractionPattern.setBoundary,
      ],
      clueTokens: const ['ferve-axine'],
      maxHistoryTurns: 6,
      modelFacingTemplate: 'template',
    );

    const loadout = Loadout(
      cardIds: ['open_question', 'validate', 'reframe', 'set_boundary'],
      slotCap: 6,
    );
    const library = CardLibrary(
      ownedCardIds: {'open_question', 'validate', 'reframe', 'set_boundary'},
    );

    TurnInput input(SimState state, InteractionPattern action) {
      return TurnInput(
        rulesetVersion: '0.1.0',
        manifest: manifest,
        state: state,
        action: action,
        loadout: loadout,
        library: library,
      );
    }

    const resolver = TurnResolver(InjectedClock.replay(0));

    test('classifies crisis when agitation crosses crisis threshold', () {
      final output = resolver.resolve(input(
        const SimState(
          seed: 1,
          trustScore: 30,
          agitationLevel: 78,
          activeDefense: DefenseState.guarded,
        ),
        InteractionPattern.reframe,
      ));
      expect(output.outcome, SessionOutcome.crisis);
      expect(output.lifecycle, CaseLifecycle.crisis);
      expect(output.isTerminal, isFalse);
    });

    test('classifies fail when agitation crosses walkout threshold', () {
      final output = resolver.resolve(input(
        const SimState(
          seed: 2,
          trustScore: 30,
          agitationLevel: 94,
          activeDefense: DefenseState.guarded,
        ),
        InteractionPattern.reframe,
      ));
      expect(output.outcome, SessionOutcome.fail);
      expect(output.lifecycle, CaseLifecycle.hardFailed);
      expect(output.isTerminal, isTrue);
    });

    test('classifies stabilize when calm and trust floor are met', () {
      final output = resolver.resolve(input(
        const SimState(
          seed: 3,
          trustScore: 50,
          agitationLevel: 20,
          activeDefense: DefenseState.guarded,
        ),
        InteractionPattern.validate,
      ));
      expect(output.outcome, SessionOutcome.stabilize);
      expect(output.lifecycle, CaseLifecycle.inTreatment);
      expect(output.isTerminal, isFalse);
    });

    test('classifies succeed when session progress threshold is reached', () {
      final output = resolver.resolve(input(
        const SimState(
          seed: 4,
          trustScore: 50,
          agitationLevel: 45,
          activeDefense: DefenseState.guarded,
          sessionProgress: 99,
        ),
        InteractionPattern.validate,
      ));
      expect(output.outcome, SessionOutcome.succeed);
      expect(output.lifecycle, CaseLifecycle.cured);
      expect(output.isTerminal, isTrue);
    });

    test('first turn moves lifecycle from open to in-treatment', () {
      final output = resolver.resolve(input(
        const SimState(seed: 5, turn: 0),
        InteractionPattern.openQuestion,
      ));
      expect(output.lifecycle, CaseLifecycle.inTreatment);
    });
  });

  group('Fictional pharmacology', () {
    const manifest = PatientManifest(
      id: 'pharma-case',
      rulesetVersion: '0.1.0',
      contentChecksum:
          'sha256:0000000000000000000000000000000000000000000000000000000000000000',
      nameKey: 'name',
      displayNameKey: 'display',
      styleArchetype: StyleArchetype.vexa,
      initialState: {'trust': 30, 'agitation': 45, 'resistance': 25},
      interactionPatterns: [InteractionPattern.openQuestion],
      clueTokens: const ['ferve-axine'],
      maxHistoryTurns: 6,
      modelFacingTemplate: 'template',
    );

    const loadout = Loadout(cardIds: ['open_question'], slotCap: 6);
    const library = CardLibrary(ownedCardIds: {'open_question'});

    TurnInput input(SimState state) {
      return TurnInput(
        rulesetVersion: '0.1.0',
        manifest: manifest,
        state: state,
        action: InteractionPattern.openQuestion,
        loadout: loadout,
        library: library,
      );
    }

    const resolver = TurnResolver(InjectedClock.replay(0));

    test('active medication emits tolerance and dependency deltas', () {
      final output = resolver.resolve(input(const SimState(
        seed: 1,
        trustScore: 30,
        agitationLevel: 45,
        activeDefense: DefenseState.guarded,
        medication: MedicationState(
          drug: FictionalDrug.ferveAxine,
          dosage: 20,
        ),
      )));

      expect(
        output.deltas.any((d) => d.axis == StateAxis.medicationTolerance),
        isTrue,
      );
      expect(
        output.deltas.any((d) => d.axis == StateAxis.medicationDependency),
        isTrue,
      );
      expect(output.nextState.medication.tolerance, greaterThan(0));
      expect(output.nextState.medication.dependency, greaterThan(0));
    });

    test('no medication state emits no medication deltas', () {
      final output = resolver.resolve(input(const SimState(seed: 2)));
      expect(
        output.deltas.any(
          (d) =>
              d.axis == StateAxis.medicationTolerance ||
              d.axis == StateAxis.medicationDependency,
        ),
        isFalse,
      );
    });
  });

  group('Typed SimState serialization', () {
    test('round-trips through canonical JSON byte-identically', () {
      const state = SimState(
        seed: 7,
        turn: 3,
        trustScore: 12,
        agitationLevel: 34,
        activeDefense: DefenseState.rigid,
        trauma: 5,
        freezeTurns: 1,
        sessionProgress: 8,
        medication: MedicationState(
          drug: FictionalDrug.vexanil,
          dosage: 40,
          tolerance: 10,
          dependency: 4,
        ),
      );
      final bytes = state.toCanonicalBytes();
      final roundTrip = SimState.fromJson(
        CanonicalJson.decode(bytes) as Map<String, Object?>,
      );
      expect(roundTrip, equals(state));
      expect(roundTrip.toCanonicalBytes(), equals(bytes));
    });
  });
}
