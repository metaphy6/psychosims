import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:psychemas/psychemas.dart';
import 'package:psycore/psycore.dart' as core;
import 'package:psyconfig/psyconfig.dart';

import 'inference_service.dart';
import 'logger.dart';
import 'metrics_service.dart';
import 'model_profile_resolver.dart';

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
    this.roleplayFrame = const core.PatientRoleplayFrame(),
  });

  final Config config;
  final InferenceService inference;
  final MetricsService metrics;
  final PsyLog logger;
  final core.RoleplayFrame roleplayFrame;

  /// Runs one deterministic turn and returns the model output plus metrics.
  Future<HarnessResult> runTurn({
    required PatientManifest manifest,
    required core.SimState state,
    required InteractionPattern action,
    List<core.ConversationTurn> conversationWindow = const [],
    String? modelPath,
  }) async {
    final stopwatch = Stopwatch()..start();

    final resolver = core.TurnResolver(
      const core.InjectedClock.replay(0),
      balance: core.CardBalance(
        postponingFreezeTurns: config.balance.postponingFreezeTurns,
      ),
    );
    final resolvedCardIds = manifest.resolvedCards.map((c) => c.id).toList();
    final loadout = Loadout(
      cardIds: resolvedCardIds,
      slotCap: config.balance.activeCardSlots,
    );
    final library = CardLibrary(ownedCardIds: resolvedCardIds.toSet());
    final output = resolver.resolve(core.TurnInput(
      rulesetVersion: manifest.rulesetVersion,
      manifest: manifest,
      state: state,
      action: action,
      loadout: loadout,
      library: library,
      controllers: const TherapyControllerSettings(),
    ));

    final assembler = core.PromptAssembler(
      tokenCounter: inference,
      chatTemplate: inference,
      roleplayFrame: roleplayFrame,
    );
    final prompt = assembler.assemble(
      rulesetVersion: manifest.rulesetVersion,
      manifest: manifest,
      state: output.nextState,
      conversationWindow: conversationWindow,
      inputBudget: config.promptBudget.maxInputTokens,
      outputReserve: config.promptBudget.maxOutputTokens,
    );

    final activeProfile = const ModelProfileResolver().resolve(
      modelPath ?? '/tmp/model.gguf',
      config,
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
        stopTokens: activeProfile.stopTokens,
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

  /// Runs two turns with the same Tier-1 prefix and reports prompt-decode
  /// timing for each. This provides the measurement harness for the KV-cache
  /// prefix-reuse benefit; once the native layer skips already-decoded prefix
  /// tokens, the second turn's `prompt_tokens`/`prompt_eval_ms` will drop.
  Future<PrefixCacheBenchmark> benchmarkPrefixCacheReuse({
    required PatientManifest manifest,
    required core.SimState state,
    required InteractionPattern action,
    String? modelPath,
  }) async {
    // Cold turn: full prompt decode.
    final cold = await runTurn(
      manifest: manifest,
      state: state,
      action: action,
      modelPath: modelPath,
    );
    final coldStats = inference.lastGenerateStats();

    // Warm turn: same T1 prefix plus a synthetic follow-up user turn.
    final warmWindow = [
      core.ConversationTurn(role: 'user', text: action.name),
      core.ConversationTurn(role: 'assistant', text: cold.rawResponse),
      core.ConversationTurn(role: 'user', text: action.name),
    ];
    await runTurn(
      manifest: manifest,
      state: cold.nextState,
      action: action,
      conversationWindow: warmWindow,
      modelPath: modelPath,
    );
    final warmStats = inference.lastGenerateStats();

    return PrefixCacheBenchmark(
      coldPromptTokens: (coldStats['prompt_tokens'] as num?)?.toInt() ?? 0,
      coldPromptEvalMs: (coldStats['prompt_eval_ms'] as num?)?.toInt() ?? 0,
      warmPromptTokens: (warmStats['prompt_tokens'] as num?)?.toInt() ?? 0,
      warmPromptEvalMs: (warmStats['prompt_eval_ms'] as num?)?.toInt() ?? 0,
    );
  }

  /// Resolves the path to the native library for CI runs.
  static String defaultLibraryPath() {
    final candidate = p.join('native', 'build', 'libpsychosims_native.so');
    return File(candidate).absolute.path;
  }
}

/// Result of a prefix-cache reuse benchmark.
class PrefixCacheBenchmark {
  final int coldPromptTokens;
  final int coldPromptEvalMs;
  final int warmPromptTokens;
  final int warmPromptEvalMs;

  const PrefixCacheBenchmark({
    required this.coldPromptTokens,
    required this.coldPromptEvalMs,
    required this.warmPromptTokens,
    required this.warmPromptEvalMs,
  });

  /// Percentage reduction in prompt tokens decoded on the warm turn.
  double get tokenReductionPercent {
    if (coldPromptTokens == 0) return 0.0;
    return 100.0 * (coldPromptTokens - warmPromptTokens) / coldPromptTokens;
  }

  Map<String, Object?> toJson() => {
        'cold_prompt_tokens': coldPromptTokens,
        'cold_prompt_eval_ms': coldPromptEvalMs,
        'warm_prompt_tokens': warmPromptTokens,
        'warm_prompt_eval_ms': warmPromptEvalMs,
        'token_reduction_percent': tokenReductionPercent,
      };
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
