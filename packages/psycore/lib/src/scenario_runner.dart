import 'package:psychemas/psychemas.dart';

import 'bot_player.dart';
import 'card_balance.dart';
import 'clock.dart';
import 'core_run_path.dart';
import 'scenario_result.dart';
import 'sim_state.dart';
import 'turn_output.dart';

/// Runs one deterministic scenario through the core-only path.
///
/// A scenario is (manifest, bot, loadout, seed). The runner repeatedly asks
/// the bot to select a legal card and resolves the turn until the case ends
/// or a configurable max-turn budget is exhausted. No model, no Flutter, no
/// `dart:io`.
class ScenarioRunner {
  final String rulesetVersion;
  final Clock clock;
  final int maxTurns;
  final CardBalance balance;

  const ScenarioRunner({
    required this.rulesetVersion,
    required this.clock,
    this.maxTurns = 120,
    this.balance = const CardBalance(),
  });

  /// Runs a single scenario and returns a structured result.
  ///
  /// Wall-clock duration is intentionally excluded here; the harness that
  /// drives the sandbox measures elapsed time outside the deterministic core
  /// so `packages/psycore` stays free of wall-clock reads.
  ScenarioResult run({
    required PatientManifest manifest,
    required BotPlayer bot,
    required Loadout loadout,
    required CardLibrary library,
    required int rootSeed,
  }) {
    final path = CoreRunPath(balance: balance);
    final turns = <TurnOutput>[];
    var state = SimState.fromInitialState(rootSeed, manifest.initialState);

    while (turns.length < maxTurns) {
      final action = bot.chooseAction(
        state: state,
        loadout: loadout,
        library: library,
        available: manifest.interactionPatterns,
      );

      final outputs = path.resolveScripted(
        rulesetVersion: rulesetVersion,
        manifest: manifest,
        actions: [action],
        rootSeed: rootSeed,
        clock: clock,
        loadout: loadout,
        library: library,
        startState: state,
      );

      final output = outputs.single;
      turns.add(output);
      state = output.nextState;

      if (output.isTerminal) break;
    }

    final last = turns.last;
    return ScenarioResult(
      manifestId: manifest.id,
      botId: bot.id,
      skill: bot.skill,
      rootSeed: rootSeed,
      won: last.outcome == SessionOutcome.succeed,
      turnCount: turns.length,
      outcome: last.outcome,
      finalState: last.nextState,
      turns: turns,
      durationMillis: 0,
    );
  }
}
