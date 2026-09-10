/// Sanitizes and validates model-generated dialogue before it reaches the UI.
///
/// This is the client-side half of the core/dialogue split. The deterministic
/// core owns mechanics; this layer ensures model output is safe to display and
/// honours the clue-token contract.
class DialogueSanitizer {
  const DialogueSanitizer();

  /// Strips echoed system-frame text and clue-token control markers.
  String sanitize(String output,
      {String? systemFrame, List<String>? clueTokens}) {
    var cleaned = output.trim();

    if (systemFrame != null && systemFrame.isNotEmpty) {
      cleaned = cleaned.replaceAll(systemFrame, '');
    }

    for (final token in clueTokens ?? const <String>[]) {
      cleaned = cleaned.replaceAll(
          RegExp(r'\[' + RegExp.escape(token) + r'\]|' + RegExp.escape(token),
              caseSensitive: false),
          '');
    }

    // Collapse multiple whitespace.
    cleaned = cleaned.replaceAll(RegExp(r'\s+'), ' ').trim();

    return cleaned;
  }

  /// Returns true if the output appears to be empty, a refusal, or a canned
  /// safety disclaimer rather than in-character dialogue.
  bool looksLikeRefusal(String output) {
    final lower = output.toLowerCase().trim();
    if (lower.isEmpty) return true;

    final refusalMarkers = [
      'i cannot',
      "i can't",
      'i am not able',
      "i'm not able",
      'i will not',
      "i won't",
      'as an ai',
      'as a language model',
      'i do not feel comfortable',
      'i cannot provide',
      'this request is against',
      'i apologize, but',
    ];

    return refusalMarkers.any((marker) => lower.startsWith(marker));
  }

  /// Shared production/measurement quality contract. Raw failures are checked
  /// before control markers are removed; fallback never earns a model pass.
  Map<String, bool> qualityChecks(String output, List<String> clues) {
    final normalized =
        output.toLowerCase().replaceAll(RegExp(r'\s+'), ' ').trim();
    return {
      'first_person': RegExp(r"\b(i|i'm|i've|i'd|i'll|me|my|myself)\b")
          .hasMatch(normalized),
      'no_frame_leak': !RegExp(
              r'\b[a-z_]+=[a-z0-9]|ruleset_version|case_id|clue_tokens|history_digest|correction [12]:|end with exactly:')
          .hasMatch(normalized),
      'no_list': !RegExp(r'\b\d+[.)]\s').hasMatch(output) &&
          !RegExp(r'^\s*[-*+•]\s+', multiLine: true).hasMatch(output),
      'no_advice': ![
        'consult',
        'seek professional',
        'healthcare provider',
        'treatment plan',
        'sedation'
      ].any(normalized.contains),
      'brief': output.isNotEmpty && output.length <= 600,
      'clues': hasRequiredClueTokens(output, clues),
      'not_refusal': !looksLikeRefusal(output),
    };
  }

  /// Returns true if every required clue token appears in the raw output.
  bool hasRequiredClueTokens(String output, List<String> clueTokens) {
    final lower = output.toLowerCase();
    return clueTokens.every((token) => lower.contains(token.toLowerCase()));
  }
}
