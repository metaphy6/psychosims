import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:psyconfig/psyconfig.dart';

/// One origin, bounded transport. Credentials never follow a redirect.
class ApiClient {
  ApiClient(
      {required this.baseUrl,
      this.httpClient,
      NetworkConfig? network,
      double Function()? randomUnit,
      Future<void> Function(Duration)? sleep})
      : network = network ?? loadConfig(environment: 'prod').network,
        _randomUnit = randomUnit ?? Random.secure().nextDouble,
        _sleep = sleep ?? Future<void>.delayed {
    _origin = Uri.parse(baseUrl);
    final loopback = ['127.0.0.1', '::1', 'localhost'].contains(_origin.host);
    if (!_origin.hasAuthority ||
        _origin.host.isEmpty ||
        _origin.userInfo.isNotEmpty ||
        (_origin.path.isNotEmpty && _origin.path != '/') ||
        _origin.hasQuery ||
        _origin.hasFragment ||
        (_origin.scheme != 'https' &&
            !(_origin.scheme == 'http' &&
                loopback &&
                this.network.allowInsecureLoopback))) {
      throw ArgumentError(
          'API origin requires HTTPS, or explicitly enabled loopback HTTP');
    }
  }

  final String baseUrl;
  final HttpClient? httpClient;
  final NetworkConfig network;
  final double Function() _randomUnit;
  final Future<void> Function(Duration) _sleep;
  late final Uri _origin;
  bool _closed = false;
  final Set<HttpClient> _active = {};

  static String newId([String prefix = 'req']) {
    final random = Random.secure();
    return '${prefix}_${List.generate(16, (_) => random.nextInt(256).toRadixString(16).padLeft(2, '0')).join()}';
  }

  Future<ApiResponse> request(
    String method,
    String path, {
    Map<String, Object?>? body,
    String? idempotencyKey,
    String? correlationId,
    String? bearer,
    String? etag,
  }) async {
    if (_closed) throw StateError('API client is closed');
    if (!['GET', 'POST'].contains(method) ||
        !RegExp(r'^/v1/[a-z0-9/-]+$').hasMatch(path)) {
      throw ArgumentError('Invalid API operation');
    }
    if (method != 'GET' && (idempotencyKey == null || idempotencyKey.isEmpty)) {
      throw ArgumentError('Mutations require an idempotency key');
    }
    final bytes = utf8.encode(jsonEncode(body ?? const <String, Object?>{}));
    if (bytes.length > network.maxBatchBytes) {
      throw const ApiException(statusCode: 0, kind: 'request_too_large');
    }
    final correlation = correlationId ?? newId('psy');
    var retry = 0;
    var rateRetry = 0;
    while (true) {
      try {
        return await _once(
            method, path, bytes, idempotencyKey, correlation, bearer, etag);
      } on ApiException catch (error) {
        if (!error.retryable ||
            retry >= network.maxRetries ||
            (error.statusCode == 429 &&
                rateRetry >= network.maxRateLimitRetries)) {
          rethrow;
        }
        if (error.statusCode == 429) rateRetry++;
        final ceiling = min(network.retryMaxDelayMillis,
                network.retryBaseDelayMillis * pow(2, retry))
            .toInt();
        final jitter = (_randomUnit().clamp(0, 1) * ceiling).floor();
        final delay = max(jitter, error.retryAfter?.inMilliseconds ?? 0);
        retry++;
        await _sleep(Duration(milliseconds: delay));
        if (_closed) throw StateError('API client is closed');
      }
    }
  }

  Future<ApiResponse> _once(
      String method,
      String path,
      List<int> bytes,
      String? idempotency,
      String correlation,
      String? bearer,
      String? etag) async {
    final client = httpClient ?? HttpClient();
    client.connectionTimeout =
        Duration(milliseconds: network.connectTimeoutMillis);
    _active.add(client);
    HttpClientRequest? pending;
    Future<ApiResponse> send() async {
      final request = await client.openUrl(method, _origin.resolve(path));
      pending = request;
      request.followRedirects = false;
      request.maxRedirects = 0;
      request.headers.set('Psy-API-Version', 'v1');
      request.headers.set('Psy-Correlation-ID', correlation);
      request.headers.set(HttpHeaders.acceptHeader, 'application/json');
      if (idempotency != null) {
        request.headers.set('Psy-Idempotency-Key', idempotency);
      }
      if (bearer != null) {
        request.headers.set(HttpHeaders.authorizationHeader, 'Bearer $bearer');
      }
      if (etag != null) {
        request.headers.set(HttpHeaders.ifNoneMatchHeader, etag);
      }
      if (method != 'GET') {
        request.headers.contentType = ContentType.json;
        request.add(bytes);
      }
      final response = await request.close();
      final data = <int>[];
      if (response.contentLength > network.maxResponseBytes) {
        throw const ApiException(statusCode: 0, kind: 'response_too_large');
      }
      await for (final chunk in response) {
        if (data.length + chunk.length > network.maxResponseBytes) {
          throw const ApiException(statusCode: 0, kind: 'response_too_large');
        }
        data.addAll(chunk);
      }
      Map<String, Object?> decoded = const {};
      if (data.isNotEmpty) {
        try {
          final value = jsonDecode(utf8.decode(data));
          if (value is! Map<String, dynamic>) throw const FormatException();
          decoded = value;
        } on FormatException {
          throw ApiException(
              statusCode: response.statusCode, kind: 'invalid_response');
        }
      }
      if ((response.statusCode < 200 || response.statusCode >= 300) &&
          response.statusCode != 304) {
        final kind = decoded['kind'];
        throw ApiException(
            statusCode: response.statusCode,
            kind: kind is String && RegExp(r'^[a-z_]{1,80}$').hasMatch(kind)
                ? kind
                : 'http_error',
            retryAfter: _retryAfter(
                response.headers.value(HttpHeaders.retryAfterHeader)));
      }
      return ApiResponse(
          statusCode: response.statusCode,
          body: decoded,
          etag: response.headers.value(HttpHeaders.etagHeader));
    }

    try {
      return await send().timeout(Duration(
          milliseconds: method == 'GET'
              ? network.readTimeoutMillis
              : network.mutationTimeoutMillis));
    } on TimeoutException {
      pending?.abort();
      throw const ApiException(statusCode: 408, kind: 'timeout');
    } on IOException {
      throw const ApiException(statusCode: 0, kind: 'offline');
    } finally {
      if (httpClient == null) client.close(force: true);
      _active.remove(client);
    }
  }

  Duration? _retryAfter(String? value) {
    if (value == null) return null;
    final seconds = int.tryParse(value);
    int millis;
    if (seconds != null) {
      millis = seconds * 1000;
    } else {
      try {
        millis = HttpDate.parse(value)
            .difference(DateTime.now().toUtc())
            .inMilliseconds;
      } on FormatException {
        return null;
      }
    }
    return Duration(milliseconds: millis.clamp(0, network.maxRetryAfterMillis));
  }

  void close() {
    _closed = true;
    for (final client in _active) {
      client.close(force: true);
    }
    _active.clear();
  }
}

class ApiResponse {
  const ApiResponse({required this.statusCode, required this.body, this.etag});
  final int statusCode;
  final Map<String, Object?> body;
  final String? etag;
}

class ApiException implements Exception {
  const ApiException(
      {required this.statusCode,
      this.kind = 'http_error',
      this.message = 'Request failed',
      this.retryAfter});
  final int statusCode;
  final String kind;
  final String message;
  final Duration? retryAfter;
  bool get retryable =>
      kind == 'offline' ||
      statusCode == 408 ||
      statusCode == 429 ||
      statusCode >= 500;
  @override
  String toString() => 'ApiException($statusCode, $kind)';
}
