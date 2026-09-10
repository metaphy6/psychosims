import 'dart:convert';
import 'package:cryptography/cryptography.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:psychemas/psychemas.dart';
import 'package:psychosims/shared/device_key_store.dart';
import 'auth_service_test.dart' show TestSecrets;

void main() {
  test(
      'key replacement persists retry identity and resumes without resigning old receipts',
      () async {
    final storage = TestSecrets();
    var fail = true;
    final calls = <String>[];
    final publics = <String>[];
    SecureDeviceKeyStore store() => SecureDeviceKeyStore(
        accountId: 'a',
        storage: storage,
        certify: (public, request) async => {
              'id': 'old',
              'account_id': 'a',
              'public_key': base64Encode(public),
              'suite_id': 'ed25519-v1'
            },
        recover: (public, request, replaces) async {
          expect(replaces, 'old');
          calls.add(request);
          publics.add(base64Encode(public));
          if (fail) throw StateError('simulated lost acknowledgment');
          return {
            'revoked_key_id': 'old',
            'key': {
              'id': 'new',
              'account_id': 'a',
              'public_key': base64Encode(public),
              'suite_id': 'ed25519-v1'
            }
          };
        });
    final original = store();
    await original.ensureCertified();
    final oldPublic = await original.publicKey;
    await expectLater(original.recoverKey(), throwsStateError);
    fail = false;
    final restarted = store();
    await restarted.ensureCertified();
    expect(await restarted.signingKeyId, 'new');
    expect(await restarted.publicKey, isNot(oldPublic));
    expect(calls, hasLength(2));
    expect(calls.first, calls.last);
    expect(publics.first, publics.last);
  });

  test('device signs with real Ed25519 and persists certified key per account',
      () async {
    final storage = TestSecrets();
    var calls = 0;
    final key = SecureDeviceKeyStore(
        accountId: 'account-1',
        storage: storage,
        certify: (publicKey, requestId) async {
          calls++;
          return {
            'id': 'key-1',
            'account_id': 'account-1',
            'public_key': base64Encode(publicKey),
            'suite_id': 'ed25519-v1',
            'created_at': DateTime.now().toUtc().toIso8601String()
          };
        });
    await Future.wait([key.ensureCertified(), key.ensureCertified()]);
    expect(calls, 1);
    final envelope = await key.signReceipt(const SessionReceipt(
        id: 'r',
        rulesetVersion: '0.1.0',
        patientId: 'p',
        idempotencyKey: 'idem',
        correlationId: 'corr',
        turnCount: 0,
        startState: {},
        actions: [],
        deltas: []));
    expect(
        await Ed25519().verify(envelope.canonicalReceiptBytes,
            signature: Signature(envelope.signature,
                publicKey: SimplePublicKey(await key.publicKey,
                    type: KeyPairType.ed25519))),
        isTrue);
    final restarted = SecureDeviceKeyStore(
        accountId: 'account-1',
        storage: storage,
        certify: (_, __) => throw StateError('should not reprovision'));
    expect(await restarted.signingKeyId, 'key-1');
    final other = SecureDeviceKeyStore(
        accountId: 'account-2',
        storage: storage,
        certify: (_, __) => throw StateError('must provision separately'));
    await expectLater(other.signingKeyId, throwsStateError);
  });
  test('rejects certificate for another account or public key', () async {
    final store = SecureDeviceKeyStore(
        accountId: 'a',
        storage: TestSecrets(),
        certify: (key, id) async => {
              'id': 'key',
              'account_id': 'other',
              'public_key': base64Encode(key),
              'suite_id': 'ed25519-v1'
            });
    await expectLater(store.ensureCertified(), throwsFormatException);
  });
}
