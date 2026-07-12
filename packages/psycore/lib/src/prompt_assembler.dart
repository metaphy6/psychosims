import 'package:psychemas/psychemas.dart';

import 'chat_template.dart';
import 'conversation_turn.dart';
import 'sim_state.dart';
import 'token_counter.dart';

/// Failure modes for prompt assembly.
enum PromptAssemblyError {
  /// Tier 1 alone exceeds the input budget: a manifest-schema defect.
  tier1Overflow,
}

/// Exception thrown when a prompt cannot be assembled within budget.
class PromptAssemblyException implements Exception {
  final PromptAssemblyError kind;
  final String message;

  const PromptAssemblyException(this.kind, this.message);

  @override
  String toString() => 'PromptAssemblyException(${kind.name}): $message';
}

/// Pure, deterministic prompt assembler.
///
/// Implements the C-7 tiered structure:
///   * Tier 1: system frame, manifest model-facing template, clue tokens — never
///     truncated.
///   * Tier 2: conversation window + history digest — truncated if needed.
///   * Tier 3: generation reserve — reserved tokens, never content.
///
/// The function is pure: it does no I/O, uses no wall-clock, and mutates none
/// of its inputs.
class PromptAssembler {
  final TokenCounter tokenCounter;
  final ChatTemplate chatTemplate;

  const PromptAssembler({
    required this.tokenCounter,
    required this.chatTemplate,
  });

  /// Assembles the prompt for one turn.
  ///
  /// [inputBudget] is the maximum input tokens allowed. [outputReserve] is the
  /// number of tokens reserved for the model's response.
  String assemble({
    required String rulesetVersion,
    required PatientManifest manifest,
    required SimState state,
    required List<ConversationTurn> conversationWindow,
    required int inputBudget,
    required int outputReserve,
  }) {
    final t1 = _buildTier1(rulesetVersion, manifest);
    final t1Rendered = chatTemplate.render(systemFrame: t1, turns: const []);
    final t1Tokens = tokenCounter.count(t1Rendered);

    if (t1Tokens + outputReserve > inputBudget) {
      throw const PromptAssemblyException(
        PromptAssemblyError.tier1Overflow,
        'Tier 1 + output reserve exceeds input budget',
      );
    }

    final t2Budget = inputBudget - t1Tokens - outputReserve;
    final t2 = _buildTier2(t1, conversationWindow, state, budget: t2Budget);

    return chatTemplate.render(
      systemFrame: t1,
      turns: t2.turns,
    );
  }

  /// Builds the immutable Tier-1 prefix.
  ///
  /// Field ordering is deterministic so the same manifest + ruleset always
  /// produces the same bytes, enabling KV-cache prefix reuse.
  String _buildTier1(String rulesetVersion, PatientManifest manifest) {
    final buffer = StringBuffer()
      ..writeln('ruleset_version=$rulesetVersion')
      ..writeln('case_id=${manifest.id}')
      ..writeln('style_archetype=${manifest.styleArchetype.name}')
      ..writeln('clue_tokens=${manifest.clueTokens.join(", ")}')
      ..writeln(manifest.modelFacingTemplate);
    return buffer.toString().trim();
  }

  /// Builds Tier-2 content within [budget] tokens.
  ///
  /// Truncation order: conversation window → history digest. T1 and the output
  /// reserve are never touched.
  ///
  /// Token counts are measured on the rendered prompt so template overhead is
  /// included in the budget.
  _Tier2 _buildTier2(
    String t1,
    List<ConversationTurn> conversationWindow,
    SimState state, {
    required int budget,
  }) {
    final digest = ConversationTurn(
      role: 'system',
      text: _buildHistoryDigest(state),
    );

    // Start with the full conversation window plus digest.
    final turns = List<ConversationTurn>.of(conversationWindow)..add(digest);

    // Drop oldest turns until the rendered T2 fits the budget.
    while (turns.isNotEmpty &&
        _renderedTier2Tokens(t1, turns) > budget &&
        turns.length > 1) {
      turns.removeAt(0);
    }

    // If even the digest alone is over budget, drop it entirely.
    if (turns.isNotEmpty && _renderedTier2Tokens(t1, turns) > budget) {
      turns.clear();
    }

    return _Tier2(turns: turns);
  }

  int _renderedTier2Tokens(String t1, List<ConversationTurn> turns) {
    final rendered = chatTemplate.render(systemFrame: t1, turns: turns);
    return tokenCounter.count(rendered) - tokenCounter.count(t1);
  }

  /// Builds a deterministic, fixed-token structured summary of prior state.
  String _buildHistoryDigest(SimState state) {
    final sortedAxes = state.axes.entries.toList()
      ..sort((a, b) => a.key.compareTo(b.key));
    final axisSummary = sortedAxes.map((e) => '${e.key}=${e.value}').join(' ');
    return 'HISTORY_DIGEST turn=${state.turn} $axisSummary';
  }
}

class _Tier2 {
  final List<ConversationTurn> turns;

  const _Tier2({required this.turns});
}
