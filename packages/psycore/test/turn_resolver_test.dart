import 'package:psycore/psycore.dart';
import 'package:test/test.dart';

void main() {
  group('TurnResolver', () {
    test('produces identical outcome for fixed state + action + clock', () {
      final clock = InjectedClock(0);
      const state = SimState(seed: 42, axes: {'anxiety': 50});
      const action = 'reassure';

      final resolver = TurnResolver(clock);
      final first = resolver.resolve(state, action);
      final second = TurnResolver(clock).resolve(state, action);

      expect(first.turn, equals(second.turn));
      expect(first.axes, equals(second.axes));
    });
  });
}
