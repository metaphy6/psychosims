import 'dart:collection';

/// Local measurement instrumentation for the PoC exit gates.
///
/// Records timers (latency) and gauges (peak values) in memory. Phase 1.6
/// consumes these snapshots; later phases will forward them through the 0.7
/// telemetry contract once the opt-in pipeline exists.
class MetricsService {
  final Map<String, List<Duration>> _timers = {};
  final Map<String, List<double>> _gauges = {};
  final Map<String, int> _counters = {};

  /// Records a timer value.
  void recordTime(String name, Duration duration) {
    _timers.putIfAbsent(name, () => []).add(duration);
  }

  /// Records a gauge sample (e.g. peak RAM in MiB, tokens/sec).
  void recordGauge(String name, double value) {
    _gauges.putIfAbsent(name, () => []).add(value);
  }

  /// Atomically increments a counter.
  void incrementCounter(String name, {int delta = 1}) {
    _counters.update(name, (v) => v + delta, ifAbsent: () => delta);
  }

  /// Returns a statistical snapshot of a timer: median and p95.
  TimerSummary? timerSummary(String name) {
    final values = _timers[name];
    if (values == null || values.isEmpty) return null;
    final sorted = List<Duration>.of(values)..sort();
    final median = sorted[sorted.length ~/ 2];
    final p95Index = (sorted.length * 0.95).ceil() - 1;
    final p95 = sorted[p95Index.clamp(0, sorted.length - 1)];
    return TimerSummary(median: median, p95: p95, count: sorted.length);
  }

  /// Returns the latest recorded gauge value.
  double? latestGauge(String name) {
    final values = _gauges[name];
    if (values == null || values.isEmpty) return null;
    return values.last;
  }

  /// Returns all counters.
  Map<String, int> get counters => UnmodifiableMapView(_counters);

  /// Clears all recorded metrics.
  void clear() {
    _timers.clear();
    _gauges.clear();
    _counters.clear();
  }
}

class TimerSummary {
  final Duration median;
  final Duration p95;
  final int count;

  const TimerSummary({
    required this.median,
    required this.p95,
    required this.count,
  });

  Map<String, Object?> toJson() => {
        'median_ms': median.inMilliseconds,
        'p95_ms': p95.inMilliseconds,
        'count': count,
      };
}
