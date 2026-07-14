import 'canonical_json.dart';

/// The capped active loadout a player brings into a session.
///
/// Every [cardId] must be owned by the player ([CardLibrary.owns]) and the
/// total count must not exceed [slotCap]. The deterministic core rejects any
/// play whose card is not present here (2.2 receipt-forgery guard).
class Loadout {
  final List<String> cardIds;
  final int slotCap;

  const Loadout({required this.cardIds, required this.slotCap});

  /// Empty loadout with a given cap.
  const Loadout.empty({required this.slotCap}) : cardIds = const [];

  bool contains(String cardId) => cardIds.contains(cardId);

  bool get isWithinCap => cardIds.length <= slotCap;

  /// Validates that the loadout is within its cap and that every card is in
  /// the supplied owned set.
  bool isValidForLibrary(Set<String> ownedCardIds) {
    return isWithinCap && cardIds.every(ownedCardIds.contains);
  }

  Map<String, Object?> toJson() => {
        'card_ids': cardIds.toList(),
        'slot_cap': slotCap,
      };

  factory Loadout.fromJson(Map<String, Object?> json) {
    return Loadout(
      cardIds: ((json['card_ids'] ?? const <String>[]) as List).cast<String>(),
      slotCap: json['slot_cap']! as int,
    );
  }

  List<int> toCanonicalBytes() => CanonicalJson.encode(toJson());

  @override
  bool operator ==(Object other) =>
      other is Loadout &&
      other.slotCap == slotCap &&
      _listEquals(other.cardIds, cardIds);

  @override
  int get hashCode => Object.hash(slotCap, Object.hashAll(cardIds));

  static bool _listEquals(List<String> a, List<String> b) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }
}
