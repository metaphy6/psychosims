import 'dart:convert';
import 'dart:io';
import 'package:crypto/crypto.dart';
import 'package:psychemas/psychemas.dart';
import 'package:test/test.dart';
import '../compile_outcomes.dart' as tool;

void main() {
  final root = Directory('..').absolute;
  final spec = File('../test_fixtures/outcomes/build_spec.json');
  test(
      'real fixtures are reproducible and bind current sources, config and schema',
      () {
    final first = tool.buildOutcomeArtifact(
        root: root, specification: spec.readAsBytesSync());
    final second = tool.buildOutcomeArtifact(
        root: root, specification: spec.readAsBytesSync());
    expect(first, second);
    expect(
        first,
        File('../test_fixtures/outcomes/trusted_catalog_v1.json')
            .readAsBytesSync());
    final json = jsonDecode(utf8.decode(first)) as Map;
    final hashes = (json['build'] as Map)['source_sha256'] as Map;
    for (final path in [
      'packages/psycore/lib/src/turn_resolver.dart',
      'packages/psycore/lib/src/solvability_oracle.dart',
      'packages/psycore/lib/src/card_balance.dart',
      'packages/psychemas/lib/src/manifest_loader.dart',
      'packages/psychemas/schema/manifest.schema.json',
      'config/lib/src/loader.dart',
      'tools/pubspec.lock',
      'content/fictional_taxonomy.yaml'
    ]) {
      expect(hashes[path],
          sha256.convert(File('../$path').readAsBytesSync()).toString());
    }
    final proofs = json['proofs'] as List;
    expect(proofs.length, 3);
    final starter = proofs.where((entry) =>
        entry['proof']['manifest']['id'] == 'siege.brumosis' &&
        (entry['proof']['start_state']['loadout']['card_ids'] as List).length ==
            1);
    expect(starter, hasLength(1),
        reason:
            'The real fresh-account open_question inventory must have a certified path');
    expect(starter.single['proof']['start_state']['loadout']['card_ids'],
        ['open_question']);
    expect(starter.single['proof']['start_state']['library']['owned_card_ids'],
        ['open_question']);
    for (final entry in proofs) {
      expect(entry['proof_sha256'],
          sha256.convert(CanonicalJson.encode(entry['proof'])).toString());
      expect(entry['proof']['turn_count'], 100);
      expect(entry['proof']['terminal']['lifecycle'], 'cured');
      expect(entry['proof']['deltas'].length, lessThanOrEqualTo(1024));
    }
  });
  test('check rejects altered fixture, source hash or terminal result', () {
    final bytes = tool.buildOutcomeArtifact(
        root: root, specification: spec.readAsBytesSync());
    expect(tool.artifactMatches(bytes, bytes), isTrue);
    final doc = jsonDecode(utf8.decode(bytes));
    doc['build']['source_sha256']
        ['packages/psycore/lib/src/turn_resolver.dart'] = '0' * 64;
    expect(tool.artifactMatches(bytes, CanonicalJson.encode(doc)), isFalse);
    doc['proofs'][0]['proof']['terminal']['lifecycle'] = 'open';
    expect(tool.artifactMatches(bytes, CanonicalJson.encode(doc)), isFalse);
    expect(tool.artifactMatches(bytes, [...bytes, 32]), isFalse);
  });
  test(
      'canonical taxonomy is loaded from YAML and newly authored patterns apply',
      () {
    final taxonomy =
        File('../content/fictional_taxonomy.yaml').readAsStringSync();
    final patterns = tool.loadForbiddenPatterns(taxonomy);
    expect(patterns.any((p) => p.hasMatch('DSMIV')), isTrue);
    final extra =
        tool.loadForbiddenPatterns('$taxonomy\n  - "(?i)sentinelword"\n');
    expect(extra.any((p) => p.hasMatch('SENTINELWORD')), isTrue);
    expect(() => tool.loadForbiddenPatterns('forbidden_patterns: []'),
        throwsFormatException);
    expect(() => tool.loadForbiddenPatterns('forbidden_patterns: [3]'),
        throwsFormatException);
  });
  test(
      'unknown inputs, duplicate entries, arbitrary starts and unsafe paths fail closed',
      () {
    for (final edit in <void Function(dynamic)>[
      (j) => j['environment'] = 'dev',
      (j) => j['entries'][0]['initial_axes'] = {'session_progress': 99},
      (j) => j['entries'][0]['manifest_path'] =
          '../content/manifests/siege_brumosis.json',
      (j) => j['entries'].add(j['entries'][0]),
      (j) => j['entries'][0]['controllers']['unexpected'] = 'raw dialogue',
      (j) => j['limits']['max_receipt_bytes'] = 131073,
    ]) {
      final doc = jsonDecode(spec.readAsStringSync());
      edit(doc);
      expect(
          () => tool.buildOutcomeArtifact(
              root: root, specification: CanonicalJson.encode(doc)),
          throwsA(isA<Exception>()));
    }
  });
  test('source hash collection notices added and altered engine source', () {
    final dir =
        Directory('/tmp/agent-runs').createTempSync('outcome-source-test-');
    addTearDown(() => dir.deleteSync(recursive: true));
    final engine =
        File('${dir.path}/packages/psycore/lib/src/turn_resolver.dart');
    engine.parent.createSync(recursive: true);
    engine.writeAsStringSync('first');
    final before = tool.hashSourceTree(dir, ['packages/psycore/lib']);
    engine.writeAsStringSync('changed');
    final after = tool.hashSourceTree(dir, ['packages/psycore/lib']);
    expect(before, isNot(after));
    File('${engine.parent.path}/new_rule.dart').writeAsStringSync('new');
    expect(tool.hashSourceTree(dir, ['packages/psycore/lib']), hasLength(2));
  });
  test('actual build rejects bad checksum and canonical taxonomy violations',
      () {
    final temp =
        Directory('/tmp/agent-runs').createTempSync('outcome-input-test-');
    addTearDown(() => temp.deleteSync(recursive: true));
    final artifact = jsonDecode(utf8.decode(tool.buildOutcomeArtifact(
        root: root, specification: spec.readAsBytesSync()))) as Map;
    final hashes = (artifact['build'] as Map)['source_sha256'] as Map;
    for (final relative in hashes.keys.cast<String>()) {
      final copy = File('${temp.path}/$relative');
      copy.parent.createSync(recursive: true);
      copy.writeAsBytesSync(File('../$relative').readAsBytesSync());
    }
    final manifest = File('${temp.path}/content/manifests/siege_brumosis.json');
    final original = manifest.readAsStringSync();
    manifest
        .writeAsStringSync(original.replaceFirst('"trust": 40', '"trust": 99'));
    expect(
        () => tool.buildOutcomeArtifact(
            root: temp, specification: spec.readAsBytesSync()),
        throwsA(isA<ManifestValidationError>()));
    final altered = jsonDecode(original) as Map<String, dynamic>;
    altered['model_facing_template'] = 'newregistryterm';
    altered['content_checksum'] = '';
    altered['content_checksum'] =
        'sha256:${sha256.convert(CanonicalJson.encode(altered))}';
    manifest.writeAsBytesSync(CanonicalJson.encode(altered));
    final taxonomy = File('${temp.path}/content/fictional_taxonomy.yaml');
    taxonomy.writeAsStringSync(
        '${taxonomy.readAsStringSync()}\n  - "(?i)newregistryterm"\n');
    expect(
        () => tool.buildOutcomeArtifact(
            root: temp, specification: spec.readAsBytesSync()),
        throwsA(isA<ManifestValidationError>()));
  });
  test('actual headless check returns nonzero for a planted artifact drift',
      () async {
    final dir =
        Directory('/tmp/agent-runs').createTempSync('outcome-cli-test-');
    addTearDown(() => dir.deleteSync(recursive: true));
    final output = File('${dir.path}/proof.json');
    final args = [
      'run',
      'compile_outcomes.dart',
      '--spec',
      spec.path,
      '--out',
      output.path
    ];
    final generated = await Process.run(Platform.resolvedExecutable, args);
    expect(generated.exitCode, 0, reason: '${generated.stderr}');
    final checked =
        await Process.run(Platform.resolvedExecutable, [...args, '--check']);
    expect(checked.exitCode, 0, reason: '${checked.stderr}');
    output.writeAsStringSync('{}');
    final drifted =
        await Process.run(Platform.resolvedExecutable, [...args, '--check']);
    expect(drifted.exitCode, 1);
    expect(drifted.stderr, contains('artifact_drift'));
    expect(output.readAsStringSync(), '{}');
  });
}
