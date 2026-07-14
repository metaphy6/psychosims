import 'package:psychemas/psychemas.dart';
import 'package:psycore/psycore.dart';
import 'package:test/test.dart';

void main() {
  group('TurnResolver', () {
    final manifest = PatientManifest(
      id: 'poc-vexa-001',
      rulesetVersion: '0.1.0',
      contentChecksum:
          'sha256:0000000000000000000000000000000000000000000000000000000000000000',
      nameKey: 'manifests.poc_vexa_001.name',
      displayNameKey: 'manifests.poc_vexa_001.display_name',
      styleArchetype: StyleArchetype.vexa,
      initialState: const {'trust': 30, 'agitation': 45, 'resistance': 25},
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

    test('produces identical outcome for fixed input + clock', () {
      final clock = InjectedClock.replay(0);
      const state = SimState(
          seed: 42, axes: {'trust': 30, 'agitation': 45, 'resistance': 25});

      final resolver = TurnResolver(clock);
      final first =
          resolver.resolve(input(InteractionPattern.openQuestion, state));
      final second = TurnResolver(clock)
          .resolve(input(InteractionPattern.openQuestion, state));

      expect(first.nextState.turn, equals(second.nextState.turn));
      expect(first.nextState.axes, equals(second.nextState.axes));
      expect(first.deltas, equals(second.deltas));
    });

    test('emits required clue tokens from manifest', () {
      final clock = InjectedClock.replay(0);
      const state = SimState(
          seed: 42, axes: {'trust': 30, 'agitation': 45, 'resistance': 25});

      final output = TurnResolver(clock)
          .resolve(input(InteractionPattern.validate, state));

      expect(output.requiredClueTokens, equals(manifest.clueTokens));
    });

    test('tags deltas with ruleset_version', () {
      final clock = InjectedClock.replay(0);
      const state = SimState(seed: 42, axes: {'trust': 30});

      final output = TurnResolver(clock)
          .resolve(input(InteractionPattern.openQuestion, state));

      for (final delta in output.deltas) {
        expect(delta.rulesetVersion, equals('0.1.0'));
      }
    });

    test('rejects unavailable action', () {
      final clock = InjectedClock.replay(0);
      const state = SimState(seed: 42, axes: {'trust': 30});

      expect(
        () => TurnResolver(clock).resolve(
          input(InteractionPattern.discloseParallel, state),
        ),
        throwsA(isA<ArgumentError>()),
      );
    });
  });
}
