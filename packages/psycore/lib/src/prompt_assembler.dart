import 'package:psychemas/psychemas.dart';

import 'chat_template.dart';
import 'conversation_turn.dart';
import 'roleplay_frame.dart';
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

  /// The versioned roleplay frame (instruction preamble + few-shot exemplars).
  /// Defaults to [NoRoleplayFrame] so the pure core stays testable at tiny
  /// token budgets; the app injects [PatientRoleplayFrame].
  final RoleplayFrame roleplayFrame;

  const PromptAssembler({
    required this.tokenCounter,
    required this.chatTemplate,
    this.roleplayFrame = const NoRoleplayFrame(),
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
    final exemplars = roleplayFrame.exemplars();
    final t1 = _buildTier1(rulesetVersion, manifest, state);
    final t1Rendered = chatTemplate.render(systemFrame: t1, turns: const []);
    final t1Tokens = tokenCounter.count(t1Rendered);

    // Exemplars are fixed roleplay-frame content, not truncatable window turns,
    // so they are reserved out of the budget alongside T1.
    final exemplarTokens =
        exemplars.isEmpty ? 0 : _renderedTier2Tokens(t1, exemplars);

    if (t1Tokens + exemplarTokens + outputReserve > inputBudget) {
      throw const PromptAssemblyException(
        PromptAssemblyError.tier1Overflow,
        'Tier 1 (frame + exemplars) + output reserve exceeds input budget',
      );
    }

    final t2Budget = inputBudget - t1Tokens - exemplarTokens - outputReserve;
    final t2 = _buildTier2(t1, conversationWindow, state, budget: t2Budget);

    return chatTemplate.render(
      systemFrame: t1,
      turns: [...exemplars, ...t2.turns],
    );
  }

  /// Builds the immutable Tier-1 prefix.
  ///
  /// Field ordering is deterministic so the same manifest + ruleset always
  /// produces the same bytes, enabling KV-cache prefix reuse. The machine pin
  /// block (ruleset/case/archetype/clue markers) is kept for reproducibility
  /// and injection-isolation; the versioned roleplay instruction that turns the
  /// model into an *actor* is appended after it.
  String _buildTier1(
    String rulesetVersion,
    PatientManifest manifest,
    SimState state,
  ) {
    final buffer = StringBuffer()
      ..writeln('ruleset_version=$rulesetVersion')
      ..writeln('case_id=${manifest.id}')
      ..writeln('style_archetype=${manifest.styleArchetype.name}')
      ..writeln('clue_tokens=${manifest.clueTokens.join(", ")}')
      ..writeln(manifest.modelFacingTemplate);
    final instruction =
        roleplayFrame.instruction(manifest: manifest, state: state);
    if (instruction.isNotEmpty) {
      buffer
        ..writeln()
        ..writeln(instruction);
    }
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
    // Start with the full conversation window. A history digest is only added
    // once the session has advanced past the opening turn; on turn 0 the
    // roleplay frame's current-feeling line already conveys the state.
    final turns = List<ConversationTurn>.of(conversationWindow);
    if (state.turn > 0) {
      turns.add(ConversationTurn(
        role: 'system',
        text: _buildHistoryDigest(state),
      ));
    }

    // Drop oldest turns until the rendered T2 fits the budget.
    while (turns.isNotEmpty &&
        _renderedTier2Tokens(t1, turns) > budget &&
        turns.length > 1) {
      turns.removeAt(0);
    }

    // If even a single remaining turn is over budget, drop it entirely.
    if (turns.isNotEmpty && _renderedTier2Tokens(t1, turns) > budget) {
      turns.clear();
    }

    return _Tier2(turns: turns);
  }

  int _renderedTier2Tokens(String t1, List<ConversationTurn> turns) {
    final rendered = chatTemplate.render(systemFrame: t1, turns: turns);
    return tokenCounter.count(rendered) - tokenCounter.count(t1);
  }

  /// Builds a deterministic, natural-language summary of prior state.
  ///
  /// Emitted as plain prose (never `HISTORY_DIGEST`/`axis=value`) so the model
  /// reads it as scene context to voice, not a data table to analyse.
  String _buildHistoryDigest(SimState state) {
    final agitation = state.axes['agitation'];
    final resistance = state.axes['resistance'];
    final trust = state.axes['trust'];
    final parts = <String>[];
    if (agitation != null) parts.add('${_axisWord(agitation)} agitated');
    if (resistance != null) parts.add('${_axisWord(resistance)} guarded');
    if (trust != null) parts.add('${_axisWord(trust)} trusting');
    final summary = parts.isEmpty ? 'unsettled' : parts.join(', ');
    return 'So far this session you have felt $summary.';
  }

  static String _axisWord(int value) {
    if (value <= 25) return 'only slightly';
    if (value <= 60) return 'moderately';
    return 'very';
  }
}

class _Tier2 {
  final List<ConversationTurn> turns;

  const _Tier2({required this.turns});
}
