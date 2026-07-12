import 'dart:convert';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:psychemas/psychemas.dart';
import 'package:test/test.dart';

void main() {
  group('PatientManifest', () {
    const manifest = PatientManifest(
      id: 'poc-vexa-001',
      rulesetVersion: 'poc-1.0.0',
      contentChecksum:
          'sha256:0000000000000000000000000000000000000000000000000000000000000000',
      nameKey: 'manifests.poc_vexa_001.name',
      displayNameKey: 'manifests.poc_vexa_001.display_name',
      styleArchetype: StyleArchetype.vexa,
      initialState: {'trust': 30, 'agitation': 45, 'resistance': 25},
      interactionPatterns: [
        InteractionPattern.openQuestion,
        InteractionPattern.validate,
      ],
      clueTokens: ['ferve-axine'],
      maxHistoryTurns: 6,
      modelFacingTemplate: 'Test template.',
    );

    test('round-trips through JSON', () {
      final json = manifest.toJson();
      final restored = PatientManifest.fromJson(json);
      expect(restored, equals(manifest));
    });

    test('canonical bytes are deterministic', () {
      final a = manifest.toCanonicalBytes();
      final b = manifest.toCanonicalBytes();
      expect(a, equals(b));
    });
  });

  group('ManifestLoader', () {
    const loader = ManifestLoader();

    Map<String, Object?> _validJson({String? checksum}) {
      final json = <String, Object?>{
        'schema_version': '1.0.0',
        'ruleset_version': 'poc-1.0.0',
        'id': 'poc-vexa-001',
        'content_checksum': checksum ?? '',
        'memory_class': 'stateless',
        'name_key': 'manifests.poc_vexa_001.name',
        'display_name_key': 'manifests.poc_vexa_001.display_name',
        'style_archetype': 'vexa',
        'initial_state': {'trust': 30, 'agitation': 45, 'resistance': 25},
        'interaction_patterns': ['openQuestion'],
        'clue_tokens': ['ferve-axine'],
        'max_history_turns': 6,
        'model_facing_template': 'Test template.',
      };
      json['content_checksum'] = checksum ?? _computeChecksum(json);
      return json;
    }

    Uint8List encode(Map<String, Object?> json) {
      return Uint8List.fromList(utf8.encode(jsonEncode(json)));
    }

    test('loads a valid manifest', () {
      final json = _validJson();
      final loaded = loader.load(encode(json));
      expect(loaded.id, equals('poc-vexa-001'));
      expect(loaded.styleArchetype, equals(StyleArchetype.vexa));
    });

    test('rejects malformed JSON', () {
      expect(
        () => loader.load(Uint8List.fromList(utf8.encode('{not json'))),
        throwsA(
          isA<ManifestValidationError>().having(
            (e) => e.kind,
            'kind',
            ManifestErrorKind.malformed,
          ),
        ),
      );
    });

    test('rejects unknown schema_version', () {
      final json = _validJson();
      json['schema_version'] = '99.0.0';
      json['content_checksum'] = _computeChecksum(json);
      expect(
        () => loader.load(encode(json)),
        throwsA(
          isA<ManifestValidationError>().having(
            (e) => e.kind,
            'kind',
            ManifestErrorKind.unknownVersion,
          ),
        ),
      );
    });

    test('rejects checksum mismatch', () {
      final json = _validJson();
      json['content_checksum'] =
          'sha256:0000000000000000000000000000000000000000000000000000000000000000';
      expect(
        () => loader.load(encode(json)),
        throwsA(
          isA<ManifestValidationError>().having(
            (e) => e.kind,
            'kind',
            ManifestErrorKind.checksumMismatch,
          ),
        ),
      );
    });

    test('ignores unknown additive fields', () {
      final json = _validJson();
      json['future_field'] = 'ignored';
      json['content_checksum'] = _computeChecksum(json);
      final loaded = loader.load(encode(json));
      expect(loaded.id, equals('poc-vexa-001'));
    });

    test('rejects content integrity violations', () {
      final loaderWithPatterns = ManifestLoader(
        forbiddenPatterns: [
          RegExp(r'\bprozac\b', caseSensitive: false),
        ],
      );
      final json = _validJson();
      json['model_facing_template'] = 'They are taking Prozac.';
      json['content_checksum'] = _computeChecksum(json);
      expect(
        () => loaderWithPatterns.load(encode(json)),
        throwsA(
          isA<ManifestValidationError>().having(
            (e) => e.kind,
            'kind',
            ManifestErrorKind.contentIntegrity,
          ),
        ),
      );
    });
  });
}

String _computeChecksum(Map<String, Object?> json) {
  final copy = Map<String, Object?>.of(json);
  copy['content_checksum'] = '';

  Object? sort(Object? value) {
    if (value is Map<String, Object?>) {
      final sorted = Map<String, Object?>.fromEntries(
        value.entries.toList()..sort((a, b) => a.key.compareTo(b.key)),
      );
      return sorted.map((k, v) => MapEntry(k, sort(v)));
    }
    if (value is List) {
      return value.map(sort).toList();
    }
    return value;
  }

  final canonical = jsonEncode(sort(copy));
  final digest = sha256.convert(utf8.encode(canonical)).toString();
  return 'sha256:$digest';
}
