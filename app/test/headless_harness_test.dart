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

void main() {
  test('runs a deterministic turn end-to-end', () async {
    final logger = PsyLog(minLevel: LogLevel.warn);
    final inference = InferenceService.load(
      libraryPath: _libraryPath(),
      logger: logger,
    );
    inference.loadModel('/tmp/psychosims_poc_model.gguf');
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

    inference.dispose();
  });
}
