import 'package:psychemas/psychemas.dart';

import 'clock.dart';
import 'prng.dart';
import 'turn_input.dart';
import 'turn_output.dart';

/// Pure deterministic turn resolver.
///
/// Given a [TurnInput], produces a [TurnOutput]. No wall-clock, no ambient
/// randomness: the seeded PRNG plus the fixed input fully determine the
/// outcome (0.8 determinism contract).
class TurnResolver {
  final Clock clock;

  const TurnResolver(this.clock);

  TurnOutput resolve(TurnInput input) {
    if (!input.manifest.interactionPatterns.contains(input.action)) {
      throw ArgumentError(
        'Action ${input.action.name} is not available for case ${input.manifest.id}',
      );
    }

    final seed = input.state.seed ^
        input.action.name.hashCode ^
        input.manifest.id.hashCode ^
        clock.nowMillis();
    final prng = SeededPrng(seed);

    final nextAxes = Map<String, int>.of(input.state.axes);
    final deltas = <StructuredDelta>[];

    // Minimal PoC resolution: each pattern shifts axes in a signature-biased
    // way. Phase 2 will replace this with the full card taxonomy.
    for (final entry in nextAxes.entries.toList()
      ..sort((a, b) => a.key.compareTo(b.key))) {
      final axis = entry.key;
      final current = entry.value;
      final delta = _resolveAxisDelta(prng, input.action, axis);
      nextAxes[axis] = (current + delta).clamp(0, 100);
      deltas.add(StructuredDelta(
        rulesetVersion: input.rulesetVersion,
        axis: axis,
        deltaMillis: delta * 1000,
        reasonKey: 'deltas.${input.action.name}.$axis',
      ));
    }

    final nextState = input.state.copyWith(
      turn: input.state.turn + 1,
      axes: nextAxes,
    );

    return TurnOutput(
      nextState: nextState,
      deltas: deltas,
      requiredClueTokens: input.manifest.clueTokens,
    );
  }

  int _resolveAxisDelta(
      SeededPrng prng, InteractionPattern action, String axis) {
    final roll = prng.nextInt(7) - 3; // [-3, 3]
    switch (action) {
      case InteractionPattern.openQuestion:
        return axis == 'trust' ? roll + 1 : roll;
      case InteractionPattern.validate:
        return axis == 'trust' ? roll + 2 : roll - 1;
      case InteractionPattern.reframe:
        return axis == 'resistance' ? roll - 2 : roll + 1;
      case InteractionPattern.setBoundary:
        return axis == 'agitation' ? roll - 2 : roll;
      case InteractionPattern.reflect:
        return axis == 'trust' ? roll + 1 : roll;
      case InteractionPattern.discloseParallel:
        return axis == 'resistance' ? roll - 1 : roll + 1;
    }
  }
}
