/// Abstraction over the active model's tokenizer.
///
/// The real implementation (Phase 1.1) calls llama.cpp through the inference
/// service. Tests use deterministic mock counters so budget logic can be
/// verified without loading a model.
abstract class TokenCounter {
  const TokenCounter();

  /// Returns the token count for [text].
  int count(String text);
}

/// Whitespace-based mock counter for unit tests.
class WhitespaceTokenCounter implements TokenCounter {
  const WhitespaceTokenCounter();

  @override
  int count(String text) {
    return text.trim().isEmpty ? 0 : text.trim().split(RegExp(r'\s+')).length;
  }
}
