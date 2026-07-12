// ignore_for_file: prefer_const_constructors

import 'dart:convert';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:psychemas/psychemas.dart';
import 'package:psycore/psycore.dart' as core;

/// Returns a valid PoC manifest JSON string for tests.
String testManifestJson() {
  const base = {
    'schema_version': '1.0.0',
    'ruleset_version': 'poc-1.0.0',
    'id': 'poc-vexa-001',
    'content_checksum': '',
    'memory_class': 'stateless',
    'name_key': 'manifests.poc_vexa_001.name',
    'display_name_key': 'manifests.poc_vexa_001.display_name',
    'style_archetype': 'vexa',
    'initial_state': {'agitation': 45, 'resistance': 20, 'trust': 30},
    'interaction_patterns': ['open_question', 'validate', 'reframe'],
    'clue_tokens': ['ferve-axine'],
    'max_history_turns': 4,
    'model_facing_template': 'The patient is restless.',
  };
  final canonical = jsonEncode(_sortedJson(base));
  final checksum = 'sha256:${sha256.convert(utf8.encode(canonical))}';
  final withChecksum = Map<String, Object?>.from(base);
  withChecksum['content_checksum'] = checksum;
  return jsonEncode(_sortedJson(withChecksum));
}

/// Returns a loaded [PatientManifest] for tests.
PatientManifest testManifest() {
  final bytes = utf8.encode(testManifestJson());
  final loader = ManifestLoader();
  return loader.load(Uint8List.fromList(bytes));
}

extension TestManifestHelpers on PatientManifest {
  core.SimState initialSimState() {
    return core.SimState(
      seed: 42,
      axes: Map<String, int>.from(initialState),
    );
  }
}

Object? _sortedJson(Object? value) {
  if (value is Map<String, dynamic>) {
    final sorted = Map<String, Object?>.fromEntries(
      value.entries.toList()..sort((a, b) => a.key.compareTo(b.key)),
    );
    return sorted.map((k, v) => MapEntry(k, _sortedJson(v)));
  }
  if (value is List) {
    return value.map(_sortedJson).toList();
  }
  return value;
}
