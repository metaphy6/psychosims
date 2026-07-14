import 'package:psychemas/psychemas.dart';
import 'package:psycore/psycore.dart';
import 'package:test/test.dart';

void main() {
  group('LoadoutAnalyzer', () {
    const manifest = PatientManifest(
      id: 'gap-case',
      rulesetVersion: '0.1.0',
      contentChecksum:
          'sha256:0000000000000000000000000000000000000000000000000000000000000000',
      nameKey: 'name',
      displayNameKey: 'display',
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
      modelFacingTemplate: 'template',
    );

    const analyzer = LoadoutAnalyzer();

    test('reports no gap when all signatures are covered', () {
      final loadout = const Loadout(
        cardIds: ['open_question', 'validate', 'reframe', 'set_boundary'],
        slotCap: 6,
      );
      final report = analyzer.analyze(manifest, loadout);
      expect(report.hasGap, isFalse);
      expect(report.missingSignatures, isEmpty);
    });

    test('reports missing signatures when a card type is not equipped', () {
      final loadout = const Loadout(
        cardIds: ['open_question', 'validate'],
        slotCap: 6,
      );
      final report = analyzer.analyze(manifest, loadout);
      expect(report.hasGap, isTrue);
      expect(report.missingSignatures, contains(CardSignature.freeze));
      expect(report.missingSignatures, contains(CardSignature.gambit));
    });
  });
}
