import 'package:psycore/psycore.dart';
import 'package:test/test.dart';

void main() {
  group('TurnResolver determinism property', () {
    test('fixed state + action + clock yields identical outcome across seeds',
        () {
      final clock = InjectedClock(123456789);
      const actions = ['reassure', 'challenge', 'postpone', 'educate'];

      for (var seed = 0; seed < 50; seed++) {
        const state = SimState(seed: 42, axes: {'trust': 50, 'doubt': 20});
        final resolver = TurnResolver(clock);

        SimState current = state;
        for (final action in actions) {
          current = resolver.resolve(current, action);
        }

        // Replay from the same starting state must produce the same final state.
        SimState replay = state;
        for (final action in actions) {
          replay = TurnResolver(clock).resolve(replay, action);
        }

        expect(replay.turn, equals(current.turn));
        expect(replay.axes, equals(current.axes));
      }
    });
  });
}
