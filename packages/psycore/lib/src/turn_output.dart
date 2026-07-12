import 'package:psychemas/psychemas.dart';

import 'sim_state.dart';

/// Output of a single deterministic turn resolution.
///
/// The session loop applies this transactionally: if generation is cancelled
/// or fails, the state and deltas are discarded and the previous state remains
/// intact.
class TurnOutput {
  final SimState nextState;
  final List<StructuredDelta> deltas;
  final List<String> requiredClueTokens;

  const TurnOutput({
    required this.nextState,
    required this.deltas,
    required this.requiredClueTokens,
  });

  Map<String, Object?> toJson() => {
        'next_state': nextState.toJson(),
        'deltas': deltas.map((d) => d.toJson()).toList(),
        'required_clue_tokens': requiredClueTokens,
      };
}
