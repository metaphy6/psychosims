import 'canonical_json.dart';

/// A player's owned/unlocked card collection.
///
/// Cards are identified by stable [Card.id] strings. Ownership is enforced in
/// the deterministic core so a receipt cannot claim a card the player does not
/// own (Phase 3.3 forgery guard).
class CardLibrary {
  final Set<String> ownedCardIds;

  const CardLibrary({required this.ownedCardIds});

  /// Empty library (e.g. fresh career).
  const CardLibrary.empty() : ownedCardIds = const {};

  bool owns(String cardId) => ownedCardIds.contains(cardId);

  CardLibrary withCard(String cardId) {
    final next = Set<String>.of(ownedCardIds);
    next.add(cardId);
    return CardLibrary(ownedCardIds: next);
  }

  Map<String, Object?> toJson() => {
        'owned_card_ids': ownedCardIds.toList()..sort(),
      };

  factory CardLibrary.fromJson(Map<String, Object?> json) {
    return CardLibrary(
      ownedCardIds: ((json['owned_card_ids'] ?? const <String>[]) as List)
          .cast<String>()
          .toSet(),
    );
  }

  List<int> toCanonicalBytes() => CanonicalJson.encode(toJson());

  @override
  bool operator ==(Object other) =>
      other is CardLibrary &&
      other.ownedCardIds.length == ownedCardIds.length &&
      other.ownedCardIds.containsAll(ownedCardIds);

  @override
  int get hashCode => Object.hashAll(ownedCardIds);
}
