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

    test('multiplies by a ratio with round-half-to-even', () {
      final value = FixedPoint.fromWhole(100);
      expect(
          value.multiplyByRatio(FixedPoint(5000)), equals(FixedPoint(500000)));
      expect(
          value.multiplyByRatio(FixedPoint(2500)), equals(FixedPoint(250000)));
      // 100 * 0.3333 = 33.33 -> 333300 raw
      expect(
          value.multiplyByRatio(FixedPoint(3333)), equals(FixedPoint(333300)));
    });

    test('divides by an integer divisor with round-half-to-even', () {
      final value = FixedPoint.fromWhole(100);
      expect(value.divideBy(4), equals(FixedPoint.fromWhole(25)));
      expect(value.divideBy(3), equals(FixedPoint(333333)));
    });

    test('applies a percentage expressed in basis points', () {
      final value = FixedPoint.fromWhole(100);
      expect(value.applyPercentage(5000), equals(FixedPoint.fromWhole(50)));
      expect(value.applyPercentage(2500), equals(FixedPoint.fromWhole(25)));
    });

    test('conserves value under percentage split and recombination', () {
      // Ledger-conservation invariant: splitting a value into complementary
      // percentages and re-adding them never mints or destroys currency due to
      // rounding.
      final value = FixedPoint.fromWhole(100);
      final partA = value.applyPercentage(3333); // ~33.33%
      final partB = value.applyPercentage(6667); // ~66.67%
      final remainder = value - partA - partB;
      expect(remainder.raw.abs(), lessThanOrEqualTo(FixedPoint.scale));
    });

    test('saturates on overflow instead of wrapping', () {
      final huge = FixedPoint(0x7FFFFFFFFFFFFFFF);
      expect((huge + FixedPoint.fromWhole(1)).raw, equals(0x7FFFFFFFFFFFFFFF));
    });

    test('checked arithmetic throws on overflow', () {
      final huge = FixedPoint(0x7FFFFFFFFFFFFFFF);
      expect(
        () => huge.addChecked(FixedPoint.fromWhole(1)),
        throwsA(isA<StateError>()),
      );
    });
  });

  group('percentToBasisPoints', () {
    test('converts percent doubles to integer basis points', () {
      expect(percentToBasisPoints(5.0), equals(500));
      expect(percentToBasisPoints(50.0), equals(5000));
      expect(percentToBasisPoints(0.01), equals(1));
    });
  });
}
