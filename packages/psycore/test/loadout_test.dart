import 'package:psychemas/psychemas.dart';
import 'package:psycore/psycore.dart';
import 'package:test/test.dart';

void main() {
  group('Loadout enforcement', () {
    const manifest = PatientManifest(
      id: 'loadout-case',
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

    const clock = InjectedClock.replay(0);
    const resolver = TurnResolver(clock);
    const state = SimState(
        seed: 1,
        trustScore: 30,
        agitationLevel: 45,
        activeDefense: DefenseState.guarded);

    TurnInput input({
      required Loadout loadout,
      required CardLibrary library,
      InteractionPattern action = InteractionPattern.openQuestion,
    }) {
      return TurnInput(
        rulesetVersion: '0.1.0',
        manifest: manifest,
        state: state,
        action: action,
        loadout: loadout,
        library: library,
      );
    }

    test('rejects play of a card not in the active loadout', () {
      final loadout = const Loadout(cardIds: ['validate'], slotCap: 6);
      final library =
          const CardLibrary(ownedCardIds: {'open_question', 'validate'});
      expect(
        () => resolver.resolve(input(loadout: loadout, library: library)),
        throwsA(isA<ArgumentError>().having(
          (e) => e.message,
          'message',
          contains('not in the active loadout'),
        )),
      );
    });

    test('rejects play of an unowned card', () {
      final loadout = const Loadout(cardIds: ['open_question'], slotCap: 6);
      final library = const CardLibrary(ownedCardIds: {'validate'});
      expect(
        () => resolver.resolve(input(loadout: loadout, library: library)),
        throwsA(isA<ArgumentError>().having(
          (e) => e.message,
          'message',
          contains('not owned'),
        )),
      );
    });

    test('rejects loadout that exceeds slot cap', () {
      final loadout = const Loadout(
        cardIds: ['open_question', 'validate', 'reframe', 'set_boundary'],
        slotCap: 2,
      );
      final library = const CardLibrary(
        ownedCardIds: {'open_question', 'validate', 'reframe', 'set_boundary'},
      );
      expect(
        () => resolver.resolve(input(loadout: loadout, library: library)),
        throwsA(isA<ArgumentError>().having(
          (e) => e.message,
          'message',
          contains('exceeds its slot cap'),
        )),
      );
    });

    test('resolves when card is equipped and owned', () {
      final loadout = const Loadout(cardIds: ['open_question'], slotCap: 6);
      final library = const CardLibrary(ownedCardIds: {'open_question'});
      final output =
          resolver.resolve(input(loadout: loadout, library: library));
      expect(output.deltas, isNotEmpty);
    });
  });
}
