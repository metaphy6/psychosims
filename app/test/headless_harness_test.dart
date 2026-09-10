import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:psyconfig/psyconfig.dart';

import 'package:psychosims/shared/headless_harness.dart';
import 'package:psychosims/shared/inference_service.dart';
import 'package:psychosims/shared/logger.dart';
import 'package:psychosims/shared/metrics_service.dart';

import 'test_manifest_data.dart';
import 'fake_inference_service.dart';

class _MeasuredInference extends FakeInferenceService {
  int resetCalls = 0;
  bool omitEvaluationCounters = false;

  @override
  void resetKvCache() => resetCalls++;

  @override
  Map<String, Object?> lastGenerateStats() => {
        'prompt_tokens': generationCalls == 1 ? 100 : 150,
        'prompt_eval_ms': generationCalls == 1 ? 20 : 5,
        if (!omitEvaluationCounters)
          'evaluated_prompt_tokens': generationCalls == 1 ? 100 : 40,
        if (!omitEvaluationCounters)
          'reused_prompt_tokens': generationCalls == 1 ? 0 : 110,
      };
}

String _libraryPath() =>
    p.join('..', 'native', 'build', 'libpsychosims_native.so');

String _modelPath() {
  const primary = '../assets/models/qwen2.5-1.5b-instruct-q4_k_m.gguf';
  return File(primary).existsSync()
      ? primary
      : '/tmp/psychosims_poc_model.gguf';
}

void main() {
  test('cache benchmark distinguishes input size from evaluated work',
      () async {
    final inference = _MeasuredInference();
    final manifest = testManifest();
    final harness = HeadlessHarness(
      config: loadConfig(environment: 'test'),
      inference: inference,
      metrics: MetricsService(),
      logger: PsyLog(minLevel: LogLevel.warn),
    );
    final report = await harness.benchmarkPrefixCacheReuse(
        manifest: manifest,
        state: manifest.initialSimState(),
        action: manifest.interactionPatterns.first);
    expect(report.coldPromptTokens, 100);
    expect(report.warmPromptTokens, 150);
    expect(report.tokenReductionPercent, 60);
    expect(report.toJson()['cold_evaluated_prompt_tokens'], 100);
    expect(report.toJson()['warm_evaluated_prompt_tokens'], 40);
    expect(report.toJson()['warm_reused_prompt_tokens'], 110);
    expect(inference.resetCalls, 1);
    expect(report.promptsDiffer, isTrue);
    expect(inference.prompts.first, isNot(inference.prompts.last));
    expect(report.toJson()['comparison'], 'changing_next_turn');
    expect(report.coldComponents!['input_total'],
        inference.count(inference.prompts.first));
    expect(report.warmComponents!['input_total'],
        inference.count(inference.prompts.last));
    expect(report.coldFirstTokenMs, isNonNegative);
    expect(report.warmFirstTokenMs, isNonNegative);
  });

  test('cache benchmark rejects a library without the measurement counters',
      () async {
    final inference = _MeasuredInference()..omitEvaluationCounters = true;
    final manifest = testManifest();
    final harness = HeadlessHarness(
      config: loadConfig(environment: 'test'),
      inference: inference,
      metrics: MetricsService(),
      logger: PsyLog(minLevel: LogLevel.warn),
    );
    await expectLater(
        harness.benchmarkPrefixCacheReuse(
            manifest: manifest,
            state: manifest.initialSimState(),
            action: manifest.interactionPatterns.first),
        throwsStateError);
  });

  test('runs a deterministic turn end-to-end', () async {
    final logger = PsyLog(minLevel: LogLevel.warn);
    final inference = InferenceService.load(
      libraryPath: _libraryPath(),
      logger: logger,
    );
    await inference.loadModel(_modelPath(),
        params: ModelLoadParams(
          backend: File(_modelPath()).existsSync() ? 'llama.cpp' : 'stub',
        ));
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
