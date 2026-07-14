import 'package:psycore/psycore.dart';
import 'package:test/test.dart';

void main() {
  group('InjectedClock', () {
    test('returns injected authoritative time', () {
      const clock = InjectedClock(123456789, 1000);
      expect(clock.nowMillis(), equals(123456789));
      expect(clock.monotonicMillis(), equals(1000));
    });

    test('replay constructor starts monotonic at zero', () {
      const clock = InjectedClock.replay(123456789);
      expect(clock.nowMillis(), equals(123456789));
      expect(clock.monotonicMillis(), equals(0));
    });

    test('advanceMonotonic increases only the monotonic source', () {
      const clock = InjectedClock(123456789, 1000);
      final advanced = advanceMonotonic(clock, 5000);
      expect(advanced.nowMillis(), equals(123456789));
      expect(advanced.monotonicMillis(), equals(6000));
    });

    test('constructor does not read wall-clock', () {
      // The API has no DateTime.now() call; this test documents that the seam
      // is fully injected and safe for replay.
      const clock = InjectedClock(0, 0);
      expect(clock.nowMillis(), equals(0));
      expect(clock.monotonicMillis(), equals(0));
    });
  });
}
