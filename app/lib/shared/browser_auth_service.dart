import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'package:app_links/app_links.dart';
import 'package:crypto/crypto.dart';
import 'package:psychemas/psychemas.dart';
import 'package:psyconfig/psyconfig.dart';
import 'package:url_launcher/url_launcher.dart';
import 'api_client.dart';
import 'auth_service.dart';
import 'secure_storage.dart';

abstract interface class OAuthBrowser {
  Future<Uri> authorize(Uri url, Uri redirect, Duration timeout);
}

/// Opens the system browser. Desktop loopback listeners bind only the explicitly
/// configured local interface. Mobile callbacks use OS-registered app links.
abstract interface class OAuthCallbackSource {
  Future<Uri?> initialCallback();
}

class PlatformOAuthBrowser implements OAuthBrowser, OAuthCallbackSource {
  @override
  Future<Uri?> initialCallback() => AppLinks().getInitialLink();
  @override
  Future<Uri> authorize(Uri url, Uri redirect, Duration timeout) async {
    final result = Completer<Uri>();
    HttpServer? server;
    StreamSubscription<Uri>? subscription;
    bool matches(Uri uri) =>
        uri.scheme == redirect.scheme &&
        uri.host == redirect.host &&
        uri.port == redirect.port &&
        uri.path == redirect.path;
    try {
      if (redirect.scheme == 'http' &&
          ['127.0.0.1', '::1', 'localhost'].contains(redirect.host)) {
        server = await HttpServer.bind(
            redirect.host == '::1'
                ? InternetAddress.loopbackIPv6
                : InternetAddress.loopbackIPv4,
            redirect.port,
            shared: false);
        server.listen((request) async {
          final target = redirect.replace(query: request.uri.query);
          if (request.method != 'GET' ||
              request.uri.path != redirect.path ||
              request.uri.toString().length > 16384) {
            request.response.statusCode = 404;
          } else if (!result.isCompleted) {
            request.response.headers.contentType = ContentType.text;
            request.response.headers.set('Cache-Control', 'no-store');
            request.response.headers
                .set('Content-Security-Policy', "default-src 'none'");
            request.response.write('Sign-in received. Return to Psychosims.');
            result.complete(target);
          }
          await request.response.close();
        });
      } else {
        subscription = AppLinks().uriLinkStream.listen((uri) {
          if (matches(uri) && !result.isCompleted) result.complete(uri);
        }, onError: (Object e, StackTrace st) {
          if (!result.isCompleted) result.completeError(e, st);
        });
      }
      if (!await launchUrl(url, mode: LaunchMode.externalApplication)) {
        throw const ApiException(statusCode: 0, kind: 'browser_unavailable');
      }
      return await result.future.timeout(timeout);
    } finally {
      await subscription?.cancel();
      await server?.close(force: true);
    }
  }
}

class BrowserAuthService {
  BrowserAuthService(
      {required this.auth, required this.network, OAuthBrowser? browser})
      : browser = browser ?? PlatformOAuthBrowser();
  final AuthService auth;
  final NetworkConfig network;
  final OAuthBrowser browser;
  bool get configured =>
      network.oauthChannel.isNotEmpty &&
      network.oauthRedirectUri.isNotEmpty &&
      network.oauthAuthorizationOrigins.isNotEmpty;
  String get _scope => '${auth.storage.scope}.oauth';
  Future<AuthPair> signIn(String provider) =>
      SerialOperations.run(_scope, () async {
        if (!configured) {
          throw const ApiException(
              statusCode: 0, kind: 'sign_in_not_configured');
        }
        if (!['google', 'apple'].contains(provider)) {
          throw ArgumentError('Unsupported identity provider');
        }
        final redirect = Uri.parse(network.oauthRedirectUri);
        final random = Random.secure();
        final verifier =
            base64UrlEncode(List.generate(32, (_) => random.nextInt(256)))
                .replaceAll('=', '');
        final challenge =
            base64UrlEncode(sha256.convert(utf8.encode(verifier)).bytes)
                .replaceAll('=', '');
        final response = await auth.api.request('POST', '/v1/auth/start',
            idempotencyKey: ApiClient.newId('oauth'),
            body: {
              'provider': provider,
              'channel': network.oauthChannel,
              'redirect_uri': redirect.toString(),
              'code_challenge': challenge,
              'code_challenge_method': 'S256'
            });
        final state = wireString(response.body, 'state', max: 4096);
        final expires = wireTime(response.body, 'expires_at');
        final authorization = Uri.parse(
            wireString(response.body, 'authorization_url', max: 16384));
        if (authorization.scheme != 'https' ||
            authorization.userInfo.isNotEmpty ||
            authorization.hasFragment ||
            !network.oauthAuthorizationOrigins.contains(authorization.origin) ||
            !expires.isAfter(DateTime.now().toUtc())) {
          throw const ApiException(
              statusCode: 0, kind: 'invalid_authorization_url');
        }
        final pending = <String, Object?>{
          'state': state,
          'verifier': verifier,
          'expires_at': expires.toIso8601String(),
          'redirect': redirect.toString(),
          'exchange_id': ApiClient.newId('exchange')
        };
        await auth.storage.write('oauth', jsonEncode(pending));
        final timeout = Duration(seconds: network.oauthStateTtlSeconds);
        final callback =
            await browser.authorize(authorization, redirect, timeout);
        return _complete(callback, pending);
      });
  Future<AuthPair> completeCallback(Uri callback) =>
      SerialOperations.run(_scope, () async {
        final raw = await auth.storage.read('oauth');
        if (raw == null || raw.length > 32768) {
          throw const ApiException(
              statusCode: 401, kind: 'oauth_state_missing');
        }
        return _complete(callback, jsonDecode(raw) as Map<String, Object?>);
      });
  Future<AuthPair> _complete(Uri callback, Map<String, Object?> pending) async {
    final persisted = await auth.storage.read('oauth');
    if (persisted == null ||
        (jsonDecode(persisted) as Map<String, Object?>)['exchange_id'] !=
            pending['exchange_id']) {
      throw const ApiException(statusCode: 401, kind: 'oauth_state_missing');
    }
    final redirect = Uri.parse(pending['redirect'] as String);
    if (callback.scheme != redirect.scheme ||
        callback.host != redirect.host ||
        callback.port != redirect.port ||
        callback.path != redirect.path ||
        callback.hasFragment ||
        callback.userInfo.isNotEmpty ||
        callback.queryParametersAll['state']?.length != 1 ||
        callback.queryParameters['state'] != pending['state'] ||
        callback.queryParametersAll['code']?.length != 1 ||
        !DateTime.parse(pending['expires_at'] as String)
            .isAfter(DateTime.now().toUtc())) {
      throw const ApiException(statusCode: 401, kind: 'oauth_state_mismatch');
    }
    final code = callback.queryParameters['code']!;
    if (code.isEmpty || code.length > 16384) {
      throw const ApiException(statusCode: 401, kind: 'oauth_code_invalid');
    }
    pending['code'] = code;
    await auth.storage.write('oauth', jsonEncode(pending));
    return _exchange(pending);
  }

  Future<AuthPair?> resumeExchange() => SerialOperations.run(_scope, () async {
        final raw = await auth.storage.read('oauth');
        if (raw == null || raw.length > 32768) return null;
        final pending = jsonDecode(raw) as Map<String, Object?>;
        if (pending['code'] == null) {
          if (browser is! OAuthCallbackSource ||
              Uri.parse(pending['redirect'] as String).scheme == 'http') {
            return null;
          }
          final callback =
              await (browser as OAuthCallbackSource).initialCallback();
          return callback == null ? null : _complete(callback, pending);
        }
        return _exchange(pending);
      });
  Future<AuthPair> _exchange(Map<String, Object?> pending) async {
    final response = await auth.api.request('POST', '/v1/auth/exchange',
        idempotencyKey: pending['exchange_id'] as String,
        body: {
          'state': pending['state'],
          'code': pending['code'],
          'code_verifier': pending['verifier']
        });
    await auth.installPairForVerifiedExchange(response.body,
        expectedOAuthExchange: pending['exchange_id'] as String);
    await auth.storage.delete('oauth');
    return AuthPair.fromJson(response.body);
  }
}
