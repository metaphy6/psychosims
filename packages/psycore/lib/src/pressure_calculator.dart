import 'package:psychemas/psychemas.dart';

/// Configuration values consumed by [PressureCalculator].
class PressureCalculatorConfig {
  final int pressurePerSessionMillis;
  final int pressurePerHighTierMillis;
  final int pressureDailyDecayMillis;

  const PressureCalculatorConfig({
    this.pressurePerSessionMillis = 100,
    this.pressurePerHighTierMillis = 150,
    this.pressureDailyDecayMillis = 20,
  });
}

/// Computes visible operational pressure from accepted session deltas (§23).
///
/// The same inputs feed the Phase 5.5 server-derived quantity, so the offline
/// precursor and server derivation remain shape-compatible.
class PressureCalculator {
  final PressureCalculatorConfig config;

  const PressureCalculator(this.config);

  /// Advances pressure after a resolved session.
  OperationalPressure afterSession({
    required OperationalPressure current,
    required int caseTier,
    required int nowSeconds,
  }) {
    final decayed = _decay(current, nowSeconds);
    var next = decayed.valueMillis + config.pressurePerSessionMillis;
    if (caseTier >= 3) {
      next += config.pressurePerHighTierMillis;
    }
    return OperationalPressure(
      valueMillis: next.clamp(0, 1000),
      lastUpdatedSeconds: nowSeconds,
    );
  }

  /// Applies natural decay based on elapsed time.
  OperationalPressure decay({
    required OperationalPressure current,
    required int nowSeconds,
  }) {
    return _decay(current, nowSeconds);
  }

  OperationalPressure _decay(OperationalPressure current, int nowSeconds) {
    if (current.valueMillis <= 0)
      return current.copyWith(lastUpdatedSeconds: nowSeconds);
    final elapsedDays =
        (nowSeconds - current.lastUpdatedSeconds) ~/ (24 * 60 * 60);
    if (elapsedDays <= 0) return current;
    final decayed =
        current.valueMillis - elapsedDays * config.pressureDailyDecayMillis;
    return OperationalPressure(
      valueMillis: decayed.clamp(0, 1000),
      lastUpdatedSeconds: nowSeconds,
    );
  }
}
