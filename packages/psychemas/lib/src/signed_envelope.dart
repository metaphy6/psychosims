import 'dart:convert';

/// Exact signed bytes are copied once and never parsed/reserialized for transport.
/// Standard base64 is the wire format; bounded legacy byte arrays are read-only
/// compatibility with older local queues, never implicit account authorization.
class SignedEnvelope {
  SignedEnvelope({
    required List<int> canonicalReceiptBytes,
    required List<int> signature,
    required this.suiteId,
    required this.signingKeyId,
  })  : canonicalReceiptBytes = _bytes(canonicalReceiptBytes, maxReceiptBytes),
        signature = _bytes(signature, signatureBytes, exact: signatureBytes) {
    if (suiteId != 'ed25519-v1' ||
        signingKeyId.isEmpty ||
        signingKeyId.length > 256) {
      throw const FormatException('Invalid signing metadata');
    }
  }

  static const maxReceiptBytes = 131072;
  static const signatureBytes = 64;
  final List<int> canonicalReceiptBytes;
  final List<int> signature;
  final String suiteId;
  final String signingKeyId;

  Map<String, Object?> toJson() => {
        'canonical_receipt_bytes': base64Encode(canonicalReceiptBytes),
        'signature': base64Encode(signature),
        'suite_id': suiteId,
        'signing_key_id': signingKeyId,
      };

  factory SignedEnvelope.fromJson(Map<String, Object?> json) {
    if (json['suite_id'] is! String || json['signing_key_id'] is! String) {
      throw const FormatException('Invalid signing metadata');
    }
    return SignedEnvelope(
      canonicalReceiptBytes:
          _bytes(json['canonical_receipt_bytes'], maxReceiptBytes),
      signature:
          _bytes(json['signature'], signatureBytes, exact: signatureBytes),
      suiteId: json['suite_id'] as String,
      signingKeyId: json['signing_key_id'] as String,
    );
  }

  static List<int> _bytes(Object? value, int max, {int? exact}) {
    if (value is String) {
      if (value.length > ((max + 2) ~/ 3) * 4 ||
          !RegExp(r'^[A-Za-z0-9+/]*={0,2}$').hasMatch(value) ||
          value.length % 4 != 0) {
        throw const FormatException('Invalid encoded bytes');
      }
      final decoded = base64Decode(value);
      if (base64Encode(decoded) != value) {
        throw const FormatException('Noncanonical base64');
      }
      value = decoded;
    }
    if (value is! List ||
        value.isEmpty ||
        value.length > max ||
        (exact != null && value.length != exact) ||
        value.any((b) => b is! int || b < 0 || b > 255)) {
      throw const FormatException('Invalid byte field');
    }
    return List<int>.unmodifiable(value.cast<int>());
  }
}
