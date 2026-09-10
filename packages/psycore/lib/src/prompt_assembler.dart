import 'package:psychemas/psychemas.dart';

import 'chat_template.dart';
import 'conversation_turn.dart';
import 'multi_session_digest_compiler.dart';
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
    CaseHistoryEnvelope? historyEnvelope,
    ClinicalEncyclopedia encyclopedia = ClinicalEncyclopedia.empty,
    PromptCorrection? correction,
    int correctionAttempt = 1,
  }) =>
      assembleDetailed(
              rulesetVersion: rulesetVersion,
              manifest: manifest,
              state: state,
              conversationWindow: conversationWindow,
              inputBudget: inputBudget,
              outputReserve: outputReserve,
              historyEnvelope: historyEnvelope,
              encyclopedia: encyclopedia,
              correction: correction,
              correctionAttempt: correctionAttempt)
          .prompt;

  /// Measures net component costs using the real, fully rendered template.
  /// The final render is checked as a whole, including chat-template overhead.
  AssembledPrompt assembleDetailed({
    required String rulesetVersion,
    required PatientManifest manifest,
    required SimState state,
    required List<ConversationTurn> conversationWindow,
    required int inputBudget,
    required int outputReserve,
    CaseHistoryEnvelope? historyEnvelope,
    ClinicalEncyclopedia encyclopedia = ClinicalEncyclopedia.empty,
    PromptCorrection? correction,
    int correctionAttempt = 1,
  }) {
    if (inputBudget < 1 ||
        outputReserve < 0 ||
        correctionAttempt < 1 ||
        correctionAttempt > 2) {
      throw ArgumentError('Invalid prompt budget or correction attempt');
    }
    final t1 = _buildTier1(rulesetVersion, manifest, state);
    final examples = roleplayFrame.examplesFor(manifest);
    final window = List<ConversationTurn>.of(conversationWindow);
    final scene = <ConversationTurn>[];
    final sceneText =
        state.turn > 0 || (historyEnvelope?.priorSessionCount ?? 0) > 0
            ? _buildHistoryDigest(state,
                historyEnvelope: historyEnvelope, encyclopedia: encyclopedia)
            : roleplayFrame.scene(state);
    if (sceneText.isNotEmpty)
      scene.add(ConversationTurn(role: 'system', text: sceneText));
    final corrections = <ConversationTurn>[];
    if (correction != null) {
      final reason = switch (correction) {
        PromptCorrection.missingClues =>
          'The previous reply missed required clue markers.',
        PromptCorrection.refusal =>
          'The previous reply broke character. Voice only your own feelings as the fictional patient, without advice or refusal.',
        PromptCorrection.invalidDialogue =>
          'The previous reply did not follow the dialogue format. Use one or two short first-person sentences, without analysis, advice, lists, headings or metadata.',
      };
      final markers = manifest.clueTokens.map((clue) => '[$clue]').join(' ');
      corrections.add(ConversationTurn(
          role: 'system',
          text:
              'Correction $correctionAttempt: $reason Write a fresh first-person reply.${markers.isEmpty ? '' : ' End with exactly: $markers'}'));
    }
    String render(List<ConversationTurn> turns) =>
        chatTemplate.render(systemFrame: t1, turns: turns);
    int count(List<ConversationTurn> turns) =>
        tokenCounter.count(render(turns));
    final limit = inputBudget - outputReserve;
    if (count([...examples, ...corrections]) > limit) {
      throw const PromptAssemblyException(PromptAssemblyError.tier1Overflow,
          'Frame, exemplars, correction and output reserve exceed input budget');
    }
    while (window.isNotEmpty &&
        count([...examples, ...window, ...scene, ...corrections]) > limit) {
      window.removeAt(0);
    }
    if (count([...examples, ...scene, ...corrections]) > limit) scene.clear();
    final baseTokens = count(const []);
    final exampleTokens = count(examples);
    final windowTokens = count([...examples, ...window]);
    final sceneTokens = count([...examples, ...window, ...scene]);
    final turns = [...examples, ...window, ...scene, ...corrections];
    final prompt = render(turns);
    final total = tokenCounter.count(prompt);
    return AssembledPrompt(
        prompt: prompt,
        stablePrefix: t1,
        tokens: PromptTokenBreakdown(
            frame: baseTokens,
            examples: exampleTokens - baseTokens,
            window: windowTokens - exampleTokens,
            scene: sceneTokens - windowTokens,
            correction: total - sceneTokens,
            outputReserve: outputReserve));
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
      ..writeln('clue_tokens=${manifest.clueTokens.join(", ")}');
    final instruction =
        roleplayFrame.stableInstruction(manifest: manifest, state: state);
    if (instruction.isEmpty) {
      buffer.writeln(manifest.modelFacingTemplate);
    } else {
      buffer
        ..writeln()
        ..writeln(instruction);
    }
    return buffer.toString().trim();
  }

  /// Builds a deterministic, natural-language summary of prior state.
  ///
  /// Emitted as plain prose (never `HISTORY_DIGEST`/`axis=value`) so the model
  /// reads it as scene context to voice, not a data table to analyse.
  String _buildHistoryDigest(
    SimState state, {
    CaseHistoryEnvelope? historyEnvelope,
    ClinicalEncyclopedia encyclopedia = ClinicalEncyclopedia.empty,
  }) {
    if (historyEnvelope != null && historyEnvelope.priorSessionCount > 0) {
      return const MultiSessionDigestCompiler().compile(
        envelope: historyEnvelope,
        state: state,
        encyclopedia: encyclopedia,
      );
    }
    final parts = <String>[
      '${_axisWord(state.agitationLevel)} agitated',
      '${_axisWord(state.resistance)} guarded',
      '${_axisWord(state.trustScore)} trusting',
    ];
    final summary = parts.join(', ');
    return 'So far this session you have felt $summary.';
  }

  static String _axisWord(int value) {
    if (value <= 25) return 'only slightly';
    if (value <= 60) return 'moderately';
    return 'very';
  }
}

/// Trusted retry reasons; generated text never becomes an instruction.
enum PromptCorrection { missingClues, refusal, invalidDialogue }

class AssembledPrompt {
  final String prompt;
  final String stablePrefix;
  final PromptTokenBreakdown tokens;
  const AssembledPrompt(
      {required this.prompt, required this.stablePrefix, required this.tokens});
}

/// Net additions to rendered input size. Costs sum exactly to [total].
class PromptTokenBreakdown {
  final int frame, examples, window, scene, correction, outputReserve;
  const PromptTokenBreakdown(
      {required this.frame,
      required this.examples,
      required this.window,
      required this.scene,
      required this.correction,
      required this.outputReserve});
  int get total => frame + examples + window + scene + correction;
  Map<String, int> toJson() => {
        'frame': frame,
        'examples': examples,
        'window': window,
        'scene': scene,
        'correction': correction,
        'input_total': total,
        'output_reserve': outputReserve
      };
}
