import 'canonical_json.dart';
import 'card.dart';
import 'interaction_pattern.dart';
import 'memory_class.dart';
import 'style_archetype.dart';

/// Canonical patient manifest schema for the Phase 1 PoC.
///
/// The manifest is a typed, versioned, checksum-guarded content atom. It
/// separates core-facing tokens (style archetype, interaction patterns, clue
/// tokens) from player-facing copy (localization keys). All model-facing prose
/// is inserted through the [modelFacingTemplate] field so the prompt assembler
/// can enforce template-level isolation.
class PatientManifest {
  static const String currentSchemaVersion = '1.0.0';

  /// Schema version of this manifest. Controlled by the 0.7 versioning registry.
  final String schemaVersion;

  /// Ruleset version that produced/consumes this manifest. Distinct from
  /// [schemaVersion]; a ruleset change affects the core, a schema change
  /// affects the wire shape.
  final String rulesetVersion;

  /// Stable identifier for this case.
  final String id;

  /// SHA-256 of the canonical JSON serialization (with this field set to empty
  /// string). Verified on load.
  final String contentChecksum;

  /// Whether this case carries persistent history across sessions.
  final MemoryClass memoryClass;

  /// Localization key for the case title (player-facing).
  final String nameKey;

  /// Localization key for the short display name (player-facing).
  final String displayNameKey;

  /// Core-facing style archetype token.
  final StyleArchetype styleArchetype;

  /// Core-facing initial pressure / sim state. Keys are axis names; values are
  /// integers in a bounded range.
  final Map<String, int> initialState;

  /// Whitelist of actions the deterministic core can resolve for this case.
  ///
  /// Kept for 0.8 wire-compatibility with PoC manifests; new content should
  /// supply [cards] instead. When [cards] is empty, the core derives card
  /// instances from this list.
  final List<InteractionPattern> interactionPatterns;

  /// Production card instances for this case.
  ///
  /// If `null`, the loader back-maps [interactionPatterns] to card instances
  /// additively so existing PoC content still resolves. Explicit cards are
  /// serialized; derived cards are not, preserving PoC wire shape.
  final List<Card>? cards;

  /// Mandatory clue tokens that must survive into the prompt and be honoured
  /// by the model output.
  final List<String> clueTokens;

  /// Maximum conversation-window turns for this case.
  final int maxHistoryTurns;

  /// Model-facing prose template. Inserted by the prompt assembler as data,
  /// never parsed as instructions.
  final String modelFacingTemplate;

  const PatientManifest({
    this.schemaVersion = currentSchemaVersion,
    required this.rulesetVersion,
    required this.id,
    required this.contentChecksum,
    this.memoryClass = MemoryClass.stateless,
    required this.nameKey,
    required this.displayNameKey,
    required this.styleArchetype,
    required this.initialState,
    required this.interactionPatterns,
    this.cards,
    required this.clueTokens,
    required this.maxHistoryTurns,
    required this.modelFacingTemplate,
  });

  /// Returns a copy with the supplied fields replaced.
  PatientManifest copyWith({
    String? schemaVersion,
    String? rulesetVersion,
    String? id,
    String? contentChecksum,
    MemoryClass? memoryClass,
    String? nameKey,
    String? displayNameKey,
    StyleArchetype? styleArchetype,
    Map<String, int>? initialState,
    List<InteractionPattern>? interactionPatterns,
    List<Card>? cards,
    List<String>? clueTokens,
    int? maxHistoryTurns,
    String? modelFacingTemplate,
  }) {
    return PatientManifest(
      schemaVersion: schemaVersion ?? this.schemaVersion,
      rulesetVersion: rulesetVersion ?? this.rulesetVersion,
      id: id ?? this.id,
      contentChecksum: contentChecksum ?? this.contentChecksum,
      memoryClass: memoryClass ?? this.memoryClass,
      nameKey: nameKey ?? this.nameKey,
      displayNameKey: displayNameKey ?? this.displayNameKey,
      styleArchetype: styleArchetype ?? this.styleArchetype,
      initialState: initialState ?? this.initialState,
      interactionPatterns: interactionPatterns ?? this.interactionPatterns,
      cards: cards ?? this.cards,
      clueTokens: clueTokens ?? this.clueTokens,
      maxHistoryTurns: maxHistoryTurns ?? this.maxHistoryTurns,
      modelFacingTemplate: modelFacingTemplate ?? this.modelFacingTemplate,
    );
  }

  /// Serializes to a canonical, deterministic JSON map.
  ///
  /// Field ordering is fixed so that checksums are reproducible across runs
  /// and platforms (0.8 canonical serialization contract).
  Map<String, Object?> toJson() => {
        'schema_version': schemaVersion,
        'ruleset_version': rulesetVersion,
        'id': id,
        'content_checksum': contentChecksum,
        'memory_class': memoryClass.toJson(),
        'name_key': nameKey,
        'display_name_key': displayNameKey,
        'style_archetype': styleArchetype.toJson(),
        'initial_state': initialState,
        'interaction_patterns':
            interactionPatterns.map((p) => p.toJson()).toList(),
        if (cards?.isNotEmpty ?? false)
          'cards': cards!.map((c) => c.toJson()).toList(),
        'clue_tokens': clueTokens.toList(),
        'max_history_turns': maxHistoryTurns,
        'model_facing_template': modelFacingTemplate,
      };

  factory PatientManifest.fromJson(Map<String, Object?> json) {
    return PatientManifest(
      schemaVersion: json['schema_version']! as String,
      rulesetVersion: json['ruleset_version']! as String,
      id: json['id']! as String,
      contentChecksum: json['content_checksum']! as String,
      memoryClass: MemoryClassJson.fromJson(json['memory_class']! as String),
      nameKey: json['name_key']! as String,
      displayNameKey: json['display_name_key']! as String,
      styleArchetype:
          StyleArchetypeJson.fromJson(json['style_archetype']! as String),
      initialState:
          (json['initial_state']! as Map<String, dynamic>).cast<String, int>(),
      interactionPatterns: (json['interaction_patterns']! as List<dynamic>)
          .cast<String>()
          .map(InteractionPatternJson.fromJson)
          .toList(),
      cards: _parseCards(
          json['cards'], json['interaction_patterns']! as List<dynamic>),
      clueTokens: (json['clue_tokens']! as List<dynamic>).cast<String>(),
      maxHistoryTurns: json['max_history_turns']! as int,
      modelFacingTemplate: json['model_facing_template']! as String,
    );
  }

  static List<Card>? _parseCards(
    Object? cardsJson,
    List<dynamic> interactionPatternsJson,
  ) {
    if (cardsJson is List && cardsJson.isNotEmpty) {
      return cardsJson.cast<Map<String, dynamic>>().map(Card.fromJson).toList();
    }
    return null;
  }

  /// Card instances for core resolution. Uses explicitly declared [cards] if
  /// present, otherwise derives them from [interactionPatterns].
  List<Card> get resolvedCards =>
      cards ?? interactionPatterns.map(cardFromInteractionPattern).toList();

  /// Encodes this manifest to canonical JSON bytes.
  ///
  /// Uses the shared [CanonicalJson] encoder so all `packages/` schemas share
  /// one casing convention and byte-identical output.
  List<int> toCanonicalBytes() {
    return CanonicalJson.encode(toJson());
  }

  @override
  bool operator ==(Object other) =>
      other is PatientManifest &&
      other.schemaVersion == schemaVersion &&
      other.rulesetVersion == rulesetVersion &&
      other.id == id &&
      other.contentChecksum == contentChecksum &&
      other.memoryClass == memoryClass &&
      other.nameKey == nameKey &&
      other.displayNameKey == displayNameKey &&
      other.styleArchetype == styleArchetype &&
      _mapEquals(other.initialState, initialState) &&
      _listEquals(other.interactionPatterns, interactionPatterns) &&
      _nullableListEquals(other.cards, cards) &&
      _listEquals(other.clueTokens, clueTokens) &&
      other.maxHistoryTurns == maxHistoryTurns &&
      other.modelFacingTemplate == modelFacingTemplate;

  @override
  int get hashCode => Object.hash(
        schemaVersion,
        rulesetVersion,
        id,
        contentChecksum,
        memoryClass,
        nameKey,
        displayNameKey,
        styleArchetype,
        Object.hashAll(initialState.entries),
        Object.hashAll(interactionPatterns),
        cards == null ? null : Object.hashAll(cards!),
        Object.hashAll(clueTokens),
        maxHistoryTurns,
        modelFacingTemplate,
      );

  static bool _mapEquals(Map<String, int> a, Map<String, int> b) {
    if (a.length != b.length) return false;
    for (final entry in a.entries) {
      if (b[entry.key] != entry.value) return false;
    }
    return true;
  }

  static bool _listEquals<T>(List<T> a, List<T> b) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }

  static bool _nullableListEquals<T>(List<T>? a, List<T>? b) {
    if (a == null) return b == null;
    if (b == null) return false;
    return _listEquals(a, b);
  }
}
