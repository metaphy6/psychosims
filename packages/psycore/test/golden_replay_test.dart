import 'dart:convert';
import 'dart:io';

import 'package:psychemas/psychemas.dart';
import 'package:psycore/psycore.dart';
import 'package:test/test.dart';

void main() {
  group('Golden replay fixture', () {
    const manifest = PatientManifest(
      id: 'golden-case-001',
      rulesetVersion: '0.1.0',
      contentChecksum:
          'sha256:0000000000000000000000000000000000000000000000000000000000000000',
      nameKey: 'golden.case_001.name',
      displayNameKey: 'golden.case_001.display_name',
      styleArchetype: StyleArchetype.vexa,
      initialState: {'trust': 30, 'agitation': 45, 'resistance': 25},
      interactionPatterns: [
        InteractionPattern.openQuestion,
        InteractionPattern.validate,
        InteractionPattern.reframe,
        InteractionPattern.setBoundary,
      ],
      clueTokens: const ['ferve-axine'],
      maxHistoryTurns: 6,
      modelFacingTemplate: 'Golden replay template.',
    );

    final actions = [
      InteractionPattern.openQuestion,
      InteractionPattern.validate,
      InteractionPattern.reframe,
      InteractionPattern.setBoundary,
    ];

    test('matches the committed golden outcome vector', () {
      const path = '../../test_fixtures/golden_replay.json';
      final fixture = File(path);
      final outputs = const CoreRunPath().resolveScripted(
        rulesetVersion: '0.1.0',
        manifest: manifest,
        actions: actions,
        rootSeed: 42,
        clock: InjectedClock.replay(123456789),
      );

      final vector =
          outputs.map((o) => utf8.decode(o.toCanonicalBytes())).toList();
      final actual = const JsonEncoder.withIndent('  ').convert(vector);

      if (!fixture.existsSync()) {
        fixture.createSync(recursive: true);
        fixture.writeAsStringSync(actual);
        fail('Golden fixture did not exist; wrote $path');
      }

      final expected = fixture.readAsStringSync();
      expect(actual, equals(expected),
          reason: 'Replay vector diverged from golden fixture');
    });
  });
}
