import 'package:psychemas/psychemas.dart';
import 'package:psycore/psycore.dart';
import 'package:test/test.dart';

void main() {
  group('TherapyControllerSettings', () {
    const manifest = PatientManifest(
      id: 'controller-case',
      rulesetVersion: '0.1.0',
      contentChecksum:
          'sha256:0000000000000000000000000000000000000000000000000000000000000000',
      nameKey: 'name',
      displayNameKey: 'display',
      styleArchetype: StyleArchetype.vexa,
      initialState: {'trust': 30, 'agitation': 45, 'resistance': 55},
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

    TurnInput input({
      required InteractionPattern action,
      required TherapyControllerSettings controllers,
    }) {
      return TurnInput(
        rulesetVersion: '0.1.0',
        manifest: manifest,
        state: const SimState(
          seed: 1,
          trustScore: 30,
          agitationLevel: 45,
          activeDefense: DefenseState.rigid,
        ),
        action: action,
        loadout: loadout,
        library: library,
        controllers: controllers,
      );
    }

    const resolver = TurnResolver(InjectedClock.replay(0));

    test('workspace focus improves breaker context-fit for Disclosing', () {
      final balanced = resolver.resolve(input(
        action: InteractionPattern.openQuestion,
        controllers: const TherapyControllerSettings(focus: FocusAxis.balanced),
      ));
      final workspace = resolver.resolve(input(
        action: InteractionPattern.openQuestion,
        controllers:
            const TherapyControllerSettings(focus: FocusAxis.workspace),
      ));
      final balancedFit = balanced.deltas.first.contextFit.index;
      final workspaceFit = workspace.deltas.first.contextFit.index;
      expect(workspaceFit, lessThanOrEqualTo(balancedFit));
    });

    test('warm delivery improves buffer context-fit for Relatable', () {
      final balanced = resolver.resolve(input(
        action: InteractionPattern.validate,
        controllers: const TherapyControllerSettings(
            emotionalDelivery: EmotionalDelivery.balanced),
      ));
      final warm = resolver.resolve(input(
        action: InteractionPattern.validate,
        controllers: const TherapyControllerSettings(
            emotionalDelivery: EmotionalDelivery.warm),
      ));
      final balancedFit = balanced.deltas.first.contextFit.index;
      final warmFit = warm.deltas.first.contextFit.index;
      expect(warmFit, lessThanOrEqualTo(balancedFit));
    });
  });
}
