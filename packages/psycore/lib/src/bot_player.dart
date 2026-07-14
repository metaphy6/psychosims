import 'package:psychemas/psychemas.dart';

import 'sim_state.dart';

/// Bot skill level for sandbox runs (§2.2 / §11 mechanical-solvability baseline).
enum BotSkill {
  /// Plays randomly among legal cards.
  novice,

  /// Picks an aligned signature when the state clearly calls for it, otherwise
  /// plays a safe buffer.
  intermediate,

  /// Near-optimal heuristic: reads state and selects the card most likely to
  /// advance progress while avoiding crisis.
  expert,
}

extension BotSkillJson on BotSkill {
  String toJson() => name;
  static BotSkill fromJson(String value) => BotSkill.values.byName(value);
}

/// A deterministic bot policy that chooses the next card from a loadout.
///
/// Bots are the mechanical-solvability actors in the 2.8 balance sandbox. They
/// have no model access and no free text; they select only from the equipped
/// loadout, keeping the core-only run path free of inference and I/O.
class BotPlayer {
  final BotSkill skill;
  final String id;

  const BotPlayer({required this.id, required this.skill});

  /// Chooses the next [InteractionPattern] given [state] and [loadout].
  ///
  /// [library] is unused by the bot itself (the core enforces ownership), but
  /// kept in the signature for symmetry with the resolver input.
  InteractionPattern chooseAction({
    required SimState state,
    required Loadout loadout,
    required CardLibrary library,
    required List<InteractionPattern> available,
  }) {
    final legal = available
        .where((a) => loadout.contains(cardFromInteractionPattern(a).id))
        .toList();
    if (legal.isEmpty) {
      throw StateError('Bot $id has no legal action from loadout');
    }

    return switch (skill) {
      BotSkill.novice => legal.first,
      BotSkill.intermediate => _intermediateChoice(state, legal),
      BotSkill.expert => _expertChoice(state, legal),
    };
  }

  InteractionPattern _intermediateChoice(
    SimState state,
    List<InteractionPattern> legal,
  ) {
    // Aligned choices when obvious; otherwise default to a safe card.
    if (state.agitationLevel >= 55) {
      final postpone = _findType(legal, CardType.postponing);
      if (postpone != null) return postpone;
    }
    if (state.trustScore >= 60) {
      final manipulative = _findType(legal, CardType.manipulative);
      if (manipulative != null) return manipulative;
    }
    final relatable = _findType(legal, CardType.relatable);
    if (relatable != null) return relatable;
    return legal.first;
  }

  InteractionPattern _expertChoice(
    SimState state,
    List<InteractionPattern> legal,
  ) {
    // Crisis avoidance first.
    if (state.agitationLevel >= 65 || state.trauma >= 65) {
      final postpone = _findType(legal, CardType.postponing);
      if (postpone != null) return postpone;
    }

    // If trust is high enough for manipulative to be safe and progress is
    // stalled, gamble.
    if (state.trustScore >= 70 && state.sessionProgress >= 60) {
      final manipulative = _findType(legal, CardType.manipulative);
      if (manipulative != null) return manipulative;
    }

    // Build trust with relatable when rapport is low.
    if (state.trustScore < 50) {
      final relatable = _findType(legal, CardType.relatable);
      if (relatable != null) return relatable;
    }

    // Crack defenses with disclosing when resistance/agitation block progress.
    if (state.resistance >= 35 || state.agitationLevel >= 45) {
      final disclosing = _findType(legal, CardType.disclosing);
      if (disclosing != null) return disclosing;
    }

    // Fallback: relatable > postpone > disclosing > manipulative.
    return _findType(legal, CardType.relatable) ??
        _findType(legal, CardType.postponing) ??
        _findType(legal, CardType.disclosing) ??
        _findType(legal, CardType.manipulative) ??
        legal.first;
  }

  InteractionPattern? _findType(
    List<InteractionPattern> patterns,
    CardType type,
  ) {
    for (final pattern in patterns) {
      if (cardFromInteractionPattern(pattern).type == type) return pattern;
    }
    return null;
  }
}
