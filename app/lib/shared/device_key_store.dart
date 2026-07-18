import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:psychemas/psychemas.dart';

/// Abstract seam for the client's per-device signing key.
///
/// Phase 3.5 requires the client to hold a per-device Ed25519 keypair in
/// platform secure storage (Keychain / Keystore / OS credential store), have
/// the server certify the public half, and sign every 3.0 envelope before it
/// enters the durable offline queue.
///
/// This interface is the seam; concrete implementations bind to the platform
/// secure-storage and crypto packages appropriate for each target.
abstract interface class DeviceKeyStore {
  /// The server-certified signing-key id for this device.
  Future<String> get signingKeyId;

  /// The public key bytes certified by the server.
  Future<Uint8List> get publicKey;

  /// Signs the canonical bytes of [receipt] and returns a [SignedEnvelope].
  Future<SignedEnvelope> signReceipt(SessionReceipt receipt);
}

/// A test-only [DeviceKeyStore] that produces deterministic placeholder
/// signatures without a real Ed25519 dependency.
///
/// Do not use in production; it exists so the queue seam and tests can run
/// without importing platform crypto packages in this repository slice.
class MemoryDeviceKeyStore implements DeviceKeyStore {
  MemoryDeviceKeyStore({
    this.keyId = 'test-device-key-1',
    this.suiteId = 'ed25519-v1',
  });

  final String keyId;
  final String suiteId;

  @override
  Future<String> get signingKeyId async => keyId;

  @override
  Future<Uint8List> get publicKey async => Uint8List.fromList(
        utf8.encode('public-key-$keyId'),
      );

  @override
  Future<SignedEnvelope> signReceipt(SessionReceipt receipt) async {
    final bytes = CanonicalJson.encode(receipt.toJson());
    // Placeholder: real implementations compute an Ed25519 signature over
    // the exact canonical bytes.
    final signature = _placeholderSignature(bytes, keyId);
    return SignedEnvelope(
      canonicalReceiptBytes: bytes,
      signature: signature,
      suiteId: suiteId,
      signingKeyId: keyId,
    );
  }

  List<int> _placeholderSignature(List<int> bytes, String keyId) {
    final seed = bytes.followedBy(utf8.encode(keyId)).toList();
    final random = Random(seed.fold<int>(0, (a, b) => a * 31 + b));
    return List<int>.generate(64, (_) => random.nextInt(256));
  }
}
