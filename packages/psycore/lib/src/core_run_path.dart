import 'package:psychemas/psychemas.dart';

import 'card_balance.dart';
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
  final CardBalance balance;

  const CoreRunPath({this.balance = const CardBalance()});

  /// Resolves [actions] against [manifest] starting from [rootSeed].
  ///
  /// [clock] is fully injected; for a pure replay use [InjectedClock.replay].
  /// [rulesetVersion] selects the pinned PRNG constants. The [loadout] and
  /// [library] enforce which cards may be played.
  /// Resolution stops at the first terminal outcome, ignoring later actions.
  ///
  /// If [startState] is provided, resolution begins from that state instead of
  /// the manifest's initial state. This lets the sandbox step through a case
  /// turn-by-turn while preserving deterministic seed derivation.
  List<TurnOutput> resolveScripted({
    required String rulesetVersion,
    required PatientManifest manifest,
    required List<InteractionPattern> actions,
    required int rootSeed,
    required Clock clock,
    required Loadout loadout,
    required CardLibrary library,
    SimState? startState,
  }) {
    final resolver = TurnResolver(clock, balance: balance);
    final outputs = <TurnOutput>[];
    var state = startState ??
        SimState.fromInitialState(rootSeed, manifest.initialState);

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
      if (output.isTerminal) break;
      state = output.nextState;
    }

    return outputs;
  }
}
