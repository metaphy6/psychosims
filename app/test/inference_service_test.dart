import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:psycore/psycore.dart' as core;
import 'package:psychosims/shared/inference_service.dart';
import 'package:psychosims/shared/logger.dart';

String _libraryPath() {
  // Tests run from app/, native stub is at ../native/build.
  final candidate = p.join('..', 'native', 'build', 'libpsychosims_native.so');
  return File(candidate).absolute.path;
}

void main() {
  final logger = PsyLog(minLevel: LogLevel.warn);

  test('loads native library and reports version', () {
    final service = InferenceService.load(
      libraryPath: _libraryPath(),
      logger: logger,
    );
    expect(service.version, startsWith('psychosims-native-'));
    service.dispose();
  });

  test('loads a model stub', () {
    final service = InferenceService.load(
      libraryPath: _libraryPath(),
      logger: logger,
    );
    service.loadModel('/tmp/model.gguf');
    expect(service.isLoaded, isTrue);
    expect(service.metadata(), containsPair('n_ctx', 2048));
    service.dispose();
  });

  test('token count falls back to whitespace before model load', () {
    final service = InferenceService.load(
      libraryPath: _libraryPath(),
      logger: logger,
    );
    expect(service.count('one two three'), 3);
    service.dispose();
  });

  test('token count uses native tokenizer after model load', () {
    final service = InferenceService.load(
      libraryPath: _libraryPath(),
      logger: logger,
    );
    service.loadModel('/tmp/model.gguf');
    // Stub tokenizer returns one token per byte.
    expect(service.count('abc'), 3);
    service.dispose();
  });

  test('chat template renders via native stub after model load', () {
    final service = InferenceService.load(
      libraryPath: _libraryPath(),
      logger: logger,
    );
    service.loadModel('/tmp/model.gguf');
    final rendered = service.render(
      systemFrame: 'frame',
      turns: const [
        core.ConversationTurn(role: 'user', text: 'hello'),
      ],
    );
    expect(rendered, contains('frame'));
    expect(rendered, contains('hello'));
    service.dispose();
  });

  test('generate streams deterministic stub tokens', () async {
    final service = InferenceService.load(
      libraryPath: _libraryPath(),
      logger: logger,
    );
    service.loadModel('/tmp/model.gguf');
    final tokens = <String>[];
    await service.generate(
      const GenerationParams(prompt: 'hi', maxTokens: 10),
      (token, _) => tokens.add(token),
    );
    expect(tokens, isNotEmpty);
    expect(tokens.join(), contains('deterministic stub response'));
    service.dispose();
  });

  test('cancel returns without error on idle service', () {
    final service = InferenceService.load(
      libraryPath: _libraryPath(),
      logger: logger,
    );
    expect(() => service.cancel(), returnsNormally);
    service.dispose();
  });
}
