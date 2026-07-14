import 'canonical_json.dart';
import 'interaction_pattern.dart';

/// Back-maps a PoC [InteractionPattern] to a production [Card] instance.
///
/// This keeps PoC manifests loadable under the new card taxonomy (0.8
/// wire-compat). New content should declare cards explicitly.
Card cardFromInteractionPattern(InteractionPattern pattern) {
  switch (pattern) {
    case InteractionPattern.openQuestion:
      return const Card(
        id: 'open_question',
        type: CardType.disclosing,
        signature: CardSignature.breaker,
        nameKey: 'card.open_question.name',
        modelFacingHint: 'open_ended_exploration',
      );
    case InteractionPattern.validate:
      return const Card(
        id: 'validate',
        type: CardType.relatable,
        signature: CardSignature.buffer,
        nameKey: 'card.validate.name',
        modelFacingHint: 'rapport_validation',
      );
    case InteractionPattern.reframe:
      return const Card(
        id: 'reframe',
        type: CardType.manipulative,
        signature: CardSignature.gambit,
        nameKey: 'card.reframe.name',
        modelFacingHint: 'cognitive_reframe',
      );
    case InteractionPattern.setBoundary:
      return const Card(
        id: 'set_boundary',
        type: CardType.postponing,
        signature: CardSignature.freeze,
        nameKey: 'card.set_boundary.name',
        modelFacingHint: 'containment_boundary',
      );
    case InteractionPattern.reflect:
      return const Card(
        id: 'reflect',
        type: CardType.relatable,
        signature: CardSignature.buffer,
        nameKey: 'card.reflect.name',
        modelFacingHint: 'rapport_reflection',
      );
    case InteractionPattern.discloseParallel:
      return const Card(
        id: 'disclose_parallel',
        type: CardType.disclosing,
        signature: CardSignature.breaker,
        nameKey: 'card.disclose_parallel.name',
        modelFacingHint: 'parallel_disclosure',
      );
  }
}

/// The four production card types (§16).
///
/// Each type defines a tactical role, not a fixed win/lose button. Numbers and
/// exact thresholds live in [C-4](BALANCE-SPEC.md); this enum owns only the
/// type identity.
enum CardType {
  /// Breakthrough tool: large agitation drop, trust gain, cracks defense.
  disclosing,

  /// Buffer / stall: small trust gain, prevents crisis.
  relatable,

  /// Tempo control: freezes state 1–2 turns; repeated use raises baseline
  /// agitation across sessions.
  postponing,

  /// High-risk gambit: three-way outcome keyed to trust state.
  manipulative,
}

extension CardTypeJson on CardType {
  String toJson() => name;
  static CardType fromJson(String value) => CardType.values.byName(value);
}

/// Signature / context-fit hint for a card (§16).
///
/// The signature tells the resolver *when* a card is aligned with the current
/// state. It is metadata, not a number.
enum CardSignature {
  /// Aligned when a truth/insight is "due" (defense crackable).
  breaker,

  /// Aligned when rapport is safe and trauma has not yet been touched.
  buffer,

  /// Aligned when crisis pressure needs to be bled off.
  freeze,

  /// Aligned when defense is too rigid for rapport and trust is high enough
  /// to gamble.
  gambit,
}

extension CardSignatureJson on CardSignature {
  String toJson() => name;
  static CardSignature fromJson(String value) =>
      CardSignature.values.byName(value);
}

/// A playable card instance in a case manifest.
///
/// Cards are core-facing tokens. Player-facing copy uses [nameKey];
/// model-facing framing uses [modelFacingHint]. This is the production card
/// model; the six PoC [InteractionPattern]s are back-mapped to card instances
/// additively (0.8 wire-compat).
class Card {
  /// Stable identifier for this card within a case.
  final String id;

  /// Tactical role.
  final CardType type;

  /// Context-fit signature.
  final CardSignature signature;

  /// Localization key for the player-facing card name.
  final String nameKey;

  /// Short model-facing framing hint used by the prompt assembler.
  ///
  /// This is a data token, not an instruction; the assembler inserts it as
  /// part of the style filter (§4 boundary).
  final String modelFacingHint;

  const Card({
    required this.id,
    required this.type,
    required this.signature,
    required this.nameKey,
    this.modelFacingHint = '',
  });

  Card copyWith({
    String? id,
    CardType? type,
    CardSignature? signature,
    String? nameKey,
    String? modelFacingHint,
  }) {
    return Card(
      id: id ?? this.id,
      type: type ?? this.type,
      signature: signature ?? this.signature,
      nameKey: nameKey ?? this.nameKey,
      modelFacingHint: modelFacingHint ?? this.modelFacingHint,
    );
  }

  Map<String, Object?> toJson() => {
        'id': id,
        'type': type.toJson(),
        'signature': signature.toJson(),
        'name_key': nameKey,
        'model_facing_hint': modelFacingHint,
      };

  factory Card.fromJson(Map<String, Object?> json) {
    return Card(
      id: json['id']! as String,
      type: CardTypeJson.fromJson(json['type']! as String),
      signature: CardSignatureJson.fromJson(json['signature']! as String),
      nameKey: json['name_key']! as String,
      modelFacingHint: (json['model_facing_hint'] ?? '') as String,
    );
  }

  List<int> toCanonicalBytes() => CanonicalJson.encode(toJson());
}
