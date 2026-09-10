import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:psychemas/psychemas.dart';
import 'package:psycore/psycore.dart' as core;
import 'package:psyconfig/psyconfig.dart';

import 'inference_service.dart';
import 'dialogue_sanitizer.dart';
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
      balance: core.CardBalance.fromConfig(config.balance),
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
    final assembly = assembler.assembleDetailed(
      rulesetVersion: manifest.rulesetVersion,
      manifest: manifest,
      state: output.nextState,
      conversationWindow: conversationWindow,
      inputBudget: config.promptBudget.maxInputTokens,
      outputReserve: config.promptBudget.maxOutputTokens,
    );

    final prompt = assembly.prompt;

    final activeProfile = const ModelProfileResolver().resolve(
      modelPath ?? '/tmp/model.gguf',
      config,
    );

    final buffer = StringBuffer();
    final generationClock = Stopwatch()..start();
    double? firstTokenMs;
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
      (token, complete) {
        if (token.isNotEmpty && complete) {
          firstTokenMs ??= generationClock.elapsedMicroseconds / 1000;
        }
        buffer.write(token);
      },
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
      tokenBreakdown: assembly.tokens,
      firstTokenMs: firstTokenMs,
    );
  }

  /// Runs two turns with the same Tier-1 prefix and reports prompt-decode
  /// timing for each. This provides the measurement harness for the KV-cache
  /// prefix-reuse benefit; once the native layer skips already-decoded prefix
  /// tokens, the second turn's `evaluated_prompt_tokens` will exclude them.
  /// `prompt_tokens` remains the complete input size; elapsed time is measured
  /// independently and is never inferred from the number of reused tokens.
  Future<PrefixCacheBenchmark> benchmarkPrefixCacheReuse({
    required PatientManifest manifest,
    required core.SimState state,
    required InteractionPattern action,
    String? modelPath,
  }) async {
    // Cold turn: full prompt decode.
    inference.resetKvCache();
    final cold = await runTurn(
      manifest: manifest,
      state: state,
      action: action,
      modelPath: modelPath,
      conversationWindow: [
        core.ConversationTurn(role: 'user', text: action.name)
      ],
    );
    final coldStats = inference.lastGenerateStats();

    // Warm turn: same T1 prefix plus a synthetic follow-up user turn.
    final warmWindow = [
      core.ConversationTurn(role: 'user', text: action.name),
      core.ConversationTurn(
          role: 'assistant',
          text: const DialogueSanitizer()
              .sanitize(cold.rawResponse, clueTokens: manifest.clueTokens)),
      core.ConversationTurn(role: 'user', text: action.name),
    ];
    final warm = await runTurn(
      manifest: manifest,
      state: cold.nextState,
      action: action,
      conversationWindow: warmWindow,
      modelPath: modelPath,
    );
    final warmStats = inference.lastGenerateStats();
    if (cold.prompt == warm.prompt) {
      throw StateError('Next-turn benchmark requires a changing prompt');
    }

    int requiredCounter(Map<String, Object?> stats, String key) {
      final value = stats[key];
      if (value is! num || value < 0 || value != value.toInt()) {
        throw StateError(
            'Native cache measurement requires $key; rebuild the native library');
      }
      return value.toInt();
    }

    return PrefixCacheBenchmark(
      promptsDiffer: cold.prompt != warm.prompt,
      coldFirstTokenMs: cold.firstTokenMs,
      warmFirstTokenMs: warm.firstTokenMs,
      coldComponents: cold.tokenBreakdown?.toJson(),
      warmComponents: warm.tokenBreakdown?.toJson(),
      coldPromptTokens: (coldStats['prompt_tokens'] as num?)?.toInt() ?? 0,
      coldPromptEvalMs: (coldStats['prompt_eval_ms'] as num?)?.toInt() ?? 0,
      warmPromptTokens: (warmStats['prompt_tokens'] as num?)?.toInt() ?? 0,
      warmPromptEvalMs: (warmStats['prompt_eval_ms'] as num?)?.toInt() ?? 0,
      coldEvaluatedPromptTokens:
          requiredCounter(coldStats, 'evaluated_prompt_tokens'),
      warmEvaluatedPromptTokens:
          requiredCounter(warmStats, 'evaluated_prompt_tokens'),
      coldReusedPromptTokens:
          requiredCounter(coldStats, 'reused_prompt_tokens'),
      warmReusedPromptTokens:
          requiredCounter(warmStats, 'reused_prompt_tokens'),
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
  /// Complete input size, including the cached prefix (unchanged semantics).
  final bool promptsDiffer;
  final double? coldFirstTokenMs, warmFirstTokenMs;
  final Map<String, int>? coldComponents, warmComponents;
  final int coldPromptTokens;
  final int coldPromptEvalMs;
  final int warmPromptTokens;
  final int warmPromptEvalMs;
  final int coldEvaluatedPromptTokens;
  final int warmEvaluatedPromptTokens;
  final int coldReusedPromptTokens;
  final int warmReusedPromptTokens;

  const PrefixCacheBenchmark({
    this.promptsDiffer = false,
    this.coldFirstTokenMs,
    this.warmFirstTokenMs,
    this.coldComponents,
    this.warmComponents,
    required this.coldPromptTokens,
    required this.coldPromptEvalMs,
    required this.warmPromptTokens,
    required this.warmPromptEvalMs,
    this.coldEvaluatedPromptTokens = 0,
    this.warmEvaluatedPromptTokens = 0,
    this.coldReusedPromptTokens = 0,
    this.warmReusedPromptTokens = 0,
  });

  /// Percentage reduction in prompt tokens decoded on the warm turn.
  double get tokenReductionPercent {
    if (coldEvaluatedPromptTokens == 0) return 0.0;
    return 100.0 *
        (coldEvaluatedPromptTokens - warmEvaluatedPromptTokens) /
        coldEvaluatedPromptTokens;
  }

  Map<String, Object?> toJson() => {
        'comparison': 'changing_next_turn',
        'prompts_differ': promptsDiffer,
        'cold_first_token_ms': coldFirstTokenMs,
        'next_turn_first_token_ms': warmFirstTokenMs,
        'cold_components': coldComponents,
        'next_turn_components': warmComponents,
        'cold_prompt_tokens': coldPromptTokens,
        'cold_prompt_eval_ms': coldPromptEvalMs,
        'warm_prompt_tokens': warmPromptTokens,
        'warm_prompt_eval_ms': warmPromptEvalMs,
        'cold_evaluated_prompt_tokens': coldEvaluatedPromptTokens,
        'warm_evaluated_prompt_tokens': warmEvaluatedPromptTokens,
        'cold_reused_prompt_tokens': coldReusedPromptTokens,
        'warm_reused_prompt_tokens': warmReusedPromptTokens,
        'token_reduction_percent': tokenReductionPercent,
      };
}

class HarnessResult {
  final core.PromptTokenBreakdown? tokenBreakdown;
  final double? firstTokenMs;
  final String prompt;
  final String rawResponse;
  final core.SimState nextState;
  final List<StructuredDelta> deltas;

  const HarnessResult({
    this.tokenBreakdown,
    this.firstTokenMs,
    required this.prompt,
    required this.rawResponse,
    required this.nextState,
    required this.deltas,
  });
}
