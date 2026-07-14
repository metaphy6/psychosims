import 'canonical_json.dart';

/// A target card that can be unlocked by spending study/subspecialty points.
///
/// Part of the §15 research loop. Costs are owned by C-4 and supplied through
/// the config authority; this schema only carries the shape.
class StudyUnlockEntry {
  /// Card identifier to unlock.
  final String cardId;

  /// Study points required.
  final int studyCost;

  /// Subspecialty points required.
  final int subspecialtyCost;

  /// Field key this unlock belongs to (fictional taxonomy).
  final String fieldKey;

  const StudyUnlockEntry({
    required this.cardId,
    required this.studyCost,
    required this.subspecialtyCost,
    required this.fieldKey,
  });

  Map<String, Object?> toJson() => {
        'card_id': cardId,
        'study_cost': studyCost,
        'subspecialty_cost': subspecialtyCost,
        'field_key': fieldKey,
      };

  factory StudyUnlockEntry.fromJson(Map<String, Object?> json) {
    return StudyUnlockEntry(
      cardId: json['card_id']! as String,
      studyCost: json['study_cost']! as int,
      subspecialtyCost: json['subspecialty_cost']! as int,
      fieldKey: json['field_key']! as String,
    );
  }

  List<int> toCanonicalBytes() => CanonicalJson.encode(toJson());

  @override
  bool operator ==(Object other) =>
      other is StudyUnlockEntry &&
      other.cardId == cardId &&
      other.studyCost == studyCost &&
      other.subspecialtyCost == subspecialtyCost &&
      other.fieldKey == fieldKey;

  @override
  int get hashCode =>
      Object.hash(cardId, studyCost, subspecialtyCost, fieldKey);
}

/// Read-only catalogue of study unlocks.
class StudyCatalog {
  final Map<String, StudyUnlockEntry> _byCardId;

  const StudyCatalog._(this._byCardId);

  factory StudyCatalog(Iterable<StudyUnlockEntry> entries) {
    final map = <String, StudyUnlockEntry>{};
    for (final entry in entries) {
      map[entry.cardId] = entry;
    }
    return StudyCatalog._(map);
  }

  static const StudyCatalog empty = StudyCatalog._({});

  StudyUnlockEntry? lookup(String cardId) => _byCardId[cardId];

  List<StudyUnlockEntry> get all => _byCardId.values.toList();

  Map<String, Object?> toJson() => {
        'entries': all.map((e) => e.toJson()).toList(),
      };

  factory StudyCatalog.fromJson(Map<String, Object?> json) {
    final entries = (json['entries']! as List<dynamic>)
        .cast<Map<String, Object?>>()
        .map(StudyUnlockEntry.fromJson);
    return StudyCatalog(entries);
  }

  List<int> toCanonicalBytes() => CanonicalJson.encode(toJson());
}
