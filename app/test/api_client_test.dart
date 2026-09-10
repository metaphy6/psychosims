import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:psyconfig/psyconfig.dart';
import 'package:psychosims/shared/api_client.dart';

void main() {
  test('requires HTTPS and rejects origins with userinfo, paths or fragments',
      () {
    for (final origin in [
      'http://example.com',
      'https://a@b',
      'https://b/api',
      'https://b#x'
    ]) {
      expect(() => ApiClient(baseUrl: origin), throwsArgumentError);
    }
  });
  test('typed request supplies headers, exact idempotency and bearer',
      () async {
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    addTearDown(() => server.close(force: true));
    final observed = <String?>[];
    server.listen((request) async {
      observed.addAll([
        request.uri.path,
        request.headers.value('Psy-API-Version'),
        request.headers.value('Psy-Idempotency-Key'),
        request.headers.value('authorization')
      ]);
      expect(request.headers.value('Psy-Correlation-ID'), isNotEmpty);
      expect(jsonDecode(await utf8.decoder.bind(request).join()),
          {'refresh_token': 'test-token'});
      request.response.headers.contentType = ContentType.json;
      request.response.write('{"ok":true}');
      await request.response.close();
    });
    final api = ApiClient(
        baseUrl: 'http://127.0.0.1:${server.port}',
        network: loadConfig(environment: 'prod')
            .network
            .copyWith(allowInsecureLoopback: true));
    addTearDown(api.close);
    final response = await api.request('POST', '/v1/auth/refresh',
        body: {'refresh_token': 'test-token'},
        idempotencyKey: 'request-1',
        bearer: 'test-access');
    expect(response.body, {'ok': true});
    expect(observed,
        ['/v1/auth/refresh', 'v1', 'request-1', 'Bearer test-access']);
  });
  test('response bounds fail closed and redirects are never followed',
      () async {
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    addTearDown(() => server.close(force: true));
    var calls = 0;
    server.listen((request) async {
      calls++;
      if (request.uri.path.endsWith('redirect')) {
        request.response.statusCode = 307;
        request.response.headers
            .set('location', 'http://127.0.0.1:${server.port}/secret');
      } else {
        request.response.write('x' * 100);
      }
      await request.response.close();
    });
    final api = ApiClient(
        baseUrl: 'http://127.0.0.1:${server.port}',
        network: loadConfig(environment: 'prod')
            .network
            .copyWith(allowInsecureLoopback: true, maxResponseBytes: 32));
    addTearDown(api.close);
    await expectLater(api.request('GET', '/v1/redirect'),
        throwsA(isA<ApiException>().having((e) => e.statusCode, 'code', 307)));
    expect(calls, 1);
    await expectLater(
        api.request('GET', '/v1/large'),
        throwsA(isA<ApiException>()
            .having((e) => e.kind, 'kind', 'response_too_large')));
  });
  test('transient errors retry with stable identity and full jitter', () async {
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    addTearDown(() => server.close(force: true));
    var calls = 0;
    final ids = <String?>[];
    server.listen((request) async {
      calls++;
      ids.add(request.headers.value('Psy-Idempotency-Key'));
      request.response.statusCode = calls == 1 ? 503 : 200;
      request.response
          .write(calls == 1 ? '{"kind":"temporarily_unavailable"}' : '{}');
      await request.response.close();
    });
    final delays = <Duration>[];
    final api = ApiClient(
        baseUrl: 'http://127.0.0.1:${server.port}',
        network: loadConfig(environment: 'prod')
            .network
            .copyWith(allowInsecureLoopback: true),
        randomUnit: () => 0.5,
        sleep: (d) async => delays.add(d));
    addTearDown(api.close);
    await api.request('POST', '/v1/receipts', body: {}, idempotencyKey: 'same');
    expect(ids, ['same', 'same']);
    expect(delays, [const Duration(milliseconds: 500)]);
  });
}
