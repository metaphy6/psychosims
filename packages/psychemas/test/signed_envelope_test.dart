import 'dart:convert';

import 'package:psychemas/psychemas.dart';
import 'package:test/test.dart';

void main() {
  final bytes = utf8.encode('{"id":"r_fixture"}');
  final signature = List<int>.generate(64, (i) => i);
  Map<String, Object?> json(Object payload, Object sig) => {
        'canonical_receipt_bytes': payload,
        'signature': sig,
        'suite_id': 'ed25519-v1',
        'signing_key_id': 'key_fixture',
      };

  test('writes standard base64 and accepts server wire representation', () {
    final envelope = SignedEnvelope(
      canonicalReceiptBytes: bytes,
      signature: signature,
      suiteId: 'ed25519-v1',
      signingKeyId: 'key_fixture',
    );
    expect(
        envelope.toJson(), json(base64Encode(bytes), base64Encode(signature)));
    final decoded = SignedEnvelope.fromJson(envelope.toJson());
    expect(decoded.canonicalReceiptBytes, bytes);
    expect(decoded.signature, signature);
  });

  test('legacy arrays remain readable but signed bytes are immutable', () {
    final mutable = List<int>.of(bytes);
    final mutableSignature = List<int>.of(signature);
    final envelope = SignedEnvelope.fromJson(json(mutable, mutableSignature));
    mutable[0] = 0;
    mutableSignature[0] = 255;
    expect(envelope.canonicalReceiptBytes, bytes);
    expect(envelope.signature, signature);
    expect(() => envelope.signature[0] = 42, throwsUnsupportedError);
  });

  test('rejects invalid bytes, invalid signature length and oversized payload',
      () {
    for (final payload in [
      <int>[-1],
      <int>[256],
      <double>[1.5],
      '%%%'
    ]) {
      expect(() => SignedEnvelope.fromJson(json(payload, signature)),
          throwsFormatException);
    }
    expect(() => SignedEnvelope.fromJson(json(bytes, [1, 2])),
        throwsFormatException);
    expect(
        () => SignedEnvelope.fromJson(json(List.filled(131073, 0), signature)),
        throwsFormatException);
  });
}
