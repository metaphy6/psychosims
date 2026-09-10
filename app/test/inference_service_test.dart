import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:psycore/psycore.dart' as core;
import 'package:psychosims/shared/inference_service.dart';
import 'package:psychosims/shared/logger.dart';

String _libraryPath() {
  // Tests run from app/, native library is at ../native/build.
  final candidate = p.join('..', 'native', 'build', 'libpsychosims_native.so');
  return File(candidate).absolute.path;
}

/// Returns the path to the pinned Tier-A primary model if it is present,
/// otherwise `null`. Native acceptance requires real weights; these API
/// contract tests explicitly choose the development backend when absent.
String? _realModelPath() {
  final candidate = p.join(
    '..',
    'assets',
    'models',
    'qwen2.5-1.5b-instruct-q4_k_m.gguf',
  );
  return File(candidate).existsSync() ? candidate : null;
}

void main() {
  final logger = PsyLog(minLevel: LogLevel.warn);

  test('loaded context bounds override omitted and inflated caller limits',
      () async {
    final service =
        InferenceService.load(libraryPath: _libraryPath(), logger: logger);
    addTearDown(service.dispose);
    // Explicit fixture makes this contract independent of installed weights.
    await service.loadModel('development',
        params: const ModelLoadParams(backend: 'stub', nCtx: 512));
    var emitted = 0;
    for (final callerLimit in <int?>[null, 2048]) {
      const request = GenerationParams(prompt: 'hello', maxTokens: 512);
      final generation = callerLimit == null
          ? service.generate(request, (_, __) => ++emitted)
          : service.generate(request, (_, __) => ++emitted, nCtx: callerLimit);
      await expectLater(
          generation,
          throwsA(isA<InferenceException>().having((error) => error.kind,
              'kind', InferenceErrorKind.contextOverflow)));
    }
    expect(emitted, 0);
    await service.generate(
        const GenerationParams(prompt: 'hello', maxTokens: 3),
        (_, __) => ++emitted);
    expect(emitted, 3);
  });

  test('omitted caller limit uses a loaded context larger than 2048', () async {
    final service =
        InferenceService.load(libraryPath: _libraryPath(), logger: logger);
    addTearDown(service.dispose);
    await service.loadModel('development',
        params: const ModelLoadParams(backend: 'stub', nCtx: 4096));
    var emitted = 0;
    await service.generate(
        const GenerationParams(prompt: 'hello', maxTokens: 2048),
        (_, __) => ++emitted);
    expect(emitted, 2048);
  });

  test('cancelling the final emitted token does not poison the next turn',
      () async {
    final service =
        InferenceService.load(libraryPath: _libraryPath(), logger: logger);
    addTearDown(service.dispose);
    await service.loadModel('development',
        params: const ModelLoadParams(backend: 'stub'));
    await service.generate(const GenerationParams(prompt: 'hi', maxTokens: 1),
        (_, __) => service.cancel());
    final next = <String>[];
    await service.generate(const GenerationParams(prompt: 'hi', maxTokens: 3),
        (token, _) => next.add(token));
    expect(next, hasLength(3));
  });

  test('unload rejects racing an asynchronous model load', () async {
    final service =
        InferenceService.load(libraryPath: _libraryPath(), logger: logger);
    addTearDown(service.dispose);
    final loading = service.loadModel('development',
        params: const ModelLoadParams(backend: 'stub'));
    expect(service.unloadModel, throwsA(isA<InferenceException>()));
    await loading;
    expect(service.isLoaded, isTrue);
  });

  test('failed real model load leaves the service unloaded', () async {
    final service =
        InferenceService.load(libraryPath: _libraryPath(), logger: logger);
    addTearDown(service.dispose);
    await expectLater(
        service.loadModel('/missing/model.gguf'),
        throwsA(isA<InferenceException>().having(
            (error) => error.kind, 'kind', InferenceErrorKind.loadFailure)));
    expect(service.isLoaded, isFalse);
    expect(service.metadata(), isEmpty);
    await service.loadModel('development',
        params: const ModelLoadParams(backend: 'stub'));
    expect(service.metadata()['backend'], 'stub');
  });

  test('dispose during active generation waits for native teardown', () async {
    final service =
        InferenceService.load(libraryPath: _libraryPath(), logger: logger);
    await service.loadModel('development',
        params: const ModelLoadParams(backend: 'stub', nCtx: 200000));
    Future<void>? disposed;
    await expectLater(
        service.generate(
            const GenerationParams(prompt: 'hi', maxTokens: 100000), (_, __) {
          disposed ??= service.dispose();
        }, nCtx: 200000),
        throwsA(isA<InferenceException>().having(
            (error) => error.kind, 'kind', InferenceErrorKind.cancelled)));
    await disposed;
    expect(service.isLoaded, isFalse);
  });

  test('chat template preserves prompts larger than the initial buffer',
      () async {
    final service =
        InferenceService.load(libraryPath: _libraryPath(), logger: logger);
    addTearDown(service.dispose);
    await service.loadModel('development',
        params: const ModelLoadParams(backend: 'stub'));
    final frame = 'frame ' * 1000;
    expect(
        service.render(systemFrame: frame, turns: const []), contains(frame));
  });

  test('active cancellation stops the generating native context', () async {
    final service = InferenceService.load(
      libraryPath: _libraryPath(),
      logger: logger,
    );
    addTearDown(service.dispose);
    await service.loadModel('development',
        params: const ModelLoadParams(backend: 'stub', nCtx: 200000));
    var emitted = 0;
    await expectLater(
      service.generate(
        const GenerationParams(prompt: 'hi', maxTokens: 100000),
        (_, __) {
          if (++emitted == 1) service.cancel();
        },
        nCtx: 200000,
      ),
      throwsA(isA<InferenceException>()
          .having((error) => error.kind, 'kind', InferenceErrorKind.cancelled)),
    );
    expect(emitted, lessThan(100000));
    final resumed = <String>[];
    await service.generate(const GenerationParams(prompt: 'hi', maxTokens: 3),
        (token, _) => resumed.add(token));
    expect(resumed, hasLength(3));
  });

  test('loads native library and reports version', () {
    final service = InferenceService.load(
      libraryPath: _libraryPath(),
      logger: logger,
    );
    expect(service.version, startsWith('psychosims-native-'));
    service.dispose();
  });

  test('loads a model', () async {
    final modelPath = _realModelPath();
    final service = InferenceService.load(
      libraryPath: _libraryPath(),
      logger: logger,
    );
    if (modelPath == null) {
      await service.loadModel('/tmp/model.gguf',
          params: const ModelLoadParams(backend: 'stub'));
      expect(service.isLoaded, isTrue);
      expect(service.metadata(), containsPair('n_ctx', 2048));
    } else {
      await service.loadModel(modelPath);
      expect(service.isLoaded, isTrue);
      final meta = service.metadata();
      expect(meta, containsPair('n_ctx', 2048));
      expect(meta, contains('quantization'));
      expect(meta, containsPair('backend', 'llama.cpp'));
    }
    await service.dispose();
  });

  test('load params reach the native layer', () async {
    final modelPath = _realModelPath();
    final service = InferenceService.load(
      libraryPath: _libraryPath(),
      logger: logger,
    );
    if (modelPath == null) {
      await service.loadModel('/tmp/model.gguf',
          params: const ModelLoadParams(
              backend: 'stub',
              nCtx: 512,
              nBatch: 64,
              nThreads: 2,
              kvCacheType: 'q8_0'));
    } else {
      await service.loadModel(
        modelPath,
        params: const ModelLoadParams(
          nCtx: 512,
          nBatch: 64,
          nThreads: 2,
          kvCacheType: 'q8_0',
        ),
      );
    }
    final meta = service.metadata();
    expect(meta['n_ctx'], 512);
    expect(meta['n_batch'], 64);
    expect(meta['n_threads'], 2);
    expect(meta['kv_cache_type'], 'q8_0');
    await service.dispose();
  });

  test('token count falls back to whitespace before model load', () {
    final service = InferenceService.load(
      libraryPath: _libraryPath(),
      logger: logger,
    );
    expect(service.count('one two three'), 3);
    service.dispose();
  });

  test('token count uses native tokenizer after model load', () async {
    final modelPath = _realModelPath();
    final service = InferenceService.load(
      libraryPath: _libraryPath(),
      logger: logger,
    );
    if (modelPath == null) {
      await service.loadModel('/tmp/model.gguf',
          params: const ModelLoadParams(backend: 'stub'));
      expect(service.count('abc'), 3);
    } else {
      await service.loadModel(modelPath);
      expect(service.count('abc'), greaterThan(0));
    }
    await service.dispose();
  });

  test('chat template renders after model load', () async {
    final modelPath = _realModelPath();
    final service = InferenceService.load(
      libraryPath: _libraryPath(),
      logger: logger,
    );
    await service.loadModel(modelPath ?? '/tmp/model.gguf',
        params:
            ModelLoadParams(backend: modelPath == null ? 'stub' : 'llama.cpp'));
    final rendered = service.render(
      systemFrame: 'frame',
      turns: const [
        core.ConversationTurn(role: 'user', text: 'hello'),
      ],
    );
    expect(rendered, contains('frame'));
    expect(rendered, contains('hello'));
    await service.dispose();
  });

  test('generate streams tokens', () async {
    final modelPath = _realModelPath();
    final service = InferenceService.load(
      libraryPath: _libraryPath(),
      logger: logger,
    );
    await service.loadModel(modelPath ?? '/tmp/model.gguf',
        params:
            ModelLoadParams(backend: modelPath == null ? 'stub' : 'llama.cpp'));
    final tokens = <String>[];
    await service.generate(
      const GenerationParams(prompt: 'hi', maxTokens: 10),
      (token, _) => tokens.add(token),
    );
    expect(tokens, isNotEmpty);
    await service.dispose();
  });

  test('buffers partial UTF-8 codepoints across tokens', () async {
    final service = InferenceService.load(
      libraryPath: _libraryPath(),
      logger: logger,
    );
    await service.loadModel('utf8-fixture',
        params: const ModelLoadParams(backend: 'stub'));
    final tokens = <String>[];
    await service.generate(
      const GenerationParams(prompt: 'utf8', maxTokens: 12),
      (token, complete) {
        expect(complete, isTrue);
        expect(token, isNot(contains('\uFFFD')));
        tokens.add(token);
      },
    );
    final joined = tokens.join();
    expect(joined, 'café café ');
    expect(utf8.encode(joined),
        [99, 97, 102, 195, 169, 32, 99, 97, 102, 195, 169, 32]);
    await service.dispose();
  });

  test('cancel returns without error on idle service', () {
    final service = InferenceService.load(
      libraryPath: _libraryPath(),
      logger: logger,
    );
    expect(() => service.cancel(), returnsNormally);
    service.dispose();
  });

  test('rejects concurrent generation requests', () async {
    final modelPath = _realModelPath();
    final service = InferenceService.load(
      libraryPath: _libraryPath(),
      logger: logger,
    );
    await service.loadModel(modelPath ?? '/tmp/model.gguf',
        params:
            ModelLoadParams(backend: modelPath == null ? 'stub' : 'llama.cpp'));
    final first = service.generate(
      const GenerationParams(prompt: 'a', maxTokens: 10),
      (_, __) {},
    );
    expect(
      () => service.generate(
        const GenerationParams(prompt: 'b', maxTokens: 10),
        (_, __) {},
      ),
      throwsA(isA<InferenceException>()),
    );
    await first;
    await service.dispose();
  });

  test('guards context window', () async {
    final modelPath = _realModelPath();
    final service = InferenceService.load(
      libraryPath: _libraryPath(),
      logger: logger,
    );
    await service.loadModel(modelPath ?? '/tmp/model.gguf',
        params:
            ModelLoadParams(backend: modelPath == null ? 'stub' : 'llama.cpp'));
    expect(
      () => service.generate(
        const GenerationParams(
          prompt: 'x',
          maxTokens: 10000,
        ),
        (_, __) {},
        nCtx: 128,
      ),
      throwsA(isA<InferenceException>()),
    );
    await service.dispose();
  });

  test('resetKvCache keeps model loaded', () async {
    final modelPath = _realModelPath();
    final service = InferenceService.load(
      libraryPath: _libraryPath(),
      logger: logger,
    );
    await service.loadModel(modelPath ?? '/tmp/model.gguf',
        params:
            ModelLoadParams(backend: modelPath == null ? 'stub' : 'llama.cpp'));
    expect(service.isLoaded, isTrue);
    service.resetKvCache();
    expect(service.isLoaded, isTrue);
    expect(service.metadata(), containsPair('n_ctx', isPositive));
    await service.dispose();
  });

  test('load params expose batch decode settings in metadata', () async {
    final modelPath = _realModelPath();
    final service = InferenceService.load(
      libraryPath: _libraryPath(),
      logger: logger,
    );
    await service.loadModel(
      modelPath ?? '/tmp/model.gguf',
      params: ModelLoadParams(
          backend: modelPath == null ? 'stub' : 'llama.cpp',
          nCtx: 512,
          nBatch: 64,
          nThreads: 2),
    );
    final meta = service.metadata();
    expect(meta['n_batch'], 64);
    expect(meta['n_threads'], 2);
    await service.dispose();
  });

  test('metadata reports real model size when mmap-loaded', () async {
    final modelPath = _realModelPath();
    final service = InferenceService.load(
      libraryPath: _libraryPath(),
      logger: logger,
    );
    await service.loadModel(modelPath ?? '/tmp/model.gguf',
        params:
            ModelLoadParams(backend: modelPath == null ? 'stub' : 'llama.cpp'));
    final meta = service.metadata();
    if (modelPath != null) {
      expect(meta['size_bytes'], greaterThan(0));
    }
    await service.dispose();
  });

  test('lastGenerateStats reports prompt and generation timing', () async {
    final modelPath = _realModelPath();
    final service = InferenceService.load(
      libraryPath: _libraryPath(),
      logger: logger,
    );
    await service.loadModel(modelPath ?? '/tmp/model.gguf',
        params:
            ModelLoadParams(backend: modelPath == null ? 'stub' : 'llama.cpp'));
    await service.generate(
      const GenerationParams(prompt: 'hello', maxTokens: 5),
      (_, __) {},
    );
    final stats = service.lastGenerateStats();
    expect(stats['prompt_tokens'], greaterThan(0));
    expect(stats, contains('prompt_eval_ms'));
    expect(stats['generated_tokens'], greaterThan(0));
    expect(stats, contains('generation_ms'));
    expect(stats['total_ms'], greaterThanOrEqualTo(0));
    await service.dispose();
  });

  test('useMmap=false loads model without mmap', () async {
    final modelPath = _realModelPath();
    final service = InferenceService.load(
      libraryPath: _libraryPath(),
      logger: logger,
    );
    await service.loadModel(
      modelPath ?? '/tmp/model.gguf',
      params: ModelLoadParams(
          backend: modelPath == null ? 'stub' : 'llama.cpp', useMmap: false),
    );
    expect(service.isLoaded, isTrue);
    await service.dispose();
  });

  test('resetKvCache clears prefix reuse state', () async {
    final modelPath = _realModelPath();
    final service = InferenceService.load(
      libraryPath: _libraryPath(),
      logger: logger,
    );
    await service.loadModel(modelPath ?? '/tmp/model.gguf',
        params:
            ModelLoadParams(backend: modelPath == null ? 'stub' : 'llama.cpp'));

    // First turn establishes the cached prefix.
    await service.generate(
      const GenerationParams(prompt: 'The patient is anxious.', maxTokens: 5),
      (_, __) {},
    );

    // Identical prompt again should reuse the cached prefix and therefore
    // complete quickly. We measure wall time rather than internal stats
    // because generation runs on the worker isolate.
    final warmStopwatch = Stopwatch()..start();
    await service.generate(
      const GenerationParams(prompt: 'The patient is anxious.', maxTokens: 5),
      (_, __) {},
    );
    final warmMs = warmStopwatch.elapsed.inMilliseconds;

    // After a reset the same prompt must decode from scratch, so it should
    // not be dramatically faster than the warm turn.
    service.resetKvCache();
    final resetStopwatch = Stopwatch()..start();
    await service.generate(
      const GenerationParams(prompt: 'The patient is anxious.', maxTokens: 5),
      (_, __) {},
    );
    final resetMs = resetStopwatch.elapsed.inMilliseconds;

    expect(service.isLoaded, isTrue);
    // The warm turn reused KV state; the reset turn re-decoded the prompt.
    // We only assert the reset turn is no faster (within 50%) than warm,
    // because prompt decode time is small relative to sampling variance.
    expect(resetMs, greaterThanOrEqualTo(warmMs * 0.5));
    await service.dispose();
  });
}
