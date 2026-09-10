// Generates an openly published, deterministic TEST ONLY signing vector.
import 'dart:convert';
import 'dart:io';
import 'package:cryptography/cryptography.dart';
import 'package:crypto/crypto.dart' as hashes;
import 'package:psychemas/psychemas.dart';

Future<void> main() async {
  final seed = List<int>.generate(32, (i) => i);
  final algorithm = Ed25519();
  final key = await algorithm.newKeyPairFromSeed(seed);
  final receipt = SessionReceipt(
      id: 'session_fixture_v1',
      rulesetVersion: '0.1.0',
      patientId: 'patient_fixture',
      idempotencyKey: 'rcp_fixture_v1',
      correlationId: 'psy_fixture_v1',
      turnCount: 1,
      startState: const SessionStartState(
              loadout:
                  Loadout(cardIds: ['core.disclosing.breaker'], slotCap: 6),
              library: CardLibrary(ownedCardIds: {'core.disclosing.breaker'}),
              controllers: TherapyControllerSettings(),
              initialAxes: {
                'trust': 40,
                'agitation': 10,
                'resistance': 35,
                'trauma': 0,
                'session_progress': 0
              },
              rootSeed: 42)
          .toJson(),
      actions: const [InteractionPattern.openQuestion],
      deltas: const []);
  final bytes = receipt.toCanonicalBytes();
  final signature = await algorithm.sign(bytes, keyPair: key);
  final fixture = {
    'purpose':
        'PUBLIC TEST VECTOR ONLY. Never use this seed in an application.',
    'test_seed_hex':
        seed.map((b) => b.toRadixString(16).padLeft(2, '0')).join(),
    'public_key': base64Encode((await key.extractPublicKey()).bytes),
    'wire_sha256': hashes.sha256.convert(bytes).toString(),
    'receipt': receipt.toJson(),
    'envelope': SignedEnvelope(
            canonicalReceiptBytes: bytes,
            signature: signature.bytes,
            suiteId: 'ed25519-v1',
            signingKeyId: 'key_fixture_v1')
        .toJson()
  };
  await File('../test_fixtures/receipts/signed_ed25519_v1.json').writeAsString(
      '${const JsonEncoder.withIndent('  ').convert(fixture)}\n');
}
