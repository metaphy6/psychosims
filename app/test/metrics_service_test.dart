import 'package:flutter_test/flutter_test.dart';
import 'package:psychosims/shared/metrics_service.dart';

void main() {
  test('records and summarizes timers', () {
    final metrics = MetricsService();
    metrics.recordTime('latency', const Duration(milliseconds: 10));
    metrics.recordTime('latency', const Duration(milliseconds: 20));
    metrics.recordTime('latency', const Duration(milliseconds: 30));

    final summary = metrics.timerSummary('latency')!;
    expect(summary.median.inMilliseconds, 20);
    expect(summary.count, 3);
  });

  test('records gauges and counters', () {
    final metrics = MetricsService();
    metrics.recordGauge('ram_mb', 512);
    metrics.incrementCounter('turns');
    metrics.incrementCounter('turns');

    expect(metrics.latestGauge('ram_mb'), 512);
    expect(metrics.counters['turns'], 2);
  });
}
