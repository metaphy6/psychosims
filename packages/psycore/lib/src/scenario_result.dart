import 'package:psychemas/psychemas.dart';

import 'bot_player.dart';
import 'sim_state.dart';
import 'turn_output.dart';

/// Aggregated result of a single sandbox scenario run.
///
/// Structured diagnostics are emitted per run so the 2.8 sandbox can report
/// distributions (median/p95) for win-rate, XP/session, currency flow, and
/// reputation trajectory on the 0.7 metrics contract.
class ScenarioResult {
  final String manifestId;
  final String botId;
  final BotSkill skill;
  final int rootSeed;
  final bool won;
  final int turnCount;
  final SessionOutcome outcome;
  final SimState finalState;
  final List<TurnOutput> turns;
  final int durationMillis;

  const ScenarioResult({
    required this.manifestId,
    required this.botId,
    required this.skill,
    required this.rootSeed,
    required this.won,
    required this.turnCount,
    required this.outcome,
    required this.finalState,
    required this.turns,
    required this.durationMillis,
  });

  Map<String, Object?> toJson() => {
        'manifest_id': manifestId,
        'bot_id': botId,
        'skill': skill.toJson(),
        'root_seed': rootSeed,
        'won': won,
        'turn_count': turnCount,
        'outcome': outcome.toJson(),
        'final_state': finalState.toJson(),
        'duration_millis': durationMillis,
      };

  ScenarioResult copyWith({int? durationMillis}) {
    return ScenarioResult(
      manifestId: manifestId,
      botId: botId,
      skill: skill,
      rootSeed: rootSeed,
      won: won,
      turnCount: turnCount,
      outcome: outcome,
      finalState: finalState,
      turns: turns,
      durationMillis: durationMillis ?? this.durationMillis,
    );
  }
}

/// Distribution summary over a collection of scenario results.
///
/// All fractional values are represented as integer basis points or scaled
/// integers so the sandbox stays within the `packages/psycore` no-float
/// contract.
class ScenarioDistribution {
  final int count;

  /// Win rate in basis points (0–10000), e.g. 7500 == 75 %.
  final int winRateBasisPoints;
  final int medianTurns;
  final int p95Turns;

  /// Median progress as an integer percentage (0–100).
  final int medianProgress;
  final int p95Progress;

  const ScenarioDistribution({
    required this.count,
    required this.winRateBasisPoints,
    required this.medianTurns,
    required this.p95Turns,
    required this.medianProgress,
    required this.p95Progress,
  });

  Map<String, Object?> toJson() => {
        'count': count,
        'win_rate_basis_points': winRateBasisPoints,
        'median_turns': medianTurns,
        'p95_turns': p95Turns,
        'median_progress': medianProgress,
        'p95_progress': p95Progress,
      };

  static ScenarioDistribution fromResults(List<ScenarioResult> results) {
    if (results.isEmpty) {
      return const ScenarioDistribution(
        count: 0,
        winRateBasisPoints: 0,
        medianTurns: 0,
        p95Turns: 0,
        medianProgress: 0,
        p95Progress: 0,
      );
    }

    final wins = results.where((r) => r.won).length;
    final turns = results.map((r) => r.turnCount).toList()..sort();
    final progress = results.map((r) => r.finalState.sessionProgress).toList()
      ..sort();

    return ScenarioDistribution(
      count: results.length,
      winRateBasisPoints: (wins * 10000) ~/ results.length,
      medianTurns: _percentileInt(turns, 500),
      p95Turns: _percentileInt(turns, 950),
      medianProgress: _percentileInt(progress, 500),
      p95Progress: _percentileInt(progress, 950),
    );
  }

  /// [permille] is the percentile in parts per thousand (500 = median,
  /// 950 = p95).
  static int _percentileInt(List<int> sorted, int permille) {
    if (sorted.isEmpty) return 0;
    if (sorted.length == 1) return sorted.first;
    // Scale by 1000 to avoid floating-point literals in core.
    final scaledIndex = (sorted.length - 1) * permille;
    final lower = scaledIndex ~/ 1000;
    final upper = (scaledIndex + 999) ~/ 1000;
    if (lower >= sorted.length - 1) return sorted.last;
    if (lower == upper) return sorted[lower];
    final remainder = scaledIndex % 1000;
    final weighted =
        sorted[lower] * (1000 - remainder) + sorted[upper] * remainder;
    return (weighted + 500) ~/ 1000;
  }
}
