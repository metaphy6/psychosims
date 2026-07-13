import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:psychemas/psychemas.dart';
import 'package:psycore/psycore.dart' as core;
import 'package:psyconfig/psyconfig.dart';

import 'inference_service.dart';
import 'logger.dart';
import 'metrics_service.dart';

/// Headless reproducibility harness for the PoC exit gates.
///
/// Runs the core → assembler → inference path with no UI, under a fixed seed
/// and greedy decode, so the token-budget and determinism artifacts are
/// reproducible in CI. The harness is intentionally small so the same path can
/// be reused by Phase 2.8 solvability bots and Phase 4.3 validation.
class HeadlessHarness {
  HeadlessHarness({
    required this.config,
    required this.inference,
    required this.metrics,
    required this.logger,
  });

  final Config config;
  final InferenceService inference;
  final MetricsService metrics;
  final PsyLog logger;

  /// Runs one deterministic turn and returns the model output plus metrics.
  Future<HarnessResult> runTurn({
    required PatientManifest manifest,
    required core.SimState state,
    required InteractionPattern action,
    List<core.ConversationTurn> conversationWindow = const [],
  }) async {
    final stopwatch = Stopwatch()..start();

    final resolver = core.TurnResolver(core.InjectedClock(0));
    final output = resolver.resolve(core.TurnInput(
      rulesetVersion: manifest.rulesetVersion,
      manifest: manifest,
      state: state,
      action: action,
    ));

    final assembler = core.PromptAssembler(
      tokenCounter: inference,
      chatTemplate: inference,
    );
    final prompt = assembler.assemble(
      rulesetVersion: manifest.rulesetVersion,
      manifest: manifest,
      state: output.nextState,
      conversationWindow: conversationWindow,
      inputBudget: config.promptBudget.maxInputTokens,
      outputReserve: config.promptBudget.maxOutputTokens,
    );

    final buffer = StringBuffer();
    await inference.generate(
      GenerationParams(
        prompt: prompt,
        maxTokens: config.promptBudget.maxOutputTokens,
        temperature:
            config.inference.greedyDecode ? 0.0 : config.inference.temperature,
        topP: config.inference.greedyDecode ? 1.0 : config.inference.topP,
        topK: config.inference.greedyDecode ? 1 : config.inference.topK,
        repetitionPenalty: config.inference.repetitionPenalty,
        seed: config.inference.seed,
        stopTokens: config.inference.stopTokens,
        grammar: config.inference.grammarPath,
      ),
      (token, _) => buffer.write(token),
      nCtx: config.model.nCtx,
    );

    stopwatch.stop();
    metrics.recordTime('headless.turn_latency', stopwatch.elapsed);
    metrics.incrementCounter('headless.turns');

    logger.success('harness', 'turn_complete', kv: {
      'case_id': manifest.id,
      'action': action.name,
      'latency_ms': stopwatch.elapsed.inMilliseconds,
    });

    return HarnessResult(
      prompt: prompt,
      rawResponse: buffer.toString(),
      nextState: output.nextState,
      deltas: output.deltas,
    );
  }

  /// Resolves the path to the native library for CI runs.
  static String defaultLibraryPath() {
    final candidate = p.join('native', 'build', 'libpsychosims_native.so');
    return File(candidate).absolute.path;
  }
}

class HarnessResult {
  final String prompt;
  final String rawResponse;
  final core.SimState nextState;
  final List<StructuredDelta> deltas;

  const HarnessResult({
    required this.prompt,
    required this.rawResponse,
    required this.nextState,
    required this.deltas,
  });
}
