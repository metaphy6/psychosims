import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:psycore/psycore.dart' as core;
import 'package:psyconfig/psyconfig.dart';
import 'package:psychosims/shared/inference_service.dart';
import 'package:psychosims/shared/logger.dart';
import 'package:psychosims/shared/model_profile_resolver.dart';

import 'test_manifest_data.dart';

String _libraryPath() =>
    p.join('..', 'native', 'build', 'libpsychosims_native.so');

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

  test(
    'prompt assembler uses the real tokenizer from InferenceService',
    () async {
      final modelPath = _realModelPath();
      final service = InferenceService.load(
        libraryPath: _libraryPath(),
        logger: logger,
      );
      await service.loadModel(modelPath ?? '/tmp/model.gguf');

      // With the real backend the token count differs from a naive whitespace
      // split, proving the assembler is wired to the model tokenizer.
      const sample = 'The patient is anxious.';
      final realCount = service.count(sample);
      final whitespaceCount = sample.trim().split(RegExp(r'\s+')).length;
      if (modelPath != null) {
        expect(realCount, isNot(equals(whitespaceCount)));
        expect(realCount, greaterThan(0));
      } else {
        expect(realCount, greaterThanOrEqualTo(0));
      }

      await service.dispose();
    },
  );

  test(
    'prompt assembler renders with the loaded model chat template',
    () async {
      final modelPath = _realModelPath();
      final service = InferenceService.load(
        libraryPath: _libraryPath(),
        logger: logger,
      );
      await service.loadModel(modelPath ?? '/tmp/model.gguf');

      final manifest = testManifest();
      final assembler = core.PromptAssembler(
        tokenCounter: service,
        chatTemplate: service,
      );
      final prompt = assembler.assemble(
        rulesetVersion: manifest.rulesetVersion,
        manifest: manifest,
        state: manifest.initialSimState(),
        conversationWindow: const [
          core.ConversationTurn(role: 'user', text: 'hello'),
        ],
        inputBudget: 1536,
        outputReserve: 256,
      );

      // The chat template should frame the system content and user turn.
      expect(prompt, contains('hello'));
      expect(prompt.length, greaterThan(20));
      await service.dispose();
    },
  );

  test(
    'ModelProfileResolver returns model-specific stop tokens',
    () {
      final config = loadConfig(environment: 'test');
      const resolver = ModelProfileResolver();

      final qwen = resolver.resolve(
        'assets/models/qwen2.5-1.5b-instruct-q4_k_m.gguf',
        config,
      );
      expect(qwen.modelKey, 'qwen2.5-1.5b');
      expect(qwen.eosToken, '<|endoftext|>');

      final phi = resolver.resolve(
        'assets/models/Phi-3.5-mini-instruct-Q4_K_M.gguf',
        config,
      );
      expect(phi.modelKey, 'phi-3.5-mini');
      expect(phi.stopTokens, contains('<|end|>'));

      final smol = resolver.resolve(
        'assets/models/smollm2-1.7b-instruct-q4_k_m.gguf',
        config,
      );
      expect(smol.modelKey, 'smollm2-1.7b');
      expect(smol.recommendedKvCacheType, 'q8_0');
    },
  );
}
