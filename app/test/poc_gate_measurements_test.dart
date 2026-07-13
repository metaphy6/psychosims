// ignore_for_file: avoid_print

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:psyconfig/psyconfig.dart';

import 'package:psychosims/shared/headless_harness.dart';
import 'package:psychosims/shared/inference_service.dart';
import 'package:psychosims/shared/logger.dart';
import 'package:psychosims/shared/metrics_service.dart';

import 'test_manifest_data.dart';

String _libraryPath() =>
    p.join('..', 'native', 'build', 'libpsychosims_native.so');

String _modelPath(String fileName) =>
    p.join('..', 'assets', 'models', fileName);

Future<_ModelMetrics> _measureModel(
  String label,
  String modelFile,
  Config config,
) async {
  final logger = PsyLog(minLevel: LogLevel.warn);
  final inference = InferenceService.load(
    libraryPath: _libraryPath(),
    logger: logger,
  );
  final stopwatch = Stopwatch()..start();
  await inference.loadModel(_modelPath(modelFile));
  final loadMillis = stopwatch.elapsed.inMilliseconds;

  final harness = HeadlessHarness(
    config: config,
    inference: inference,
    metrics: MetricsService(),
    logger: logger,
  );

  final manifest = testManifest();
  final result = await harness.runTurn(
    manifest: manifest,
    state: manifest.initialSimState(),
    action: manifest.interactionPatterns.first,
  );

  await inference.dispose();
  stopwatch.stop();

  final metrics = _ModelMetrics(
    label: label,
    loadMillis: loadMillis,
    promptChars: result.prompt.length,
    responseChars: result.rawResponse.length,
  );

  print(
    '[$label] load=${loadMillis}ms prompt_chars=${result.prompt.length} '
    'response_chars=${result.rawResponse.length} total_ms=${stopwatch.elapsed.inMilliseconds}',
  );
  print('[$label] response:\n${result.rawResponse}\n');

  return metrics;
}

void main() {
  test(
    'measure Tier A primary (Qwen2.5-1.5B) on Linux desktop',
    () async {
      final config = loadConfig(environment: 'dev');
      final qwen = await _measureModel(
        'Qwen2.5-1.5B-Q4_K_M',
        'qwen2.5-1.5b-instruct-q4_k_m.gguf',
        config,
      );
      expect(qwen.responseChars, greaterThan(0));
    },
    timeout: const Timeout(Duration(minutes: 2)),
  );

  test(
    'measure comparator (Phi-3.5-mini) on Linux desktop',
    () async {
      final config = loadConfig(environment: 'dev');
      final phi = await _measureModel(
        'Phi-3.5-mini-Q4_K_M',
        'Phi-3.5-mini-instruct-Q4_K_M.gguf',
        config,
      );
      expect(phi.responseChars, greaterThan(0));
    },
    timeout: const Timeout(Duration(minutes: 5)),
  );
}

class _ModelMetrics {
  final String label;
  final int loadMillis;
  final int promptChars;
  final int responseChars;

  _ModelMetrics({
    required this.label,
    required this.loadMillis,
    required this.promptChars,
    required this.responseChars,
  });
}
