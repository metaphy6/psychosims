import 'package:psychemas/psychemas.dart';
import 'package:psycore/psycore.dart';
import 'package:test/test.dart';

void main() {
  group('TurnResolver determinism property', () {
    final manifest = PatientManifest(
      id: 'poc-vexa-001',
      rulesetVersion: 'poc-1.0.0',
      contentChecksum:
          'sha256:0000000000000000000000000000000000000000000000000000000000000000',
      nameKey: 'manifests.poc_vexa_001.name',
      displayNameKey: 'manifests.poc_vexa_001.display_name',
      styleArchetype: StyleArchetype.vexa,
      initialState: const {'trust': 50, 'agitation': 40, 'resistance': 25},
      interactionPatterns: const [
        InteractionPattern.openQuestion,
        InteractionPattern.validate,
        InteractionPattern.reframe,
        InteractionPattern.setBoundary,
      ],
      clueTokens: const ['ferve-axine'],
      maxHistoryTurns: 6,
      modelFacingTemplate: 'Test template.',
    );

    TurnInput input(InteractionPattern action, SimState state) {
      return TurnInput(
        rulesetVersion: manifest.rulesetVersion,
        manifest: manifest,
        state: state,
        action: action,
      );
    }

    test('fixed state + action + clock yields identical outcome across seeds',
        () {
      final clock = InjectedClock(123456789);
      const actions = [
        InteractionPattern.openQuestion,
        InteractionPattern.validate,
        InteractionPattern.reframe,
        InteractionPattern.setBoundary,
      ];

      for (var seed = 0; seed < 50; seed++) {
        const state = SimState(
            seed: 42, axes: {'trust': 50, 'agitation': 40, 'resistance': 25});
        final resolver = TurnResolver(clock);

        SimState current = state;
        final outputs = <TurnOutput>[];
        for (final action in actions) {
          final output = resolver.resolve(input(action, current));
          outputs.add(output);
          current = output.nextState;
        }

        // Replay from the same starting state must produce the same final state.
        SimState replay = state;
        final replayOutputs = <TurnOutput>[];
        for (final action in actions) {
          final output = TurnResolver(clock).resolve(input(action, replay));
          replayOutputs.add(output);
          replay = output.nextState;
        }

        expect(replay.turn, equals(current.turn));
        expect(replay.axes, equals(current.axes));
        expect(
          replayOutputs.map((o) => o.deltas),
          equals(outputs.map((o) => o.deltas)),
        );
      }
    });
  });
}
