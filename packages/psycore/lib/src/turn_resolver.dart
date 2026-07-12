import 'clock.dart';
import 'prng.dart';
import 'sim_state.dart';

/// Pure deterministic turn resolver.
///
/// Given a state, action key, and clock, produces the next state.
/// No wall-clock, no ambient randomness.
class TurnResolver {
  final Clock clock;

  const TurnResolver(this.clock);

  SimState resolve(SimState state, String actionKey) {
    final seed = state.seed ^ actionKey.hashCode ^ clock.nowMillis();
    final prng = SeededPrng(seed);
    final nextAxes = Map<String, int>.of(state.axes);
    for (final axis in nextAxes.keys) {
      nextAxes[axis] = nextAxes[axis]! + prng.nextInt(11) - 5;
    }
    return state.copyWith(
      turn: state.turn + 1,
      axes: nextAxes,
    );
  }
}
