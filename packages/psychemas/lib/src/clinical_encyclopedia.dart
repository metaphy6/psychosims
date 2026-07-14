import 'canonical_json.dart';

/// A fictional clinical field-note entry in the in-game encyclopedia (§15).
///
/// Entries are invented reference material, never a real DSM/ICD label or
/// diagnostic manual. Each entry is keyed to a collected clue token from the
/// manifest vocabulary (1.2) so cross-session research has a deterministic
/// lookup target.
class ClinicalEncyclopediaEntry {
  /// Stable identifier, e.g. 'brumosis_somatic_marker'.
  final String id;

  /// Localization key for the entry title (player-facing).
  final String titleKey;

  /// Localization key for the short field note (player-facing).
  final String noteKey;

  /// The clue token this entry explains.
  final String clueToken;

  /// Optional fictional drug related to this entry.
  final String? relatedDrug;

  /// Study/subspecialty field this entry belongs to (fictional taxonomy).
  final String fieldKey;

  const ClinicalEncyclopediaEntry({
    required this.id,
    required this.titleKey,
    required this.noteKey,
    required this.clueToken,
    this.relatedDrug,
    required this.fieldKey,
  });

  Map<String, Object?> toJson() => {
        'id': id,
        'title_key': titleKey,
        'note_key': noteKey,
        'clue_token': clueToken,
        if (relatedDrug != null) 'related_drug': relatedDrug,
        'field_key': fieldKey,
      };

  factory ClinicalEncyclopediaEntry.fromJson(Map<String, Object?> json) {
    return ClinicalEncyclopediaEntry(
      id: json['id']! as String,
      titleKey: json['title_key']! as String,
      noteKey: json['note_key']! as String,
      clueToken: json['clue_token']! as String,
      relatedDrug: json['related_drug'] as String?,
      fieldKey: json['field_key']! as String,
    );
  }

  List<int> toCanonicalBytes() => CanonicalJson.encode(toJson());

  @override
  bool operator ==(Object other) =>
      other is ClinicalEncyclopediaEntry &&
      other.id == id &&
      other.titleKey == titleKey &&
      other.noteKey == noteKey &&
      other.clueToken == clueToken &&
      other.relatedDrug == relatedDrug &&
      other.fieldKey == fieldKey;

  @override
  int get hashCode =>
      Object.hash(id, titleKey, noteKey, clueToken, relatedDrug, fieldKey);
}

/// A read-only, deterministic encyclopedia catalogue.
///
/// Content is loaded from the 0.12 fictional-taxonomy registry; lookups are
/// pure functions of the collected clue-token set.
class ClinicalEncyclopedia {
  final Map<String, ClinicalEncyclopediaEntry> _byClueToken;
  final Map<String, ClinicalEncyclopediaEntry> _byId;

  const ClinicalEncyclopedia._(this._byClueToken, this._byId);

  factory ClinicalEncyclopedia(Iterable<ClinicalEncyclopediaEntry> entries) {
    final byClue = <String, ClinicalEncyclopediaEntry>{};
    final byId = <String, ClinicalEncyclopediaEntry>{};
    for (final entry in entries) {
      byClue[entry.clueToken] = entry;
      byId[entry.id] = entry;
    }
    return ClinicalEncyclopedia._(byClue, byId);
  }

  static const ClinicalEncyclopedia empty = ClinicalEncyclopedia._({}, {});

  /// Returns the entry matching [clueToken], or null if not collected/unknown.
  ClinicalEncyclopediaEntry? lookupByClue(String clueToken) =>
      _byClueToken[clueToken];

  /// Returns the entry with [id], or null if unknown.
  ClinicalEncyclopediaEntry? lookupById(String id) => _byId[id];

  /// All entries whose clue token is present in [collectedClues].
  List<ClinicalEncyclopediaEntry> unlocked(Iterable<String> collectedClues) {
    final result = <ClinicalEncyclopediaEntry>[];
    for (final clue in collectedClues) {
      final entry = _byClueToken[clue];
      if (entry != null) result.add(entry);
    }
    return result;
  }

  List<ClinicalEncyclopediaEntry> get all => _byId.values.toList();

  Map<String, Object?> toJson() => {
        'entries': all.map((e) => e.toJson()).toList(),
      };

  factory ClinicalEncyclopedia.fromJson(Map<String, Object?> json) {
    final entries = (json['entries']! as List<dynamic>)
        .cast<Map<String, Object?>>()
        .map(ClinicalEncyclopediaEntry.fromJson);
    return ClinicalEncyclopedia(entries);
  }

  List<int> toCanonicalBytes() => CanonicalJson.encode(toJson());
}
