/// Deterministic fixed-point money / ratio representation.
///
/// Uses an integer backing value scaled by 10^4. No platform-dependent
/// floating point in the core economy.
class FixedPoint {
  static const int scale = 10000;
  final int raw;

  const FixedPoint(this.raw);

  factory FixedPoint.fromDouble(double value) {
    return FixedPoint((value * scale).round());
  }

  double toDouble() => raw / scale;

  FixedPoint operator +(FixedPoint other) => FixedPoint(raw + other.raw);
  FixedPoint operator -(FixedPoint other) => FixedPoint(raw - other.raw);
  FixedPoint operator *(int multiplier) => FixedPoint(raw * multiplier);

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
}
