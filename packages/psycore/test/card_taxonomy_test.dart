import 'package:psychemas/psychemas.dart';
import 'package:psycore/psycore.dart';
import 'package:test/test.dart';

void main() {
  group('Card taxonomy', () {
    const manifest = PatientManifest(
      id: 'taxonomy-case',
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

    const resolver = TurnResolver(InjectedClock.replay(0));

    test('maps PoC interaction patterns to production card types', () {
      final cards = manifest.resolvedCards;
      expect(cards[0].type, CardType.disclosing); // openQuestion
      expect(cards[1].type, CardType.relatable); // validate
      expect(cards[2].type, CardType.manipulative); // reframe
      expect(cards[3].type, CardType.postponing); // setBoundary
    });

    test('records card type, signature and context-fit in deltas', () {
      final output = resolver.resolve(const TurnInput(
        rulesetVersion: '0.1.0',
        manifest: manifest,
        state: SimState(
            seed: 1, axes: {'trust': 30, 'agitation': 45, 'resistance': 25}),
        action: InteractionPattern.openQuestion,
      ));
      expect(output.deltas, isNotEmpty);
      for (final delta in output.deltas) {
        expect(delta.cardType, CardType.disclosing);
        expect(delta.cardSignature, CardSignature.breaker);
        expect(delta.contextFit, isNotNull);
      }
    });

    test('Disclosing aligned reduces resistance more than mismatched', () {
      // Aligned: resistance is high (defense crackable).
      final aligned = resolver.resolve(const TurnInput(
        rulesetVersion: '0.1.0',
        manifest: manifest,
        state: SimState(
            seed: 7, axes: {'trust': 30, 'agitation': 45, 'resistance': 80}),
        action: InteractionPattern.openQuestion,
      ));
      final alignedDelta =
          aligned.deltas.firstWhere((d) => d.axis == 'resistance').deltaMillis;

      // Mismatched: resistance is low.
      final mismatched = resolver.resolve(const TurnInput(
        rulesetVersion: '0.1.0',
        manifest: manifest,
        state: SimState(
            seed: 7, axes: {'trust': 30, 'agitation': 45, 'resistance': 10}),
        action: InteractionPattern.openQuestion,
      ));
      final mismatchedDelta = mismatched.deltas
          .firstWhere((d) => d.axis == 'resistance')
          .deltaMillis;

      // Aligned disclosing should crack defense more (more negative delta).
      expect(alignedDelta, lessThan(mismatchedDelta));
    });

    test('Manipulative partitions by trust state', () {
      // Low trust -> derangement: trauma rises.
      final lowTrust = resolver.resolve(const TurnInput(
        rulesetVersion: '0.1.0',
        manifest: manifest,
        state: SimState(
            seed: 3, axes: {'trust': 20, 'agitation': 45, 'resistance': 25}),
        action: InteractionPattern.reframe,
      ));
      expect(lowTrust.nextState.axes['trauma'], greaterThan(0));

      // High trust -> success: resistance drops and trust rises.
      final highTrust = resolver.resolve(const TurnInput(
        rulesetVersion: '0.1.0',
        manifest: manifest,
        state: SimState(
            seed: 3, axes: {'trust': 80, 'agitation': 45, 'resistance': 60}),
        action: InteractionPattern.reframe,
      ));
      expect(highTrust.nextState.axes['resistance'], lessThan(60));
      expect(highTrust.nextState.axes['trust'], greaterThan(80));
    });

    test('Transference Spike reclassifies Relatable as Manipulative failure',
        () {
      final output = resolver.resolve(const TurnInput(
        rulesetVersion: '0.1.0',
        manifest: manifest,
        state: SimState(
          seed: 5,
          axes: {'trust': 30, 'agitation': 80, 'resistance': 25, 'trauma': 75},
        ),
        action: InteractionPattern.validate,
      ));
      // The Relatable play should resolve as Manipulative under high trauma.
      expect(output.deltas.first.cardType, CardType.manipulative);
      expect(output.deltas.first.cardSignature, CardSignature.gambit);
    });

    test('is byte-identical for fixed state + action + seed', () {
      final a = resolver.resolve(const TurnInput(
        rulesetVersion: '0.1.0',
        manifest: manifest,
        state: SimState(
            seed: 9, axes: {'trust': 30, 'agitation': 45, 'resistance': 25}),
        action: InteractionPattern.setBoundary,
      ));
      final b = resolver.resolve(const TurnInput(
        rulesetVersion: '0.1.0',
        manifest: manifest,
        state: SimState(
            seed: 9, axes: {'trust': 30, 'agitation': 45, 'resistance': 25}),
        action: InteractionPattern.setBoundary,
      ));
      expect(a.toCanonicalBytes(), equals(b.toCanonicalBytes()));
    });
  });
}
