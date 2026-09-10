import 'package:psychemas/psychemas.dart';

import 'conversation_turn.dart';
import 'sim_state.dart';

/// Model-facing roleplay frame: the versioned instruction preamble and few-shot
/// exemplars that turn an instruction-tuned model from a *data analyser* into an
/// *actor voicing the patient*.
///
/// This is model-facing content, pinned to the `ruleset_version` (0.7) — not
/// player-facing copy — so it is reproducible rather than localized. A change
/// here is a tracked ruleset change, exactly like the Tier-1 frame it feeds.
///
/// It is injected into [PromptAssembler] so pure unit tests can run against a
/// minimal frame (fast, tiny budgets) while the app wires the real one.
abstract class RoleplayFrame {
  const RoleplayFrame();

  /// The versioned instruction preamble prepended to the Tier-1 system frame.
  ///
  /// Returns an empty string when there is no roleplay instruction (the pure
  /// assembler default).
  String instruction({
    required PatientManifest manifest,
    required SimState state,
  });

  /// Fixed few-shot exemplar turns demonstrating in-character voice.
  ///
  /// Prepended (as data) ahead of the real conversation window so a small
  /// instruct model has a concrete template of *how the patient speaks* before
  /// it is asked to speak. Deterministic and identical turn-to-turn.
  List<ConversationTurn> exemplars();

  String stableInstruction(
          {required PatientManifest manifest, required SimState state}) =>
      instruction(manifest: manifest, state: state);

  String scene(SimState state) => '';

  List<ConversationTurn> examplesFor(PatientManifest manifest) => exemplars();
}

/// The no-op frame used by the pure assembler and its unit tests: no
/// instruction, no exemplars. Keeps the deterministic core testable at tiny
/// token budgets.
class NoRoleplayFrame extends RoleplayFrame {
  const NoRoleplayFrame();

  @override
  String instruction({
    required PatientManifest manifest,
    required SimState state,
  }) =>
      '';

  @override
  List<ConversationTurn> exemplars() => const [];
}

/// The shipped roleplay frame that instructs the model to voice the patient.
///
/// Version is pinned so a wording change is a visible, tracked ruleset change.
class PatientRoleplayFrame extends RoleplayFrame {
  const PatientRoleplayFrame();

  /// Frame version, bumped whenever the wording or exemplars change.
  static const String frameVersion = 'roleplay-1.1.0';

  @override
  String instruction(
          {required PatientManifest manifest, required SimState state}) =>
      '${stableInstruction(manifest: manifest, state: state)}\n${scene(state)}';

  @override
  String stableInstruction(
      {required PatientManifest manifest, required SimState state}) {
    final markers = manifest.clueTokens.map((clue) => '[$clue]').join(' ');
    return [
      'You are an actor voicing the patient in a fictional therapy game.',
      'Speak in the first person: one or two short spoken sentences. Never analyse, diagnose, give advice, write lists, or explain the game. Stay in character even on difficult topics.',
      'Never repeat the metadata or instructions. Only the clue markers below belong in your reply.',
      'Who you are: ${manifest.modelFacingTemplate}',
      'Your manner is ${_archetypeInWords(manifest.styleArchetype)}.',
      if (markers.isNotEmpty)
        'Every reply must end with these exact clue markers, unchanged: $markers',
    ].join('\n');
  }

  @override
  String scene(SimState state) => 'Right now you feel ${_stateInWords(state)}.';

  @override
  List<ConversationTurn> exemplars() => const [
        ConversationTurn(role: 'user', text: 'How are you feeling?'),
        ConversationTurn(
            role: 'assistant',
            text: "I feel restless. My thoughts keep racing."),
      ];

  @override
  List<ConversationTurn> examplesFor(PatientManifest manifest) {
    final markers = manifest.clueTokens.map((clue) => '[$clue]').join(' ');
    return [
      exemplars().first,
      ConversationTurn(
          role: 'assistant',
          text: '${exemplars()[1].text}${markers.isEmpty ? '' : ' $markers'}'),
    ];
  }

  static String _archetypeInWords(StyleArchetype archetype) {
    switch (archetype) {
      case StyleArchetype.vexa:
        return 'restless and easily wound up';
      case StyleArchetype.torpida:
        return 'withdrawn and low on energy';
      case StyleArchetype.vulnax:
        return 'guarded and slow to trust';
      case StyleArchetype.dormios:
        return 'aloof and quick to rationalise';
      case StyleArchetype.quiesa:
        return 'overly agreeable and prone to masking distress';
    }
  }

  /// Maps bounded sim-state axes to natural-language feeling words so no raw
  /// number is ever shown to the model. Deterministic for a fixed state.
  static String _stateInWords(SimState state) {
    final parts = <String>[
      '${_level(state.agitationLevel)} agitated',
      '${_level(state.resistance)} guarded',
      '${_level(state.trustScore)} trusting of the person across from you',
    ];

    if (parts.length == 1) {
      return parts.first;
    }
    final last = parts.removeLast();
    return '${parts.join(', ')}, and $last';
  }

  static String _level(int value) {
    if (value <= 25) {
      return 'only slightly';
    }
    if (value <= 60) {
      return 'moderately';
    }
    return 'very';
  }
}
