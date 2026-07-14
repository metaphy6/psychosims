import 'package:psychemas/psychemas.dart';

import 'clock.dart';
import 'sim_state.dart';
import 'turn_input.dart';
import 'turn_output.dart';
import 'turn_resolver.dart';

/// Pure core-only run path: resolves a full case from a manifest, a scripted
/// action list, and a root seed.
///
/// No inference, no `dart:io`, no Flutter. This is the path used by the 2.8
/// balance sandbox and Phase 4.3 solvability checks in CI without the model
/// binary present.
class CoreRunPath {
  const CoreRunPath();

  /// Resolves [actions] against [manifest] starting from [rootSeed].
  ///
  /// [clock] is fully injected; for a pure replay use [InjectedClock.replay].
  /// [rulesetVersion] selects the pinned PRNG constants. The [loadout] and
  /// [library] enforce which cards may be played.
  List<TurnOutput> resolveScripted({
    required String rulesetVersion,
    required PatientManifest manifest,
    required List<InteractionPattern> actions,
    required int rootSeed,
    required Clock clock,
    required Loadout loadout,
    required CardLibrary library,
  }) {
    final resolver = TurnResolver(clock);
    final outputs = <TurnOutput>[];
    var state = SimState.fromInitialState(rootSeed, manifest.initialState);

    for (final action in actions) {
      final input = TurnInput(
        rulesetVersion: rulesetVersion,
        manifest: manifest,
        state: state,
        action: action,
        loadout: loadout,
        library: library,
      );
      final output = resolver.resolve(input);
      outputs.add(output);
      state = output.nextState;
    }

    return outputs;
  }
}
