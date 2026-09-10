import 'package:psycore/psycore.dart' as core;
import 'package:psyconfig/psyconfig.dart';

import 'dialogue_sanitizer.dart';

/// Result of the response planning step.
class PlannedResponse {
  final String dialogue;
  final bool usedFallback;
  final bool wasRefusal;
  final int attemptCount;

  const PlannedResponse({
    required this.dialogue,
    required this.usedFallback,
    required this.wasRefusal,
    this.attemptCount = 1,
  });
}

/// Orchestrates model generation with bounded regeneration and a deterministic
/// templated fallback.
///
/// The planner is the dialogue-layer counterpart to the deterministic core:
/// it does not change mechanical state, but it decides what text is shown to
/// the player. It keeps model interaction behind the provided [generate]
/// callback so it never imports the FFI layer directly.
class ResponsePlanner {
  final DialogueSanitizer sanitizer;
  final int maxRetries;

  const ResponsePlanner({
    this.sanitizer = const DialogueSanitizer(),
    this.maxRetries = 2,
  });

  ResponsePlanner.fromConfig(PromptBudgetConfig config)
      : this(maxRetries: config.maxRegenerationRetries);

  /// Plans the response for a turn.
  ///
  /// [generate] is a callback that runs model inference and returns raw text.
  /// [requiredClueTokens] are the manifest's mandatory clues. [fallback]
  /// is the deterministic templated line used when the model misses clues or
  /// emits a refusal.
  ///
  /// [systemFrame] and [clueTokens] are passed to the sanitizer so echoed frame
  /// text and control markers never reach the UI.
  Future<PlannedResponse> plan({
    required Future<String> Function() generate,
    Future<String> Function(core.PromptCorrection reason, int attempt)?
        regenerate,
    required String fallback,
    required List<String> requiredClueTokens,
    String? systemFrame,
    List<String>? clueTokens,
  }) async {
    if (maxRetries < 0 || maxRetries > 2) {
      throw ArgumentError.value(maxRetries, 'maxRetries', 'must be 0..2');
    }
    var wasRefusal = false;
    var attemptCount = 0;
    var correction = core.PromptCorrection.missingClues;
    for (var attempt = 0; attempt <= maxRetries; attempt++) {
      late String raw;
      if (attempt == 0 || regenerate == null) {
        raw = await generate();
      } else {
        try {
          raw = await regenerate(correction, attempt);
        } on core.PromptAssemblyException catch (error) {
          // Only an unavailable correction budget selects fallback. Initial
          // assembly, inference and cancellation failures still propagate.
          if (error.kind != core.PromptAssemblyError.tier1Overflow) rethrow;
          break;
        }
      }
      attemptCount++;
      final rawQuality = sanitizer.qualityChecks(raw, requiredClueTokens);
      final content = sanitizer.sanitize(raw, systemFrame: systemFrame);
      final sanitized = sanitizer.sanitize(
        content,
        systemFrame: systemFrame,
        clueTokens: clueTokens,
      );

      if (sanitizer.looksLikeRefusal(sanitized)) {
        wasRefusal = true;
        correction = core.PromptCorrection.refusal;
        continue;
      }

      if (requiredClueTokens.isNotEmpty &&
          !sanitizer.hasRequiredClueTokens(content, requiredClueTokens)) {
        correction = core.PromptCorrection.missingClues;
        continue;
      }

      if (!rawQuality.values.every((pass) => pass)) {
        correction = core.PromptCorrection.invalidDialogue;
        continue;
      }

      return PlannedResponse(
        dialogue: sanitized,
        usedFallback: false,
        wasRefusal: false,
        attemptCount: attemptCount,
      );
    }

    return PlannedResponse(
      dialogue: sanitizer.sanitize(fallback,
          systemFrame: systemFrame, clueTokens: clueTokens),
      usedFallback: true,
      wasRefusal: wasRefusal,
      attemptCount: attemptCount,
    );
  }
}
