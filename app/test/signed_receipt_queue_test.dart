import 'package:flutter_test/flutter_test.dart';
import 'package:psychemas/psychemas.dart';
import 'package:psychosims/shared/device_key_store.dart';
import 'package:psychosims/shared/signed_receipt_queue.dart';

SessionReceipt _receipt(String idempotencyKey) {
  final state = SessionStartState(
    loadout: const Loadout(cardIds: [], slotCap: 6),
    library: const CardLibrary(ownedCardIds: {}),
    controllers: const TherapyControllerSettings(
      focus: FocusAxis.balanced,
      emotionalDelivery: EmotionalDelivery.balanced,
    ),
    initialAxes: const {},
    rootSeed: 42,
  );
  return SessionReceipt(
    id: 'r-$idempotencyKey',
    schemaVersion: SessionReceipt.currentSchemaVersion,
    rulesetVersion: '0.1.0',
    patientId: 'p-1',
    idempotencyKey: idempotencyKey,
    correlationId: 'corr-$idempotencyKey',
    turnCount: 1,
    startState: state.toJson(),
    actions: const <InteractionPattern>[],
    deltas: const <StructuredDelta>[],
  );
}

void main() {
  test('enqueue signs receipt and drain applies exactly once', () async {
    final submitted = <String>[];
    final queue = SignedReceiptQueue(
      deviceKeyStore: MemoryDeviceKeyStore(),
      persistence: MemoryQueuePersistence(),
      retryPolicy: const RetryPolicy(maxAttempts: 0),
    );

    await queue.enqueue(_receipt('idem-1'));
    await queue.enqueue(_receipt('idem-2'));

    final cursor = await queue.drain((env) async {
      submitted.add(env.signingKeyId);
    });

    expect(cursor, equals('idem-2'));
    expect(submitted, hasLength(2));
  });

  test('resumed drain continues from cursor', () async {
    final persistence = MemoryQueuePersistence();
    final queue = SignedReceiptQueue(
      deviceKeyStore: MemoryDeviceKeyStore(),
      persistence: persistence,
      retryPolicy: const RetryPolicy(maxAttempts: 0),
    );

    await queue.enqueue(_receipt('idem-1'));
    await queue.enqueue(_receipt('idem-2'));
    await queue.enqueue(_receipt('idem-3'));

    // First drain fails after the second item.
    var calls = 0;
    await queue.drain((env) async {
      calls++;
      if (calls == 3) throw Exception('network');
    });

    expect(persistence.cursor, completion(equals('idem-2')));

    // Resume applies the third item only.
    final later = <SignedEnvelope>[];
    await queue.drain((env) async => later.add(env));
    expect(later, hasLength(1));
    expect(later.first.signingKeyId, equals('test-device-key-1'));
  });
}
