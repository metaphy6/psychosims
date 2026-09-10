import 'dart:convert';
import 'dart:typed_data';
import 'package:cryptography/cryptography.dart';
import 'package:psychemas/psychemas.dart';
import 'api_client.dart';
import 'secure_storage.dart';

abstract interface class DeviceKeyStore {
  Future<String> get signingKeyId;
  Future<Uint8List> get publicKey;
  Future<SignedEnvelope> signReceipt(SessionReceipt receipt);
}

typedef RecoverDevice = Future<Map<String, Object?>> Function(
    List<int> publicKey, String requestId, String replacesKeyId);

typedef CertifyDevice = Future<Map<String, Object?>> Function(
    List<int> publicKey, String requestId);

/// Per-account Ed25519 seed and certificate live only in platform secure storage.
/// Pending provisioning identity is persisted before the network call, allowing
/// a lost acknowledgment to retry with the same key and idempotency key.
class SecureDeviceKeyStore implements DeviceKeyStore {
  SecureDeviceKeyStore(
      {required this.accountId,
      required this.storage,
      required this.certify,
      this.recover});
  final String accountId;
  final SecretStorage storage;
  final CertifyDevice certify;
  final RecoverDevice? recover;
  final _algorithm = Ed25519();
  String get _key => 'device.${base64Url.encode(utf8.encode(accountId))}';
  String get _scope => '${storage.scope}.$_key';

  Future<Map<String, Object?>> _record() async {
    final raw = await storage.read(_key);
    if (raw == null) throw StateError('Device key is not provisioned');
    if (raw.length > 8192) throw const FormatException('Invalid device record');
    final record = jsonDecode(raw) as Map<String, Object?>;
    if (record['account_id'] != accountId) {
      throw const FormatException('Device account mismatch');
    }
    return record;
  }

  Future<SimpleKeyPair> _pair(Map<String, Object?> record) async {
    final seed = base64Decode(record['seed'] as String);
    if (seed.length != 32) throw const FormatException('Invalid signing seed');
    return _algorithm.newKeyPairFromSeed(seed);
  }

  Future<void> ensureCertified() => SerialOperations.run(_scope, () async {
        Map<String, Object?> record;
        if (await storage.read(_key) == null) {
          final pair = await _algorithm.newKeyPair();
          final seed = await pair.extractPrivateKeyBytes();
          record = {
            'account_id': accountId,
            'seed': base64Encode(seed),
            'request_id': ApiClient.newId('device')
          };
          await storage.write(_key, jsonEncode(record));
        } else {
          record = await _record();
        }
        if (record['recovery'] != null) {
          await _finishRecovery(record);
          return;
        }
        if (record['certificate'] != null) return;
        final pair = await _pair(record);
        final public = (await pair.extractPublicKey()).bytes;
        final certificate =
            await certify(public, record['request_id'] as String);
        _validateCertificate(certificate, public);
        record['certificate'] = certificate;
        await storage.write(_key, jsonEncode(record));
      });
  void _validateCertificate(
      Map<String, Object?> certificate, List<int> public) {
    if (certificate['account_id'] != accountId ||
        certificate['suite_id'] != 'ed25519-v1' ||
        certificate['public_key'] != base64Encode(public) ||
        certificate['id'] is! String ||
        (certificate['id'] as String).isEmpty) {
      throw const FormatException(
          'Certificate does not match local key and account');
    }
  }

  Future<void> recoverKey() => SerialOperations.run(_scope, () async {
        if (recover == null) throw StateError('Device recovery is unavailable');
        final record = await _record();
        if (record['recovery'] == null) {
          final certificate = record['certificate'] as Map<String, Object?>?;
          if (certificate == null) {
            throw StateError('No certified key to replace');
          }
          final pair = await _algorithm.newKeyPair();
          record['recovery'] = {
            'account_id': accountId,
            'seed': base64Encode(await pair.extractPrivateKeyBytes()),
            'request_id': ApiClient.newId('recover'),
            'replaces_key_id': certificate['id']
          };
          await storage.write(_key, jsonEncode(record));
        }
        await _finishRecovery(record);
      });
  Future<void> _finishRecovery(Map<String, Object?> record) async {
    if (recover == null) throw StateError('Device recovery is unavailable');
    final pending = record['recovery'] as Map<String, Object?>;
    final public = (await (await _pair(pending)).extractPublicKey()).bytes;
    final result = await recover!(public, pending['request_id'] as String,
        pending['replaces_key_id'] as String);
    final certificate = result['key'] as Map<String, Object?>;
    _validateCertificate(certificate, public);
    if (result['revoked_key_id'] != pending['replaces_key_id'] ||
        certificate['id'] == pending['replaces_key_id']) {
      throw const FormatException('Recovery did not replace the requested key');
    }
    await storage.write(
        _key,
        jsonEncode({
          'account_id': accountId,
          'seed': pending['seed'],
          'request_id': pending['request_id'],
          'certificate': certificate
        }));
  }

  @override
  Future<String> get signingKeyId => SerialOperations.run(_scope, () async {
        final record = await _record();
        if (record['recovery'] != null) {
          throw StateError('Device recovery is pending');
        }
        final cert = record['certificate'] as Map<String, Object?>?;
        if (cert == null) {
          throw StateError('Device key has no server certificate');
        }
        return cert['id'] as String;
      });
  @override
  Future<Uint8List> get publicKey => SerialOperations.run(_scope, () async {
        final pair = await _pair(await _record());
        return Uint8List.fromList((await pair.extractPublicKey()).bytes);
      });
  @override
  Future<SignedEnvelope> signReceipt(SessionReceipt receipt) =>
      SerialOperations.run(_scope, () async {
        final record = await _record();
        if (record['recovery'] != null) {
          throw StateError('Device recovery is pending');
        }
        final cert = record['certificate'] as Map<String, Object?>?;
        if (cert == null) {
          throw StateError('Device key has no server certificate');
        }
        final bytes = receipt.toCanonicalBytes();
        final signature =
            await _algorithm.sign(bytes, keyPair: await _pair(record));
        return SignedEnvelope(
            canonicalReceiptBytes: bytes,
            signature: signature.bytes,
            suiteId: 'ed25519-v1',
            signingKeyId: cert['id'] as String);
      });
}

/// Test fixture only. It uses actual Ed25519, never placeholder signatures.
/// Production injection exclusively creates SecureDeviceKeyStore.
class MemoryDeviceKeyStore implements DeviceKeyStore {
  MemoryDeviceKeyStore(
      {this.keyId = 'test-device-key-1',
      this.suiteId = 'ed25519-v1',
      List<int>? seed})
      : _pair = Ed25519()
            .newKeyPairFromSeed(seed ?? List<int>.generate(32, (i) => i));
  final String keyId, suiteId;
  final Future<SimpleKeyPair> _pair;
  @override
  Future<String> get signingKeyId async => keyId;
  @override
  Future<Uint8List> get publicKey async =>
      Uint8List.fromList((await (await _pair).extractPublicKey()).bytes);
  @override
  Future<SignedEnvelope> signReceipt(SessionReceipt receipt) async {
    final bytes = receipt.toCanonicalBytes();
    final signature = await Ed25519().sign(bytes, keyPair: await _pair);
    return SignedEnvelope(
        canonicalReceiptBytes: bytes,
        signature: signature.bytes,
        suiteId: suiteId,
        signingKeyId: keyId);
  }
}
