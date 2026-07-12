import 'dart:convert';
import 'dart:io';

import 'package:psychemas/psychemas.dart';

/// Typed API-client seam for all remote calls.
///
/// This is a stub. The real client will add auth-token injection from secure
/// storage, refresh, retries, offline queueing, and idempotency keys per
/// `docs/code/NETWORKING.md`.
class ApiClient {
  ApiClient({required this.baseUrl, this.httpClient});

  final String baseUrl;
  final HttpClient? httpClient;

  Future<SessionReceipt> submitReceipt(SessionReceipt receipt) async {
    final client = httpClient ?? HttpClient();
    final request = await client.postUrl(Uri.parse('$baseUrl/receipts'));
    request.headers.contentType = ContentType.json;
    request.write(jsonEncode(receipt.toJson()));
    final response = await request.close();
    if (response.statusCode >= 200 && response.statusCode < 300) {
      final body = await response.transform(utf8.decoder).join();
      return SessionReceipt.fromJson(
        jsonDecode(body) as Map<String, Object?>,
      );
    }
    throw ApiException(
      statusCode: response.statusCode,
      message: 'Receipt submission failed',
    );
  }
}

class ApiException implements Exception {
  ApiException({required this.statusCode, required this.message});
  final int statusCode;
  final String message;

  @override
  String toString() => 'ApiException($statusCode): $message';
}
