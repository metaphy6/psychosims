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

    final loadout = Loadout(
      cardIds: actions.map((a) => cardFromInteractionPattern(a).id).toList(),
      slotCap: 6,
    );
    final library = CardLibrary(
      ownedCardIds:
          actions.map((a) => cardFromInteractionPattern(a).id).toSet(),
    );

    test('scripted replay stops at a terminal success or walkout', () {
      for (final entry in {
        const SimState(
            seed: 42,
            trustScore: 60,
            agitationLevel: 20,
            sessionProgress: 99): SessionOutcome.succeed,
        const SimState(seed: 42, trustScore: 30, agitationLevel: 100):
            SessionOutcome.fail,
      }.entries) {
        final outputs = const CoreRunPath().resolveScripted(
            rulesetVersion: '0.1.0',
            manifest: manifest,
            actions: List.filled(5, InteractionPattern.openQuestion),
            rootSeed: 42,
            clock: const InjectedClock.replay(0),
            loadout: loadout,
            library: library,
            startState: entry.key);
        expect(outputs, hasLength(1));
        expect(outputs.single.outcome, entry.value);
      }
    });

    test('matches the committed golden outcome vector', () {
      const path = '../../test_fixtures/golden_replay.json';
      final fixture = File(path);
      final outputs = const CoreRunPath().resolveScripted(
        rulesetVersion: '0.1.0',
        manifest: manifest,
        actions: actions,
        rootSeed: 42,
        clock: InjectedClock.replay(123456789),
        loadout: loadout,
        library: library,
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
