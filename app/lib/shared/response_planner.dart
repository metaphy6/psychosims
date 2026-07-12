import 'dialogue_sanitizer.dart';

/// Result of the response planning step.
class PlannedResponse {
  final String dialogue;
  final bool usedFallback;
  final bool wasRefusal;

  const PlannedResponse({
    required this.dialogue,
    required this.usedFallback,
    required this.wasRefusal,
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
    required String fallback,
    required List<String> requiredClueTokens,
    String? systemFrame,
    List<String>? clueTokens,
  }) async {
    for (var attempt = 0; attempt <= maxRetries; attempt++) {
      final raw = await generate();
      final sanitized = sanitizer.sanitize(
        raw,
        systemFrame: systemFrame,
        clueTokens: clueTokens,
      );

      if (sanitizer.looksLikeRefusal(sanitized)) {
        continue;
      }

      if (requiredClueTokens.isNotEmpty &&
          !sanitizer.hasRequiredClueTokens(sanitized, requiredClueTokens)) {
        continue;
      }

      return PlannedResponse(
        dialogue: sanitized,
        usedFallback: false,
        wasRefusal: false,
      );
    }

    return PlannedResponse(
      dialogue: fallback,
      usedFallback: true,
      wasRefusal: false,
    );
  }
}
