/// Trusted, model-free content build. Run from tools/ with an explicit build
/// specification and output path; --check is read-only and fails on any drift.
library;

import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:path/path.dart' as p;
import 'package:psychemas/psychemas.dart';
import 'package:psyconfig/psyconfig.dart';
import 'package:psycore/psycore.dart';
import 'package:yaml/yaml.dart';

const _sourceRoots = [
  'packages/psycore/lib',
  'packages/psychemas/lib',
  'packages/psychemas/schema',
  'config/lib',
  'packages/psycore/pubspec.yaml',
  'packages/psycore/pubspec.lock',
  'packages/psychemas/pubspec.yaml',
  'packages/psychemas/pubspec.lock',
  'config/pubspec.yaml',
  'config/pubspec.lock',
  'config/ruleset_registry.yaml',
  'tools/compile_outcomes.dart',
  'tools/pubspec.yaml',
  'tools/pubspec.lock',
  'content/fictional_taxonomy.yaml',
];

/// Registry patterns remain authored in the canonical YAML file. Dart's regex
/// implementation requires the registry's leading (?i) as a constructor option.
List<RegExp> loadForbiddenPatterns(String text) {
  if (text.length > 131072) throw const FormatException('taxonomy_size');
  final registry = loadYaml(text);
  final values = registry is YamlMap ? registry['forbidden_patterns'] : null;
  if (values is! YamlList || values.isEmpty || values.length > 128) {
    throw const FormatException('taxonomy_patterns');
  }
  return List<RegExp>.unmodifiable(values.map((value) {
    if (value is! String || value.isEmpty || value.length > 4096) {
      throw const FormatException('taxonomy_pattern');
    }
    final insensitive = value.startsWith('(?i)');
    return RegExp(insensitive ? value.substring(4) : value,
        caseSensitive: !insensitive);
  }));
}

/// Includes every source file in each selected tree so additions and deletions,
/// as well as edits, invalidate stale artifacts. Links are never followed.
Map<String, String> hashSourceTree(Directory root, List<String> paths) {
  final hashes = <String, String>{};
  for (final relative in paths) {
    final absolute = p.join(root.path, relative);
    final type = FileSystemEntity.typeSync(absolute, followLinks: false);
    final files = type == FileSystemEntityType.directory
        ? Directory(absolute).listSync(recursive: true, followLinks: false)
        : [File(absolute)];
    for (final entity in files) {
      final kind = FileSystemEntity.typeSync(entity.path, followLinks: false);
      if (kind == FileSystemEntityType.directory) continue;
      if (kind != FileSystemEntityType.file)
        throw const FormatException('source_not_regular');
      final file = File(entity.path);
      if (file.lengthSync() > 1048576)
        throw const FormatException('source_size');
      hashes[p
          .relative(file.path, from: root.path)
          .split(p.separator)
          .join('/')] = sha256.convert(file.readAsBytesSync()).toString();
    }
  }
  return {for (final key in hashes.keys.toList()..sort()) key: hashes[key]!};
}

Map<String, Object?> _object(Object? value, Set<String> keys) {
  if (value is! Map<String, dynamic> ||
      value.length != keys.length ||
      value.keys.any((k) => !keys.contains(k)))
    throw const FormatException('build_shape');
  return value.cast<String, Object?>();
}

int _integer(Object? value) {
  if (value is! int) throw const FormatException('build_integer');
  return value;
}

String _string(Object? value) {
  if (value is! String || value.isEmpty || value.length > 256)
    throw const FormatException('build_string');
  return value;
}

List<String> _strings(Object? value, int bound) {
  if (value is! List ||
      value.length > bound ||
      value.any((v) => v is! String)) {
    throw const FormatException('build_array');
  }
  final strings = value.map(_string).toList();
  if (strings.toSet().length != strings.length)
    throw const FormatException('build_duplicates');
  return strings;
}

File _manifestFile(Directory root, String relative) {
  if (p.isAbsolute(relative) ||
      relative.contains('\\') ||
      relative.split('/').any((s) => s == '..' || s == '.' || s.isEmpty)) {
    throw const FormatException('manifest_path');
  }
  final file = File(p.join(root.path, relative));
  final canonicalRoot = root.resolveSymbolicLinksSync();
  if (!p.isWithin(canonicalRoot, file.resolveSymbolicLinksSync()))
    throw const FormatException('manifest_path');
  if (file.lengthSync() > 131072) throw const FormatException('manifest_size');
  return file;
}

/// Root is the source checkout running the trusted compiler, never a client
/// input. The executable anchors it to its own path. Tests may inject a checkout.
List<int> buildOutcomeArtifact(
    {required Directory root, required List<int> specification}) {
  if (specification.length > 131072)
    throw const FormatException('build_spec_size');
  final spec = _object(jsonDecode(utf8.decode(specification)), {
    'build_schema_version',
    'catalog_version',
    'environment',
    'limits',
    'entries'
  });
  if (spec['build_schema_version'] != '1.0.0' ||
      spec['environment'] != 'prod') {
    throw const FormatException('unsupported_build');
  }
  final values = _object(spec['limits'], {
    'max_actions',
    'max_deltas',
    'max_transitions',
    'max_receipt_bytes',
    'max_proof_bytes'
  });
  final limits = OutcomeCompileLimits(
      maxActions: _integer(values['max_actions']),
      maxDeltas: _integer(values['max_deltas']),
      maxTransitions: _integer(values['max_transitions']),
      maxReceiptBytes: _integer(values['max_receipt_bytes']),
      maxProofBytes: _integer(values['max_proof_bytes']));
  final entries = spec['entries'];
  if (entries is! List || entries.isEmpty || entries.length > 64)
    throw const FormatException('build_entries');
  final initialSourceHashes = hashSourceTree(root, _sourceRoots);
  final patterns = loadForbiddenPatterns(
      File(p.join(root.path, 'content/fictional_taxonomy.yaml'))
          .readAsStringSync());
  final compiler = TrustedOutcomeCompiler(
      balance: CardBalance.fromConfig(loadConfig(environment: 'prod').balance),
      limits: limits);
  final proofs = <Map<String, Object?>>[];
  final bindings = <String>{};
  final sourceHashes = Map<String, String>.of(initialSourceHashes);
  for (final raw in entries) {
    final entry = _object(raw,
        {'manifest_path', 'root_seed', 'loadout', 'library', 'controllers'});
    final relative = _string(entry['manifest_path']);
    final source = _manifestFile(root, relative).readAsBytesSync();
    final manifest = ManifestLoader(forbiddenPatterns: patterns).load(source);
    sourceHashes[relative] = sha256.convert(source).toString();
    final loadout = _object(entry['loadout'], {'card_ids', 'slot_cap'});
    final library = _object(entry['library'], {'owned_card_ids'});
    final controllers =
        _object(entry['controllers'], {'focus', 'emotional_delivery'});
    final snapshot = SessionStartState(
        rootSeed: _integer(entry['root_seed']),
        initialAxes: manifest.initialState,
        loadout: Loadout(
            cardIds: _strings(loadout['card_ids'], 6),
            slotCap: _integer(loadout['slot_cap'])),
        library: CardLibrary(
            ownedCardIds: _strings(library['owned_card_ids'], 64).toSet()),
        controllers: TherapyControllerSettings.fromJson(controllers));
    final proof = compiler.compile(
        rawManifest: source,
        start: snapshot,
        catalogVersion: _string(spec['catalog_version']),
        forbiddenPatterns: patterns);
    final binding = CanonicalJson.encodeString(
        {'manifest': manifest.contentChecksum, 'start': snapshot.toJson()});
    if (!bindings.add(binding))
      throw const FormatException('duplicate_binding');
    proofs.add({
      'proof_sha256': sha256.convert(proof.canonicalBytes).toString(),
      'proof': proof.toJson()
    });
  }
  proofs.sort((a, b) =>
      (a['proof_sha256'] as String).compareTo(b['proof_sha256'] as String));
  // Build from a stable checkout. Detect source edits during this invocation.
  final current = hashSourceTree(root, _sourceRoots);
  for (final entry in sourceHashes.entries) {
    if ((current[entry.key] ??
            sha256
                .convert(_manifestFile(root, entry.key).readAsBytesSync())
                .toString()) !=
        entry.value) {
      throw const FormatException('source_changed_during_build');
    }
  }
  if (CanonicalJson.encodeString(current) !=
      CanonicalJson.encodeString(initialSourceHashes)) {
    throw const FormatException('source_changed_during_build');
  }
  final artifact = CanonicalJson.encode({
    'artifact_schema_version': '1.0.0',
    'build': {
      'compiler_version': TrustedOutcomeCompiler.compilerVersion,
      'config_environment': 'prod',
      'specification_sha256': sha256.convert(specification).toString(),
      'source_sha256': sourceHashes
    },
    'proofs': proofs,
  });
  if (artifact.length > 16777216) throw const FormatException('artifact_size');
  return List<int>.unmodifiable([...artifact, 10]);
}

bool artifactMatches(List<int> expected, List<int> actual) {
  if (expected.length != actual.length) return false;
  for (var i = 0; i < expected.length; i++) {
    if (expected[i] != actual[i]) return false;
  }
  return true;
}

void main(List<String> args) {
  try {
    var check = false;
    final options = <String, String>{};
    for (var i = 0; i < args.length; i++) {
      if (args[i] == '--check' && !check) {
        check = true;
        continue;
      }
      if (!{'--spec', '--out'}.contains(args[i]) ||
          i + 1 >= args.length ||
          options.containsKey(args[i])) {
        throw const FormatException('usage: --spec PATH --out PATH [--check]');
      }
      options[args[i]] = args[++i];
    }
    if (options.length != 2)
      throw const FormatException('usage: --spec PATH --out PATH [--check]');
    final root = File.fromUri(Platform.script).parent.parent;
    final spec = File(options['--spec']!);
    if (spec.lengthSync() > 131072)
      throw const FormatException('build_spec_size');
    final bytes =
        buildOutcomeArtifact(root: root, specification: spec.readAsBytesSync());
    final output = File(options['--out']!);
    if (check) {
      if (!output.existsSync() ||
          output.lengthSync() != bytes.length ||
          !artifactMatches(bytes, output.readAsBytesSync())) {
        throw const FormatException('artifact_drift');
      }
    } else {
      output.parent.createSync(recursive: true);
      final temporary = File('${output.path}.tmp.$pid');
      try {
        temporary.writeAsBytesSync(bytes, flush: true);
        temporary.renameSync(output.path);
      } finally {
        if (temporary.existsSync()) temporary.deleteSync();
      }
    }
    stdout.writeln(
        check ? 'outcome artifact verified' : 'outcome artifact generated');
  } catch (error) {
    // Never echo content, arbitrary paths or parser source snippets into logs.
    final kind = error is OutcomeCompileException
        ? error.kind
        : error is FormatException && error.message == 'artifact_drift'
            ? 'artifact_drift'
            : 'invalid_build_input';
    stderr.writeln('outcome build failed: $kind');
    exitCode = 1;
  }
}
