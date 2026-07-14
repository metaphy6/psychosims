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
    const loadout = Loadout(
      cardIds: ['open_question', 'validate', 'reframe', 'set_boundary'],
      slotCap: 6,
    );
    const library = CardLibrary(
      ownedCardIds: {'open_question', 'validate', 'reframe', 'set_boundary'},
    );

    TurnInput input(InteractionPattern action, SimState state) {
      return TurnInput(
        rulesetVersion: '0.1.0',
        manifest: manifest,
        state: state,
        action: action,
        loadout: loadout,
        library: library,
      );
    }

    test('maps PoC interaction patterns to production card types', () {
      final cards = manifest.resolvedCards;
      expect(cards[0].type, CardType.disclosing); // openQuestion
      expect(cards[1].type, CardType.relatable); // validate
      expect(cards[2].type, CardType.manipulative); // reframe
      expect(cards[3].type, CardType.postponing); // setBoundary
    });

    test('records card type, signature and context-fit in deltas', () {
      final output = resolver.resolve(input(
        InteractionPattern.openQuestion,
        const SimState(
            seed: 1,
            trustScore: 30,
            agitationLevel: 45,
            activeDefense: DefenseState.guarded),
      ));
      expect(output.deltas, isNotEmpty);
      for (final delta in output.deltas) {
        expect(delta.cardType, CardType.disclosing);
        expect(delta.cardSignature, CardSignature.breaker);
        expect(delta.contextFit, isNotNull);
      }
    });

    test('Disclosing aligned cracks defense; mismatched does not', () {
      // Aligned: resistance is high (defense crackable).
      final aligned = resolver.resolve(input(
        InteractionPattern.openQuestion,
        const SimState(
            seed: 7,
            trustScore: 30,
            agitationLevel: 45,
            activeDefense: DefenseState.rigid),
      ));
      final alignedDefenseDelta = aligned.deltas
          .where((d) => d.axis == StateAxis.activeDefense)
          .fold(0, (sum, d) => sum + d.deltaMillis);

      // Mismatched: resistance is already low; no defense change should occur.
      final mismatched = resolver.resolve(input(
        InteractionPattern.openQuestion,
        const SimState(
            seed: 7,
            trustScore: 30,
            agitationLevel: 45,
            activeDefense: DefenseState.none),
      ));
      final mismatchedDefenseDelta = mismatched.deltas
          .where((d) => d.axis == StateAxis.activeDefense)
          .fold(0, (sum, d) => sum + d.deltaMillis);

      expect(alignedDefenseDelta, lessThan(0));
      expect(mismatchedDefenseDelta, equals(0));
    });

    test('Manipulative partitions by trust state', () {
      // Low trust -> derangement: trauma rises.
      final lowTrust = resolver.resolve(input(
        InteractionPattern.reframe,
        const SimState(
            seed: 3,
            trustScore: 20,
            agitationLevel: 45,
            activeDefense: DefenseState.guarded),
      ));
      expect(lowTrust.nextState.trauma, greaterThan(0));

      // High trust -> success: resistance drops and trust rises.
      final highTrust = resolver.resolve(input(
        InteractionPattern.reframe,
        const SimState(
            seed: 3,
            trustScore: 80,
            agitationLevel: 45,
            activeDefense: DefenseState.rigid),
      ));
      expect(highTrust.nextState.activeDefense.index,
          lessThan(DefenseState.rigid.index));
      expect(highTrust.nextState.trustScore, greaterThan(80));
    });

    test('Transference Spike reclassifies Relatable as Manipulative failure',
        () {
      final output = resolver.resolve(input(
        InteractionPattern.validate,
        const SimState(
          seed: 5,
          trustScore: 30,
          agitationLevel: 80,
          activeDefense: DefenseState.guarded,
          trauma: 75,
        ),
      ));
      // The Relatable play should resolve as Manipulative under high trauma.
      expect(output.deltas.first.cardType, CardType.manipulative);
      expect(output.deltas.first.cardSignature, CardSignature.gambit);
    });

    test('is byte-identical for fixed state + action + seed', () {
      final a = resolver.resolve(input(
        InteractionPattern.setBoundary,
        const SimState(
            seed: 9,
            trustScore: 30,
            agitationLevel: 45,
            activeDefense: DefenseState.guarded),
      ));
      final b = resolver.resolve(input(
        InteractionPattern.setBoundary,
        const SimState(
            seed: 9,
            trustScore: 30,
            agitationLevel: 45,
            activeDefense: DefenseState.guarded),
      ));
      expect(a.toCanonicalBytes(), equals(b.toCanonicalBytes()));
    });
  });
}
