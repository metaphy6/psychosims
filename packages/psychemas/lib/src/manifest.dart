import 'dart:convert';

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
  final List<InteractionPattern> interactionPatterns;

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
    required this.clueTokens,
    required this.maxHistoryTurns,
    required this.modelFacingTemplate,
  });

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
        'initial_state': _sortedIntMap(initialState),
        'interaction_patterns':
            interactionPatterns.map((p) => p.toJson()).toList(),
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
      clueTokens: (json['clue_tokens']! as List<dynamic>).cast<String>(),
      maxHistoryTurns: json['max_history_turns']! as int,
      modelFacingTemplate: json['model_facing_template']! as String,
    );
  }

  /// Encodes this manifest to canonical JSON bytes.
  ///
  /// The encoding uses no unnecessary whitespace and a deterministic field
  /// order so the same manifest always yields the same bytes.
  List<int> toCanonicalBytes() {
    return utf8.encode(jsonEncode(toJson()));
  }

  static Map<String, int> _sortedIntMap(Map<String, int> source) {
    final sorted = Map<String, int>.fromEntries(
      source.entries.toList()..sort((a, b) => a.key.compareTo(b.key)),
    );
    return sorted;
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
}
