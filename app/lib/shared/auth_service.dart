import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:psychemas/psychemas.dart';
import 'api_client.dart';
import 'secure_storage.dart';

/// Tokens and the in-flight refresh identity share one secure atomic record.
class AuthService {
  AuthService(
      {required this.api,
      required SecretStorage storage,
      DateTime Function()? now})
      : storage = ScopedSecretStorage(storage,
            'origin.${sha256.convert(utf8.encode(Uri.parse(api.baseUrl).origin))}'),
        _now = now ?? DateTime.now;
  final ApiClient api;
  final SecretStorage storage;
  final DateTime Function() _now;
  String get _scope => '${storage.scope}.auth';
  static const _key = 'auth';
  Future<Map<String, Object?>> _read() async {
    final raw = await storage.read(_key);
    if (raw == null) return {};
    if (raw.length > 65536) {
      throw const FormatException('Invalid authentication record');
    }
    return jsonDecode(raw) as Map<String, Object?>;
  }

  Future<AuthPair?> currentSession() => SerialOperations.run(_scope, () async {
        final record = await _read();
        return record['pair'] == null
            ? null
            : AuthPair.fromJson(record['pair'] as Map<String, Object?>);
      });
  Future<void> installPairForVerifiedExchange(Map<String, Object?> json,
          {String? expectedOAuthExchange}) =>
      SerialOperations.run(_scope, () async {
        final pair = AuthPair.fromJson(json);
        if (expectedOAuthExchange != null) {
          final raw = await storage.read('oauth');
          if (raw == null ||
              (jsonDecode(raw) as Map<String, Object?>)['exchange_id'] !=
                  expectedOAuthExchange) {
            throw const ApiException(
                statusCode: 401, kind: 'oauth_state_missing');
          }
        }
        await storage.write(_key, jsonEncode({'pair': pair.toJson()}));
        await storage.delete('oauth');
      });
  Future<AuthPair> signIn(
          {required String provider,
          required String idToken,
          required String nonce}) =>
      SerialOperations.run(_scope, () async {
        final response = await api.request('POST', '/v1/auth/id-token',
            idempotencyKey: ApiClient.newId(),
            body: {'provider': provider, 'id_token': idToken, 'nonce': nonce});
        final pair = AuthPair.fromJson(response.body);
        await storage.write(_key, jsonEncode({'pair': pair.toJson()}));
        return pair;
      });
  Future<String> accessToken(
          {bool forceRefresh = false, String? rejectedAccessToken}) =>
      SerialOperations.run(_scope, () async {
        final record = await _read();
        if (record['pair'] == null) {
          throw const ApiException(statusCode: 401, kind: 'signed_out');
        }
        final pair = AuthPair.fromJson(record['pair'] as Map<String, Object?>);
        if ((!forceRefresh ||
                (rejectedAccessToken != null &&
                    pair.accessToken != rejectedAccessToken)) &&
            record['refresh_key'] == null &&
            pair.accessExpiresAt
                .isAfter(_now().toUtc().add(const Duration(seconds: 30)))) {
          return pair.accessToken;
        }
        if (!pair.refreshExpiresAt.isAfter(_now().toUtc())) {
          throw const ApiException(statusCode: 401, kind: 'session_expired');
        }
        final refreshKey =
            record['refresh_key'] as String? ?? ApiClient.newId('refresh');
        if (record['refresh_key'] == null) {
          record['refresh_key'] = refreshKey;
          await storage.write(_key, jsonEncode(record));
        }
        final response = await api.request('POST', '/v1/auth/refresh',
            idempotencyKey: refreshKey,
            body: {'refresh_token': pair.refreshToken});
        final next = AuthPair.fromJson(response.body);
        if (next.accountId != pair.accountId) {
          throw const ApiException(statusCode: 401, kind: 'account_mismatch');
        }
        await storage.write(_key, jsonEncode({'pair': next.toJson()}));
        return next.accessToken;
      });
  Future<ApiResponse> authenticated(String method, String path,
      {Map<String, Object?>? body,
      String? idempotencyKey,
      String? etag,
      String? accountId}) async {
    final initial = await currentSession();
    if (initial == null ||
        (accountId != null && initial.accountId != accountId)) {
      throw const ApiException(statusCode: 401, kind: 'account_mismatch');
    }
    var token = await accessToken();
    for (var attempt = 0; attempt < 2; attempt++) {
      if ((await currentSession())?.accountId != initial.accountId) {
        throw const ApiException(statusCode: 401, kind: 'account_mismatch');
      }
      try {
        final response = await api.request(method, path,
            body: body,
            idempotencyKey: idempotencyKey,
            bearer: token,
            etag: etag);
        if ((await currentSession())?.accountId != initial.accountId) {
          throw const ApiException(statusCode: 401, kind: 'account_mismatch');
        }
        return response;
      } on ApiException catch (error) {
        if (error.statusCode != 401 || attempt != 0) rethrow;
        // If another request already refreshed, reuse its pair instead of
        // rotating again after a response from the old access token.
        final latest = await currentSession();
        token = await accessToken(
            forceRefresh: latest?.accessToken == token,
            rejectedAccessToken: token);
      }
    }
    throw StateError('Unreachable authentication retry');
  }

  Future<void> flushLogouts() => SerialOperations.run(_scope, _flushLogouts);
  Future<void> _flushLogouts() async {
    final raw = await storage.read('pending_logouts');
    if (raw == null) return;
    if (raw.length > 65536) {
      throw const FormatException('Invalid revocation obligations');
    }
    final pending = (jsonDecode(raw) as List).cast<Map<String, Object?>>();
    while (pending.isNotEmpty) {
      final entry = pending.first;
      try {
        var pair = AuthPair.fromJson(entry['pair'] as Map<String, Object?>);
        if (!pair.accessExpiresAt
            .isAfter(_now().toUtc().add(const Duration(seconds: 30)))) {
          if (pair.refreshExpiresAt.isAfter(_now().toUtc())) {
            try {
              final refreshed = await api.request('POST', '/v1/auth/refresh',
                  body: {'refresh_token': pair.refreshToken},
                  idempotencyKey: entry['refresh_key'] as String);
              final next = AuthPair.fromJson(refreshed.body);
              if (next.accountId != pair.accountId) {
                throw const ApiException(
                    statusCode: 409, kind: 'account_mismatch');
              }
              pair = next;
              entry['pair'] = pair.toJson();
              await storage.write('pending_logouts', jsonEncode(pending));
            } on ApiException catch (error) {
              // A consumed refresh does not establish family revocation. The
              // server accepts this original signed access token for logout,
              // including after its access expiry.
              if (error.statusCode != 401) rethrow;
            }
          }
        }
        await api.request('POST', '/v1/auth/logout',
            body: {},
            bearer: pair.accessToken,
            idempotencyKey: entry['idempotency_key'] as String);
      } on ApiException catch (error) {
        if (error.retryable) return;
        if (error.statusCode != 401) rethrow;
      }
      pending.removeAt(0);
      if (pending.isEmpty) {
        await storage.delete('pending_logouts');
      } else {
        await storage.write('pending_logouts', jsonEncode(pending));
      }
    }
  }

  Future<void> logout() => SerialOperations.run(_scope, () async {
        final record = await _read();
        if (record['pair'] == null) {
          await storage.delete('oauth');
          await _flushLogouts();
          return;
        }
        final pair = AuthPair.fromJson(record['pair'] as Map<String, Object?>);
        final raw = await storage.read('pending_logouts');
        final pending = raw == null ? <Object?>[] : jsonDecode(raw) as List;
        if (pending.length >= 16) {
          throw StateError(
              'Connect to finish previous sign-outs before switching again');
        }
        pending.add({
          'pair': pair.toJson(),
          'refresh_key':
              record['refresh_key'] ?? ApiClient.newId('logout_refresh'),
          'idempotency_key': ApiClient.newId('logout')
        });
        // The revocation obligation survives even if deletion or network I/O fails.
        await storage.write('pending_logouts', jsonEncode(pending));
        await storage.delete(_key);
        await storage.delete('oauth');
        await _flushLogouts();
      });
}
