import 'dart:async';
import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:psyconfig/psyconfig.dart';
import 'package:psychosims/shared/api_client.dart';
import 'package:psychosims/shared/auth_service.dart';
import 'package:psychosims/shared/browser_auth_service.dart';
import 'auth_service_test.dart' show TestSecrets, pair;

class AuthApi extends ApiClient {
  AuthApi() : super(baseUrl: 'https://example.invalid');
  Map<String, Object?>? startBody, exchangeBody;
  @override
  Future<ApiResponse> request(String method, String path,
      {Map<String, Object?>? body,
      String? idempotencyKey,
      String? correlationId,
      String? bearer,
      String? etag}) async {
    if (path.endsWith('start')) {
      startBody = body;
      return ApiResponse(statusCode: 200, body: {
        'state': 'fixture-state',
        'nonce': 'fixture-nonce',
        'authorization_url':
            'https://provider.invalid/authorize?state=fixture-state',
        'expires_at': DateTime.now()
            .toUtc()
            .add(const Duration(minutes: 5))
            .toIso8601String()
      });
    }
    exchangeBody = body;
    return ApiResponse(statusCode: 200, body: pair('access', 'refresh'));
  }
}

class CallbackBrowser implements OAuthBrowser {
  CallbackBrowser(this.state);
  final String state;
  @override
  Future<Uri> authorize(Uri url, Uri redirect, Duration timeout) async =>
      redirect
          .replace(queryParameters: {'state': state, 'code': 'fixture-code'});
}

class DelayedBrowser implements OAuthBrowser {
  final opened = Completer<void>();
  final callback = Completer<Uri>();
  @override
  Future<Uri> authorize(Uri url, Uri redirect, Duration timeout) {
    opened.complete();
    return callback.future;
  }
}

class ColdCallbackBrowser extends CallbackBrowser
    implements OAuthCallbackSource {
  ColdCallbackBrowser() : super('fixture-state');
  @override
  Future<Uri?> initialCallback() async => Uri.parse(
      'https://callback.invalid/oauth?state=fixture-state&code=fixture-code');
}

void main() {
  test('cold callback resumes a durable secure handshake after process restart',
      () async {
    final api = AuthApi();
    final auth = AuthService(api: api, storage: TestSecrets());
    await auth.storage.write(
        'oauth',
        jsonEncode({
          'state': 'fixture-state',
          'verifier': 'fixture-verifier',
          'exchange_id': 'fixture-exchange',
          'redirect': 'https://callback.invalid/oauth',
          'expires_at': DateTime.now()
              .toUtc()
              .add(const Duration(minutes: 5))
              .toIso8601String()
        }));
    final service = BrowserAuthService(
        auth: auth,
        network: loadConfig(environment: 'test').network,
        browser: ColdCallbackBrowser());
    expect((await service.resumeExchange())!.accountId, 'account-1');
    expect(await auth.storage.read('oauth'), isNull);
    expect(api.exchangeBody!['code'], 'fixture-code');
  });

  test(
      'logout cancels an in-flight browser exchange even before any account exists',
      () async {
    final api = AuthApi();
    final auth = AuthService(api: api, storage: TestSecrets());
    final browser = DelayedBrowser();
    final network = loadConfig(environment: 'test').network.copyWith(
        oauthChannel: 'direct_download',
        oauthRedirectUri: 'http://127.0.0.1:38191/oauth',
        oauthAuthorizationOrigins: ['https://provider.invalid']);
    final service =
        BrowserAuthService(auth: auth, network: network, browser: browser);
    final flight = service.signIn('google');
    await browser.opened.future;
    await auth.logout();
    final expectation = expectLater(flight, throwsA(isA<ApiException>()));
    browser.callback.complete(Uri.parse(
        'http://127.0.0.1:38191/oauth?state=fixture-state&code=fixture-code'));
    await expectation;
    expect(await auth.currentSession(), isNull);
  });

  test(
      'browser sign-in binds state and PKCE and deletes completed secure handshake',
      () async {
    final api = AuthApi(), storage = TestSecrets();
    final auth = AuthService(api: api, storage: storage);
    final network = loadConfig(environment: 'test').network.copyWith(
        oauthChannel: 'direct_download',
        oauthRedirectUri: 'http://127.0.0.1:38191/oauth',
        oauthAuthorizationOrigins: ['https://provider.invalid']);
    final browser = BrowserAuthService(
        auth: auth,
        network: network,
        browser: CallbackBrowser('fixture-state'));
    await browser.signIn('google');
    expect(api.startBody!['code_challenge_method'], 'S256');
    expect(api.startBody!['code_challenge'], hasLength(43));
    expect(api.exchangeBody!['code_verifier'], hasLength(43));
    expect((await auth.currentSession())!.accountId, 'account-1');
    expect(await auth.storage.read('oauth'), isNull);
  });
  test('wrong callback state never exchanges and unconfigured flow is disabled',
      () async {
    final api = AuthApi(), storage = TestSecrets();
    final auth = AuthService(api: api, storage: storage);
    final network = loadConfig(environment: 'test').network.copyWith(
        oauthChannel: 'direct_download',
        oauthRedirectUri: 'http://127.0.0.1:38191/oauth',
        oauthAuthorizationOrigins: ['https://provider.invalid']);
    await expectLater(
        BrowserAuthService(
                auth: auth,
                network: network,
                browser: CallbackBrowser('attacker'))
            .signIn('google'),
        throwsA(isA<ApiException>()));
    expect(api.exchangeBody, isNull);
    expect(
        BrowserAuthService(
                auth: auth, network: loadConfig(environment: 'prod').network)
            .configured,
        isFalse);
  });
}
