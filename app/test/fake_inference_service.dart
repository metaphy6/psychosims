import 'dart:async';
import 'package:psycore/psycore.dart' as core;
import 'package:psychosims/shared/inference_service.dart';

/// Deterministic inference double; production bindings and resolver stay real.
class FakeInferenceService implements InferenceService {
  final List<String> responses = [];
  final List<String> prompts = [];
  final List<GenerationParams> generations = [];
  int generationCalls = 0;
  String? loadedPath;
  Future<void>? loadDelay;
  Completer<void>? loadStarted;
  void Function()? duringGeneration;

  @override
  Future<void> loadModel(String modelPath,
      {ModelLoadParams params = const ModelLoadParams()}) async {
    loadedPath = modelPath;
    loadStarted?.complete();
    await loadDelay;
  }

  @override
  Future<void> warmUp() async {}
  @override
  void resetKvCache() {}
  @override
  void cancel() {}
  @override
  Future<void> dispose() async {}
  @override
  int count(String text) => const core.WhitespaceTokenCounter().count(text);
  @override
  String render(
          {required String systemFrame,
          required List<core.ConversationTurn> turns}) =>
      const core.PlainChatTemplate()
          .render(systemFrame: systemFrame, turns: turns);
  @override
  Future<void> generate(
      GenerationParams params, void Function(String, bool) onToken,
      {String? correlationId, int nCtx = 2048}) async {
    prompts.add(params.prompt);
    generations.add(params);
    final index = generationCalls++;
    onToken(
        index < responses.length
            ? responses[index]
            : 'I feel restless. [ferve-axine]',
        true);
    duringGeneration?.call();
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
