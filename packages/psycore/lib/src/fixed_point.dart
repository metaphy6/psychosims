/// Deterministic fixed-point money / ratio representation.
///
/// Uses an integer backing value scaled by 10^4. All arithmetic is integer-only
/// with a single documented rounding mode: **round-half-to-even** (banker's
/// rounding). No platform-dependent floating point participates in core
/// economy rules.
///
/// The backing is saturating by default: overflow/underflow clamps to the
/// largest/smallest representable value rather than silently wrapping. Callers
/// that need an error on overflow can use [addChecked], [subtractChecked], and
/// [multiplyByRatioChecked].
class FixedPoint {
  static const int scale = 10000;
  static const int _maxRaw = 0x7FFFFFFFFFFFFFFF;
  static const int _minRaw = -0x8000000000000000;

  final int raw;

  const FixedPoint(this.raw);

  const FixedPoint.zero() : raw = 0;

  /// Whole units only (e.g. `FixedPoint.fromWhole(5)` == 5.0000).
  factory FixedPoint.fromWhole(int whole) => FixedPoint(whole * scale);

  /// Integer basis points (1 bp = 0.01 %). `5000` == 50% == 0.5000.
  factory FixedPoint.fromBasisPoints(int basisPoints) =>
      FixedPoint(basisPoints);

  /// Exact decimal string, e.g. `"1.2345"`.
  factory FixedPoint.fromString(String value) {
    final parts = value.split('.');
    final whole = int.parse(parts[0]);
    if (parts.length == 1) return FixedPoint.fromWhole(whole);
    var frac = parts[1].padRight(4, '0').substring(0, 4);
    final sign = whole < 0 ? -1 : 1;
    return FixedPoint(whole * scale + (sign * int.parse(frac)));
  }

  /// Config-boundary conversion from `double`.
  ///
  /// This factory exists **only** at the config→core seam. It must never be
  /// called inside a deterministic rule; percentages are converted to
  /// fixed-point ratios once at the boundary and then flow through
  /// [fromBasisPoints] / [multiplyByRatio].
  factory FixedPoint.fromDouble(double value) {
    return FixedPoint((value * scale).roundToEven());
  }

  double toDouble() => raw / scale;

  int toWhole() => raw ~/ scale;

  /// Saturating addition.
  FixedPoint operator +(FixedPoint other) {
    if (other.raw >= 0) {
      if (raw > _maxRaw - other.raw) return const FixedPoint(_maxRaw);
      return FixedPoint(raw + other.raw);
    } else {
      if (raw < _minRaw - other.raw) return const FixedPoint(_minRaw);
      return FixedPoint(raw + other.raw);
    }
  }

  /// Saturating subtraction.
  FixedPoint operator -(FixedPoint other) {
    if (other.raw >= 0) {
      if (raw < _minRaw + other.raw) return const FixedPoint(_minRaw);
      return FixedPoint(raw - other.raw);
    } else {
      if (raw > _maxRaw + other.raw) return const FixedPoint(_maxRaw);
      return FixedPoint(raw - other.raw);
    }
  }

  /// Exact multiplication by a signed integer scalar.
  FixedPoint operator *(int multiplier) {
    // Detect overflow before it wraps.
    if (multiplier == 0) return const FixedPoint.zero();
    if (raw == 0) return const FixedPoint.zero();
    final limit = raw > 0 ? _maxRaw : _minRaw;
    final bound = limit ~/ multiplier;
    if (multiplier > 0) {
      if (raw > bound) return const FixedPoint(_maxRaw);
      if (raw < -bound) return const FixedPoint(_minRaw);
    } else {
      if (raw < bound) return const FixedPoint(_maxRaw);
      if (raw > -bound) return const FixedPoint(_minRaw);
    }
    return FixedPoint(raw * multiplier);
  }

  /// Checked addition; throws [StateError] on overflow/underflow.
  FixedPoint addChecked(FixedPoint other) {
    if (other.raw >= 0 && raw > _maxRaw - other.raw) {
      throw StateError('FixedPoint overflow: $raw + ${other.raw}');
    }
    if (other.raw < 0 && raw < _minRaw - other.raw) {
      throw StateError('FixedPoint underflow: $raw + ${other.raw}');
    }
    return FixedPoint(raw + other.raw);
  }

  /// Checked subtraction; throws [StateError] on overflow/underflow.
  FixedPoint subtractChecked(FixedPoint other) {
    if (other.raw >= 0 && raw < _minRaw + other.raw) {
      throw StateError('FixedPoint underflow: $raw - ${other.raw}');
    }
    if (other.raw < 0 && raw > _maxRaw + other.raw) {
      throw StateError('FixedPoint overflow: $raw - ${other.raw}');
    }
    return FixedPoint(raw - other.raw);
  }

  /// Multiply by a [ratio] expressed as a fixed-point fraction.
  ///
  /// `value.multiplyByRatio(FixedPoint(5000))` == value * 0.5.
  /// Rounds half-to-even.
  FixedPoint multiplyByRatio(FixedPoint ratio) {
    final product = raw * ratio.raw;
    final scaled = _divideRoundHalfToEven(product, scale);
    return FixedPoint(_saturate(scaled));
  }

  /// Checked variant of [multiplyByRatio]; throws on overflow.
  FixedPoint multiplyByRatioChecked(FixedPoint ratio) {
    final product = raw * ratio.raw;
    final scaled = _divideRoundHalfToEven(product, scale);
    if (_wouldOverflow(scaled)) {
      throw StateError('FixedPoint ratio overflow: $raw * ${ratio.raw}');
    }
    return FixedPoint(scaled);
  }

  /// Divide by a positive integer divisor, rounding half-to-even.
  FixedPoint divideBy(int divisor) {
    if (divisor == 0) throw ArgumentError('division by zero');
    return FixedPoint(_divideRoundHalfToEven(raw, divisor));
  }

  /// Apply a percentage expressed in basis points.
  ///
  /// `value.applyPercentage(5000)` returns value * 50%.
  FixedPoint applyPercentage(int basisPoints) =>
      multiplyByRatio(FixedPoint.fromBasisPoints(basisPoints));

  /// Returns the negated value (saturating).
  FixedPoint negate() => FixedPoint(_saturate(-raw));

  static int _saturate(int value) {
    if (value > _maxRaw) return _maxRaw;
    if (value < _minRaw) return _minRaw;
    return value;
  }

  static bool _wouldOverflow(int value) => value > _maxRaw || value < _minRaw;

  /// Divides [numerator] by [denominator] with round-half-to-even.
  static int _divideRoundHalfToEven(int numerator, int denominator) {
    final quotient = numerator ~/ denominator;
    final remainder = numerator.remainder(denominator);
    final absDen = denominator.abs();
    final absRem = remainder.abs();
    final twice = absRem * 2;
    if (twice > absDen || (twice == absDen && quotient.isOdd)) {
      return quotient + (numerator.sign == denominator.sign ? 1 : -1);
    }
    return quotient;
  }

  @override
  String toString() {
    final whole = raw ~/ scale;
    final frac = (raw.abs() % scale).toString().padLeft(4, '0');
    return '$whole.$frac';
  }

  @override
  bool operator ==(Object other) => other is FixedPoint && other.raw == raw;

  @override
  int get hashCode => raw.hashCode;

  /// Compares two values.
  int compareTo(FixedPoint other) => raw.compareTo(other.raw);

  bool operator <(FixedPoint other) => raw < other.raw;
  bool operator <=(FixedPoint other) => raw <= other.raw;
  bool operator >(FixedPoint other) => raw > other.raw;
  bool operator >=(FixedPoint other) => raw >= other.raw;
}

extension on double {
  int roundToEven() {
    final truncated = truncate();
    final frac = this - truncated;
    if (frac.abs() < 0.5) return truncated;
    if (frac.abs() > 0.5) return truncated + (this > 0 ? 1 : -1);
    // Exactly half: round to even.
    if (truncated.isEven) return truncated;
    return truncated + (this > 0 ? 1 : -1);
  }
}

/// A fixed-point ratio independent of money semantics.
///
/// Used by the config→core seam so percentages arrive as integer basis points
/// and are converted to a [FixedPoint] ratio once, at the boundary. No `double`
/// multiplication ever enters a deterministic rule.
typedef Ratio = FixedPoint;

/// Converts a config percentage `double` to integer basis points.
///
/// This is the **only** place a config `double` percentage becomes a core
/// ratio. The result is an exact integer basis-point value; non-representable
/// values like 0.1 % are rounded half-to-even and the integer bp is what flows
/// into core rules.
int percentToBasisPoints(double percent) {
  final scaled = percent * 100.0;
  final rounded = scaled >= 0 ? scaled + 0.0001 : scaled - 0.0001;
  return rounded.round();
}

/// Converts a config fractional rate `double` (e.g. 0.02) to basis points.
int fractionToBasisPoints(double fraction) {
  final scaled = fraction * 10000.0;
  final rounded = scaled >= 0 ? scaled + 0.0001 : scaled - 0.0001;
  return rounded.round();
}
