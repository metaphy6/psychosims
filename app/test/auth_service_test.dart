import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:psyconfig/psyconfig.dart';
import 'package:psychosims/shared/api_client.dart';
import 'package:psychosims/shared/auth_service.dart';
import 'package:psychosims/shared/secure_storage.dart';

class TestSecrets implements SecretStorage {
  final Map<String, String> values = {};
  bool failNextWrite = false;
  @override
  String get scope => 'test_${identityHashCode(this)}';
  @override
  Future<String?> read(String key) async => values[key];
  @override
  Future<void> write(String key, String value) async {
    if (failNextWrite) {
      failNextWrite = false;
      throw StateError('storage unavailable');
    }
    values[key] = value;
  }

  @override
  Future<void> delete(String key) async {
    values.remove(key);
  }
}

Map<String, Object?> pair(String access, String refresh,
        {String account = 'account-1', bool expired = false}) =>
    {
      'account_id': account,
      'access_token': access,
      'refresh_token': refresh,
      'token_type': 'Bearer',
      'access_expires_at': DateTime.now()
          .toUtc()
          .add(Duration(hours: expired ? -1 : 1))
          .toIso8601String(),
      'refresh_expires_at':
          DateTime.now().toUtc().add(const Duration(days: 1)).toIso8601String(),
    };

void main() {
  test(
      'concurrent refresh uses one rotation; restart recovers lost persisted response',
      () async {
    final secrets = TestSecrets();
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    addTearDown(() => server.close(force: true));
    var refreshes = 0;
    final keys = <String?>[];
    server.listen((request) async {
      final body = jsonDecode(await utf8.decoder.bind(request).join());
      request.response.headers.contentType = ContentType.json;
      if (request.uri.path.endsWith('id-token')) {
        request.response.write(
            jsonEncode(pair('expired-access', 'old-refresh', expired: true)));
      } else {
        refreshes++;
        keys.add(request.headers.value('Psy-Idempotency-Key'));
        expect(body['refresh_token'], 'old-refresh');
        if (refreshes == 1) secrets.failNextWrite = true;
        request.response.write(jsonEncode(pair('new-access', 'new-refresh')));
      }
      await request.response.close();
    });
    final api = ApiClient(
        baseUrl: 'http://127.0.0.1:${server.port}',
        network: loadConfig(environment: 'test').network);
    addTearDown(api.close);
    final auth = AuthService(api: api, storage: secrets);
    await auth.signIn(
        provider: 'google', idToken: 'fixture-proof', nonce: 'nonce');
    await expectLater(auth.accessToken(), throwsStateError);
    final restarted = AuthService(api: api, storage: secrets);
    final results =
        await Future.wait(List.generate(8, (_) => restarted.accessToken()));
    expect(results, everyElement('new-access'));
    expect(refreshes, 2);
    expect(keys[0], keys[1]);
  });
  test('storage failures are visible and never downgrade to plaintext',
      () async {
    final secrets = TestSecrets()..failNextWrite = true;
    final api = ApiClient(baseUrl: 'https://example.invalid');
    addTearDown(api.close);
    final auth = AuthService(api: api, storage: secrets);
    await expectLater(
        auth.installPairForVerifiedExchange(pair('a', 'r')), throwsStateError);
    expect(await auth.currentSession(), isNull);
  });
  test(
      'credentials never cross API origins and offline logout retries after restart',
      () async {
    final secrets = TestSecrets();
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    addTearDown(() => server.close(force: true));
    var online = false, calls = 0;
    final ids = <String?>[];
    server.listen((request) async {
      calls++;
      ids.add(request.headers.value('Psy-Idempotency-Key'));
      request.response.statusCode = online ? 200 : 503;
      request.response.write('{}');
      await request.response.close();
    });
    final api = ApiClient(
        baseUrl: 'http://127.0.0.1:${server.port}',
        network:
            loadConfig(environment: 'test').network.copyWith(maxRetries: 0));
    addTearDown(api.close);
    final auth = AuthService(api: api, storage: secrets);
    await auth.installPairForVerifiedExchange(pair('access', 'refresh'));
    final otherApi = ApiClient(baseUrl: 'https://another.invalid');
    addTearDown(otherApi.close);
    expect(await AuthService(api: otherApi, storage: secrets).currentSession(),
        isNull);
    await auth.logout();
    expect(await auth.currentSession(), isNull);
    online = true;
    await AuthService(api: api, storage: secrets).flushLogouts();
    expect(calls, 2);
    expect(ids[0], ids[1]);
  });
  test('sign-out refreshes expired access before revoking its refresh family',
      () async {
    final secrets = TestSecrets();
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    addTearDown(() => server.close(force: true));
    final paths = <String>[];
    String? logoutBearer;
    server.listen((request) async {
      paths.add(request.uri.path);
      if (request.uri.path.endsWith('refresh')) {
        request.response
            .write(jsonEncode(pair('renewed-access', 'renewed-refresh')));
      } else {
        logoutBearer = request.headers.value('authorization');
        request.response.write('{}');
      }
      await request.response.close();
    });
    final api = ApiClient(
        baseUrl: 'http://127.0.0.1:${server.port}',
        network: loadConfig(environment: 'test').network);
    addTearDown(api.close);
    final auth = AuthService(api: api, storage: secrets);
    await auth.installPairForVerifiedExchange(
        pair('expired', 'refresh', expired: true));
    await auth.logout();
    expect(paths, ['/v1/auth/refresh', '/v1/auth/logout']);
    expect(logoutBearer, 'Bearer renewed-access');
    expect(await auth.currentSession(), isNull);
  });
  test(
      'consumed refresh still revokes expired access and retains transient logout',
      () async {
    final secrets = TestSecrets();
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    addTearDown(() => server.close(force: true));
    final logoutIds = <String?>[];
    var online = false;
    server.listen((request) async {
      await request.drain<void>();
      if (request.uri.path.endsWith('refresh')) {
        request.response.statusCode = 401;
      } else {
        expect(request.uri.path, '/v1/auth/logout');
        expect(request.headers.value('authorization'), 'Bearer expired');
        logoutIds.add(request.headers.value('Psy-Idempotency-Key'));
        request.response.statusCode = online ? 200 : 503;
      }
      request.response.write('{}');
      await request.response.close();
    });
    final api = ApiClient(
        baseUrl: 'http://127.0.0.1:${server.port}',
        network:
            loadConfig(environment: 'test').network.copyWith(maxRetries: 0));
    addTearDown(api.close);
    final auth = AuthService(api: api, storage: secrets);
    await auth.installPairForVerifiedExchange(
        pair('expired', 'consumed', expired: true));
    await auth.logout();
    expect(await auth.currentSession(), isNull);
    expect(logoutIds, hasLength(1));
    expect(await auth.storage.read('pending_logouts'), isNotNull);
    online = true;
    await AuthService(api: api, storage: secrets).flushLogouts();
    expect(logoutIds, hasLength(2));
    expect(logoutIds[1], logoutIds[0]);
    expect(await auth.storage.read('pending_logouts'), isNull);
  });
}
