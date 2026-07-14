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

  /// Turn-level outcome classification.
  final SessionOutcome outcome;

  /// Whether this turn ends the session (success, failure, or terminal
  /// abandonment).
  final bool isTerminal;

  /// Updated case lifecycle state.
  final CaseLifecycle lifecycle;

  const TurnOutput({
    required this.nextState,
    required this.deltas,
    required this.requiredClueTokens,
    this.outcome = SessionOutcome.ongoing,
    this.isTerminal = false,
    this.lifecycle = CaseLifecycle.inTreatment,
  });

  Map<String, Object?> toJson() => {
        'next_state': nextState.toJson(),
        'deltas': deltas.map((d) => d.toJson()).toList(),
        'required_clue_tokens': requiredClueTokens,
        'outcome': outcome.toJson(),
        'is_terminal': isTerminal,
        'lifecycle': lifecycle.toJson(),
      };

  /// Encodes this output to canonical UTF-8 bytes.
  List<int> toCanonicalBytes() => CanonicalJson.encode(toJson());
}
