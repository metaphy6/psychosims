import 'package:psychemas/psychemas.dart';
import 'package:psycore/psycore.dart';
import 'package:test/test.dart';

void main() {
  group('Card style frame', () {
    test('returns deterministic voice token for card + archetype', () {
      final frame =
          resolveCardStyleFrame(CardType.disclosing, StyleArchetype.vexa);
      expect(frame, equals('vexa_disclosing_voice'));
    });

    test('returns a presentation form token for a card type', () {
      final form = resolveCardPresentationForm(CardType.relatable, seed: 42);
      expect(form, isIn(['warm_paragraph', 'brief_validation', 'gesture']));
    });

    test('presentation form is deterministic for the same seed', () {
      expect(
        resolveCardPresentationForm(CardType.manipulative, seed: 7),
        equals(resolveCardPresentationForm(CardType.manipulative, seed: 7)),
      );
    });
  });
}
