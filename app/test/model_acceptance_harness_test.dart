import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:psyconfig/psyconfig.dart';

import '../tools/model_acceptance.dart';
import 'fake_inference_service.dart';
import 'test_manifest_data.dart';

void main() {
  final config = loadConfig(environment: 'dev');

  test('throughput counts sampled tokens independent of UTF-8 callbacks', () {
    expect(
        generationTokensPerSecond(
            {'generated_tokens': 3, 'generation_ms': 100, 'callbacks': 1}),
        30);
    for (final stats in <Map<String, Object?>>[
      {},
      {'generated_tokens': 0, 'generation_ms': 1},
      {'generated_tokens': 1.5, 'generation_ms': 100},
      {'generated_tokens': double.nan, 'generation_ms': 100},
      {'generated_tokens': 3, 'generation_ms': double.infinity},
      {'generated_tokens': 3, 'generation_ms': 0},
    ]) {
      expect(() => generationTokensPerSecond(stats), throwsStateError);
    }
  });

  test('percentiles retain outliers and do not mutate samples', () {
    final values = List<double>.generate(20, (i) => 20.0 - i);
    final summary = Distribution(values);
    expect(summary.median, 10.5);
    expect(summary.p95, 19);
    expect(summary.maximum, 20);
    expect(values.first, 20);
  });

  test('measurement summary rejects missing and invalid observations', () {
    expect(() => Distribution([]), throwsArgumentError);
    expect(() => Distribution([double.nan]), throwsArgumentError);
    expect(() => Distribution([-1]), throwsArgumentError);
    expect(() => Distribution([double.infinity]), throwsArgumentError);
  });

  test('budget refuses overflow and preserves configured generation reserve',
      () {
    expect(() => checkBudget(config, 1280, 2048), returnsNormally);
    expect(() => checkBudget(config, 1537, 2048), throwsStateError);
    expect(() => checkBudget(config, 1280, 1400), throwsStateError);
    expect(() => checkBudget(config, 0, 2048), throwsStateError);
  });

  test('model profile must match its configured artifact before loading', () {
    final candidate = ModelCandidate.fromConfig(
        config, config.model.tierAPrimaryUrl, Directory('models'));
    expect(candidate.profile.modelKey, 'qwen2.5-1.5b');
    expect(
        () => candidate.requirePath('models/Phi-3.5-mini-instruct-Q4_K_M.gguf'),
        throwsStateError);
    expect(() => candidate.requirePath(candidate.path), returnsNormally);
    expect(
        () => ModelCandidate.fromConfig(config,
            'https://invalid.example/unconfigured.gguf', Directory('models')),
        throwsArgumentError);
  });

  test('missing weights fail rather than select a different local model',
      () async {
    final candidate = ModelCandidate.fromConfig(
        config,
        config.model.tierAPrimaryUrl,
        Directory('definitely-no-acceptance-models'));
    await expectLater(candidate.verify(), throwsStateError);
  });

  test('the accepted sample count cannot be silently reduced', () {
    expect(() => requireSampleCount(20), returnsNormally);
    expect(() => requireSampleCount(19), throwsArgumentError);
  });

  test('a correctly named but corrupt artifact cannot pass acceptance',
      () async {
    final directory =
        await Directory('/tmp/agent-runs').createTemp('w4-model-');
    addTearDown(() => directory.delete(recursive: true));
    final candidate = ModelCandidate.fromConfig(
        config, config.model.tierAPrimaryUrl, directory);
    await File(candidate.path).writeAsString('GGUF incorrect content');
    await expectLater(candidate.verify(), throwsStateError);
  });

  test('populated context includes production frame and medication history',
      () {
    final fixture = AcceptanceFixture(testManifest());
    final inference = FakeInferenceService();
    final prompt = fixture.assemble(inference, config);
    expect(prompt, contains('You are an actor'));
    expect(prompt, contains('999999 prior sessions'));
    expect(prompt, isNot(contains('ferveAxine')));
    expect(prompt, contains('ferve-axine'));
    expect(fixture.window(), hasLength(fixture.manifest.maxHistoryTurns));
    final stress = fixture.assemble(inference, config, overloaded: true);
    expect(stress, isNot(contains('OLDEST_WINDOW')));
    expect(stress, contains('999999 prior sessions'));
    expect(stress, contains('ferve-axine'));
    checkBudget(config, inference.count(stress), config.model.nCtx);
  });
}
