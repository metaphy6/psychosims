import 'dart:io';

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

String _modelPath() {
  const primary = '../assets/models/qwen2.5-1.5b-instruct-q4_k_m.gguf';
  return File(primary).existsSync()
      ? primary
      : '/tmp/psychosims_poc_model.gguf';
}

void main() {
  test('runs a deterministic turn end-to-end', () async {
    final logger = PsyLog(minLevel: LogLevel.warn);
    final inference = InferenceService.load(
      libraryPath: _libraryPath(),
      logger: logger,
    );
    await inference.loadModel(_modelPath());
    final manifest = testManifest();

    final harness = HeadlessHarness(
      config: loadConfig(environment: 'test'),
      inference: inference,
      metrics: MetricsService(),
      logger: logger,
    );

    final result = await harness.runTurn(
      manifest: manifest,
      state: manifest.initialSimState(),
      action: manifest.interactionPatterns.first,
    );

    expect(result.rawResponse, isNotEmpty);
    expect(result.nextState.turn, 1);
    expect(result.deltas, isNotEmpty);

    await inference.dispose();
  });
}
