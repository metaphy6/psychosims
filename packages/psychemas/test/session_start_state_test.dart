import 'package:psychemas/psychemas.dart';
import 'package:test/test.dart';

void main() {
  group('SessionStartState', () {
    test('round-trips through canonical JSON with loadout + controllers', () {
      const state = SessionStartState(
        loadout: Loadout(cardIds: ['open_question', 'validate'], slotCap: 6),
        library: CardLibrary(ownedCardIds: {'open_question', 'validate'}),
        controllers: TherapyControllerSettings(
          focus: FocusAxis.workspace,
          emotionalDelivery: EmotionalDelivery.warm,
        ),
        initialAxes: {'trust': 30, 'agitation': 45},
        rootSeed: 42,
      );

      final bytes = state.toCanonicalBytes();
      final decoded = SessionStartState.fromJson(
        CanonicalJson.decode(bytes) as Map<String, Object?>,
      );
      expect(decoded, equals(state));
    });
  });
}
