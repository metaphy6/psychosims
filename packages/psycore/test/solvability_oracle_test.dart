import 'dart:io';

import 'package:psychemas/psychemas.dart';
import 'package:psycore/psycore.dart';
import 'package:test/test.dart';

void main() {
  const oracle = SolvabilityOracle();

  test('siege manifest is solvable and content-compliant', () {
    final bytes =
        File('../../content/manifests/siege_brumosis.json').readAsBytesSync();
    final manifest = ManifestLoader().load(bytes);
    expect(oracle.isSolvable(manifest), isTrue);
    expect(oracle.isContentCompliant(manifest), isTrue);
    expect(manifest.memoryClass, MemoryClass.persistent);
  });

  test('manifest without interaction patterns is not solvable', () {
    final manifest = PatientManifest(
      rulesetVersion: '0.1.0',
      id: 'empty.case',
      contentChecksum: 'sha256:ignored',
      nameKey: 'case.empty.title',
      displayNameKey: 'case.empty.display',
      styleArchetype: StyleArchetype.vexa,
      initialState: const {},
      interactionPatterns: const [],
      clueTokens: const [],
      maxHistoryTurns: 1,
      modelFacingTemplate: 'empty',
    );
    expect(oracle.isSolvable(manifest), isFalse);
  });

  test('real diagnostic labels fail content compliance', () {
    final manifest = PatientManifest(
      rulesetVersion: '0.1.0',
      id: 'bad.case',
      contentChecksum: 'sha256:ignored',
      nameKey: 'case.bad.title',
      displayNameKey: 'case.bad.display',
      styleArchetype: StyleArchetype.vexa,
      initialState: const {},
      interactionPatterns: const [InteractionPattern.openQuestion],
      clueTokens: const ['depression-marker'],
      maxHistoryTurns: 1,
      modelFacingTemplate: 'bad',
    );
    expect(oracle.isContentCompliant(manifest), isFalse);
  });
}
