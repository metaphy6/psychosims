import 'dart:convert';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';

import 'canonical_json.dart';
import 'interaction_pattern.dart';
import 'manifest.dart';
import 'manifest_validation_error.dart';
import 'memory_class.dart';
import 'style_archetype.dart';

/// Cap-driven limits for defensive manifest decoding.
class ManifestLoaderLimits {
  static const int defaultMaxBytes = 128 * 1024; // 128 KiB
  static const int defaultMaxFieldLength = 4096;
  static const int defaultMaxListLength = 256;
  static const int defaultMaxMapDepth = 8;

  final int maxBytes;
  final int maxFieldLength;
  final int maxListLength;
  final int maxMapDepth;

  const ManifestLoaderLimits({
    this.maxBytes = defaultMaxBytes,
    this.maxFieldLength = defaultMaxFieldLength,
    this.maxListLength = defaultMaxListLength,
    this.maxMapDepth = defaultMaxMapDepth,
  });
}

/// Interface the app provides to validate player-facing localization keys.
abstract class StringCatalog {
  /// Returns true if [key] resolves to a localized string.
  bool containsKey(String key);
}

/// Loads and integrity-checks a [PatientManifest] from raw bytes.
///
/// The loader is defensive: it rejects oversized payloads, excessive nesting,
/// unknown schema versions, checksum mismatches, and forbidden content
/// patterns. Unknown additive fields on a recognized schema version are
/// ignored per the 0.8 wire-compatibility rule.
class ManifestLoader {
  final ManifestLoaderLimits limits;
  final StringCatalog? catalog;
  final List<RegExp> forbiddenPatterns;

  const ManifestLoader({
    this.limits = const ManifestLoaderLimits(),
    this.catalog,
    this.forbiddenPatterns = const [],
  });

  /// Loads a manifest from canonical JSON bytes.
  PatientManifest load(Uint8List bytes) {
    _guardSize(bytes.length);

    late final Object? decoded;
    try {
      decoded = jsonDecode(utf8.decode(bytes));
    } on FormatException catch (e) {
      throw ManifestValidationError(
          ManifestErrorKind.malformed, 'Invalid JSON: ${e.message}');
    }

    if (decoded is! Map<String, dynamic>) {
      throw const ManifestValidationError(
          ManifestErrorKind.malformed, 'Manifest root must be a JSON object');
    }

    _guardDepth(decoded, 1);
    _guardStringLengths(decoded);
    _guardListLengths(decoded);
    _guardContentIntegrity(decoded);

    final schemaVersion = decoded['schema_version'];
    if (schemaVersion is! String) {
      throw const ManifestValidationError(
          ManifestErrorKind.malformed, 'Missing schema_version');
    }
    if (schemaVersion != PatientManifest.currentSchemaVersion) {
      throw ManifestValidationError(
        ManifestErrorKind.unknownVersion,
        'Unsupported schema_version: $schemaVersion',
      );
    }

    _verifyChecksum(decoded);

    final manifest = _parseKnownFields(decoded);

    _validateLocalizationKeys(manifest);

    return manifest;
  }

  PatientManifest _parseKnownFields(Map<String, dynamic> raw) {
    final initialState = (raw['initial_state'] as Map<String, dynamic>? ?? {})
        .cast<String, int>();
    final interactionPatternNames =
        (raw['interaction_patterns'] as List<dynamic>? ?? []).cast<String>();
    final clueTokens =
        (raw['clue_tokens'] as List<dynamic>? ?? []).cast<String>();

    return PatientManifest(
      schemaVersion: raw['schema_version'] as String,
      rulesetVersion: raw['ruleset_version'] as String,
      id: raw['id'] as String,
      contentChecksum: raw['content_checksum'] as String,
      memoryClass: MemoryClassJson.fromJson(raw['memory_class'] as String),
      nameKey: raw['name_key'] as String,
      displayNameKey: raw['display_name_key'] as String,
      styleArchetype:
          StyleArchetypeJson.fromJson(raw['style_archetype'] as String),
      initialState: initialState,
      interactionPatterns:
          interactionPatternNames.map(InteractionPatternJson.fromJson).toList(),
      clueTokens: clueTokens,
      maxHistoryTurns: raw['max_history_turns'] as int,
      modelFacingTemplate: raw['model_facing_template'] as String,
    );
  }

  void _verifyChecksum(Map<String, dynamic> raw) {
    final checksum = raw['content_checksum'];
    if (checksum is! String || checksum.isEmpty) {
      throw const ManifestValidationError(
          ManifestErrorKind.malformed, 'Missing content_checksum');
    }

    final copy = Map<String, dynamic>.of(raw);
    copy['content_checksum'] = '';
    final canonical = CanonicalJson.encodeString(copy);
    final expected = 'sha256:${sha256.convert(utf8.encode(canonical))}';

    if (expected != checksum) {
      throw ManifestValidationError(
        ManifestErrorKind.checksumMismatch,
        'Checksum mismatch: expected $expected, got $checksum',
      );
    }
  }

  void _validateLocalizationKeys(PatientManifest manifest) {
    if (catalog == null) return;
    for (final key in [manifest.nameKey, manifest.displayNameKey]) {
      if (!catalog!.containsKey(key)) {
        throw ManifestValidationError(
          ManifestErrorKind.missingLocalization,
          'Missing localization key: $key',
        );
      }
    }
  }

  void _guardSize(int length) {
    if (length > limits.maxBytes) {
      throw ManifestValidationError(
        ManifestErrorKind.overBudget,
        'Manifest size $length bytes exceeds cap ${limits.maxBytes}',
      );
    }
  }

  void _guardDepth(Object? value, int depth) {
    if (depth > limits.maxMapDepth) {
      throw ManifestValidationError(
        ManifestErrorKind.overBudget,
        'JSON nesting exceeds ${limits.maxMapDepth}',
      );
    }
    if (value is Map<String, dynamic>) {
      for (final entry in value.values) {
        _guardDepth(entry, depth + 1);
      }
    } else if (value is List) {
      for (final item in value) {
        _guardDepth(item, depth + 1);
      }
    }
  }

  void _guardStringLengths(Object? value) {
    if (value is String && value.length > limits.maxFieldLength) {
      throw ManifestValidationError(
        ManifestErrorKind.overBudget,
        'String field length ${value.length} exceeds ${limits.maxFieldLength}',
      );
    }
    if (value is Map<String, dynamic>) {
      for (final entry in value.values) {
        _guardStringLengths(entry);
      }
    } else if (value is List) {
      for (final item in value) {
        _guardStringLengths(item);
      }
    }
  }

  void _guardListLengths(Object? value) {
    if (value is List && value.length > limits.maxListLength) {
      throw ManifestValidationError(
        ManifestErrorKind.overBudget,
        'List length ${value.length} exceeds ${limits.maxListLength}',
      );
    }
    if (value is Map<String, dynamic>) {
      for (final entry in value.values) {
        _guardListLengths(entry);
      }
    } else if (value is List) {
      for (final item in value) {
        _guardListLengths(item);
      }
    }
  }

  void _guardContentIntegrity(Map<String, dynamic> raw) {
    final buffer = StringBuffer();
    _writeValue(buffer, raw);
    final text = buffer.toString();
    for (final pattern in forbiddenPatterns) {
      if (pattern.hasMatch(text)) {
        throw ManifestValidationError(
          ManifestErrorKind.contentIntegrity,
          'Content matches forbidden pattern: ${pattern.pattern}',
        );
      }
    }
  }

  void _writeValue(StringBuffer buffer, Object? value) {
    if (value is String) {
      buffer.write(value);
      buffer.write('\n');
    } else if (value is Map<String, dynamic>) {
      for (final entry in value.values) {
        _writeValue(buffer, entry);
      }
    } else if (value is List) {
      for (final item in value) {
        _writeValue(buffer, item);
      }
    }
  }
}
