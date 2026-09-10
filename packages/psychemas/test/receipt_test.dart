import 'package:psychemas/psychemas.dart';
import 'package:test/test.dart';

void main() {
  group('SessionReceipt', () {
    const receipt = SessionReceipt(
      id: 'r-1',
      rulesetVersion: '0.1.0',
      patientId: 'p-1',
      idempotencyKey: 'idemp-1',
      correlationId: 'corr-1',
      turnCount: 3,
      startState: {'seed': 42, 'trust_score': 30},
      actions: [InteractionPattern.openQuestion, InteractionPattern.validate],
      deltas: [
        StructuredDelta(
          rulesetVersion: '0.1.0',
          axis: StateAxis.trust,
          deltaMillis: 5,
          reasonKey: 'reason.open_question',
          cardType: CardType.disclosing,
          cardSignature: CardSignature.breaker,
          contextFit: ContextFit.aligned,
        ),
      ],
    );

    test('round-trips through JSON with typed actions and deltas', () {
      final json = receipt.toJson();
      final restored = SessionReceipt.fromJson(json);
      expect(restored, equals(receipt));
      expect(restored.actions.first, equals(InteractionPattern.openQuestion));
      expect(restored.deltas.first.axis, equals(StateAxis.trust));
    });

    test('preserves additive typed ledger events for validation', () {
      final wire = {
        ...receipt.toJson(),
        'ledger_events': [
          const LedgerEvent(
            kind: 'fixture',
            idempotencyKey: 'event',
            timestampSeconds: 1,
            currency: CurrencyType.xp,
            amountMicros: 1000000,
            reasonKey: 'fixture',
          ).toJson()
        ]
      };
      final parsed = SessionReceipt.fromJson(wire);
      expect(parsed.ledgerEvents.single.currency, CurrencyType.xp);
      expect(parsed.toJson()['ledger_events'], wire['ledger_events']);
      expect(receipt.toJson().containsKey('ledger_events'), isFalse);
    });

    test('canonical bytes are deterministic', () {
      final a = receipt.toCanonicalBytes();
      final b = receipt.toCanonicalBytes();
      expect(a, equals(b));
    });

    test('carries idempotency key and correlation id', () {
      expect(receipt.idempotencyKey, equals('idemp-1'));
      expect(receipt.correlationId, equals('corr-1'));
    });
  });
}
