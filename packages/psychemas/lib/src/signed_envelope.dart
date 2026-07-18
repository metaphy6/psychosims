import 'package:meta/meta.dart';

/// The 3.0 signed transport envelope that wraps a canonical `SessionReceipt`.
///
/// The exact bytes in [canonicalReceiptBytes] are what the signature is
/// computed over on the client and verified over on the server (verify-in-
/// place). This shape travels on the wire and in the durable offline queue.
@immutable
class SignedEnvelope {
  const SignedEnvelope({
    required this.canonicalReceiptBytes,
    required this.signature,
    required this.suiteId,
    required this.signingKeyId,
  });

  final List<int> canonicalReceiptBytes;
  final List<int> signature;
  final String suiteId;
  final String signingKeyId;

  Map<String, Object?> toJson() => {
        'canonical_receipt_bytes': canonicalReceiptBytes,
        'signature': signature,
        'suite_id': suiteId,
        'signing_key_id': signingKeyId,
      };

  factory SignedEnvelope.fromJson(Map<String, Object?> json) => SignedEnvelope(
        canonicalReceiptBytes:
            (json['canonical_receipt_bytes'] as List<dynamic>).cast<int>(),
        signature: (json['signature'] as List<dynamic>).cast<int>(),
        suiteId: json['suite_id'] as String,
        signingKeyId: json['signing_key_id'] as String,
      );
}
