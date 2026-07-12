import 'package:psycore/psycore.dart';
import 'package:test/test.dart';

void main() {
  group('FixedPoint', () {
    test('represents values deterministically', () {
      const a = FixedPoint(123450000);
      const b = FixedPoint(50000);
      expect((a + b).raw, equals(123500000));
    });

    test('rounds double conversions the same way every time', () {
      final value = FixedPoint.fromDouble(1.2345);
      final again = FixedPoint.fromDouble(1.2345);
      expect(value, equals(again));
    });
  });
}
