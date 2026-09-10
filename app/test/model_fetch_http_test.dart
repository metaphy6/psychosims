import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:psyconfig/psyconfig.dart';
import 'package:psychosims/shared/logger.dart';
import 'package:psychosims/shared/model_fetch_service.dart';

class AvailableDisk implements DiskSpaceProvider {
  @override
  Future<int> freeBytes(Directory directory) async => 64 * 1024 * 1024 * 1024;
}

void main() {
  late Directory directory;
  late HttpServer server;
  final bytes = List<int>.generate(128, (i) => i);
  final checksum = sha256.convert(bytes).toString();
  setUp(() async {
    directory = await Directory('/tmp/agent-runs').createTemp('w4-fetch-http-');
    server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
  });
  tearDown(() async {
    await server.close(force: true);
    await directory.delete(recursive: true);
  });
  String url() => 'http://127.0.0.1:${server.port}/model.gguf';
  ModelFetchService service() => ModelFetchService(
      loadConfig(environment: 'test'),
      directory,
      PsyLog(minLevel: LogLevel.error),
      diskSpaceProvider: AvailableDisk());

  test('real interrupted HTTP transfer resumes the bound ETag and byte range',
      () async {
    var calls = 0;
    String? range, ifRange;
    server.listen((request) async {
      calls++;
      request.response.headers.set('ETag', '"artifact-v1"');
      if (calls == 1) {
        request.response.contentLength = bytes.length;
        final socket = await request.response.detachSocket();
        socket.add(bytes.sublist(0, 64));
        await socket.flush();
        socket.destroy();
        return;
      }
      range = request.headers.value('Range');
      ifRange = request.headers.value('If-Range');
      request.response.statusCode = 206;
      request.response.headers.set('Content-Range', 'bytes 64-127/128');
      request.response.add(bytes.sublist(64));
      await request.response.close();
    });
    final result = await service()
        .fetchModel(url(), checksum)
        .timeout(const Duration(seconds: 3));
    expect(await result.readAsBytes(), bytes);
    expect(calls, 2);
    expect(range, 'bytes=64-');
    expect(ifRange, '"artifact-v1"');
  });

  test(
      'cancellation aborts a stalled body and preserves only resumable partials',
      () async {
    final firstChunk = Completer<void>();
    server.listen((request) async {
      request.response.contentLength = bytes.length;
      request.response.headers.set('ETag', '"artifact-v1"');
      final socket = await request.response.detachSocket();
      addTearDown(socket.destroy);
      socket.add(bytes.sublist(0, 64));
      await socket.flush();
    });
    final fetcher = service();
    final flight = fetcher.fetchModel(url(), checksum, onProgress: (_) {
      if (!firstChunk.isCompleted) firstChunk.complete();
    });
    await firstChunk.future.timeout(const Duration(seconds: 2));
    fetcher.cancel();
    await expectLater(flight.timeout(const Duration(milliseconds: 500)),
        throwsA(isA<ModelFetchCancelledException>()));
    expect(fetcher.status, FetchStatus.error);
    expect(await File('${directory.path}/model.gguf').exists(), isFalse);
  });

  test('mismatched range or ETag restarts without publishing mixed bytes',
      () async {
    for (final badEtag in [false, true]) {
      await File('${directory.path}/model.gguf.tmp')
          .writeAsBytes(bytes.sublist(0, 64));
      await File('${directory.path}/model.gguf.tmp.meta').writeAsString(
          jsonEncode({
        'url': url(),
        'checksum': checksum,
        'etag': '"artifact-v1"',
        'total_length': 128
      }));
      var calls = 0;
      final subscription = server.listen((request) async {
        calls++;
        if (calls == 1) {
          request.response.statusCode = 206;
          request.response.headers.set('Content-Range',
              badEtag ? 'bytes 64-127/128' : 'bytes 63-126/128');
          request.response.headers
              .set('ETag', badEtag ? '"changed"' : '"artifact-v1"');
          request.response.add(bytes.sublist(64));
        } else {
          request.response.headers.set('ETag', '"artifact-v1"');
          request.response.add(bytes);
        }
        await request.response.close();
      });
      final result = await service().fetchModel(url(), checksum);
      expect(await result.readAsBytes(), bytes);
      expect(calls, 2);
      await result.delete();
      await subscription.cancel();
      await server.close(force: true);
      server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    }
  });

  test('bounded public artifact redirects preserve download integrity',
      () async {
    var calls = 0;
    server.listen((request) async {
      calls++;
      if (request.uri.path == '/model.gguf') {
        request.response.statusCode = 302;
        request.response.headers.set('Location', '/artifact.gguf');
      } else {
        request.response.add(bytes);
      }
      await request.response.close();
    });
    expect(await (await service().fetchModel(url(), checksum)).readAsBytes(),
        bytes);
    expect(calls, 2);
  });

  test('concurrent service instances share one selected file download',
      () async {
    var calls = 0;
    server.listen((request) async {
      calls++;
      request.response.add(bytes);
      await request.response.close();
    });
    final results = await Future.wait([
      service().fetchModel(url(), checksum),
      service().fetchModel(url(), checksum)
    ]);
    expect(results[0].path, results[1].path);
    expect(await results[0].readAsBytes(), bytes);
    expect(calls, 1);
  });
  test('queued cancellation settles promptly without releasing another writer',
      () async {
    final arrived = Completer<void>(), release = Completer<void>();
    addTearDown(() {
      if (!release.isCompleted) release.complete();
    });
    var calls = 0;
    server.listen((request) async {
      calls++;
      request.response.contentLength = bytes.length;
      request.response.add(bytes.sublist(0, 64));
      await request.response.flush();
      if (!arrived.isCompleted) arrived.complete();
      await release.future;
      request.response.add(bytes.sublist(64));
      await request.response.close();
    });
    final leader = service(), follower = service(), third = service();
    final first = leader.fetchModel(url(), checksum);
    await arrived.future;
    var settled = false, thirdSettled = false;
    final second = follower.fetchModel(url(), checksum).then<Object>((file) {
      settled = true;
      return file;
    }, onError: (Object error) {
      settled = true;
      return error;
    });
    follower.cancel();
    final last = third.fetchModel(url(), checksum).then((file) {
      thirdSettled = true;
      return file;
    });
    await Future<void>.delayed(const Duration(milliseconds: 300));
    final settledBeforeLeader = settled;
    expect(thirdSettled, isFalse);
    expect(calls, 1);
    release.complete();
    expect(await second, isA<ModelFetchCancelledException>());
    expect(await (await first).readAsBytes(), bytes);
    expect(await (await last).readAsBytes(), bytes);
    expect(calls, 1);
    expect(settledBeforeLeader, isTrue);
  });
  for (final invalid in <Map<String, Object?>>[
    {'etag': 17},
    {'etag': 'W/"weak"'},
    {'etag': 'not-an-etag'},
    {'etag': '"bad\nheader"'},
    {'total_length': '128'},
    {'total_length': -1},
    {'total_length': 32},
  ]) {
    test('invalid persisted resume metadata safely restarts: $invalid',
        () async {
      await File('${directory.path}/model.gguf.tmp')
          .writeAsBytes(bytes.sublist(0, 64));
      await File('${directory.path}/model.gguf.tmp.meta')
          .writeAsString(jsonEncode({
        'url': url(),
        'checksum': checksum,
        'etag': '"artifact-v1"',
        'total_length': 128,
        ...invalid
      }));
      var calls = 0;
      final ranges = <String?>[], ifRanges = <String?>[];
      server.listen((request) async {
        calls++;
        ranges.add(request.headers.value('range'));
        ifRanges.add(request.headers.value('if-range'));
        request.response.add(bytes);
        await request.response.close();
      });
      expect(await (await service().fetchModel(url(), checksum)).readAsBytes(),
          bytes);
      expect(await (await service().fetchModel(url(), checksum)).readAsBytes(),
          bytes);
      expect(calls, 1);
      expect(ranges, [null]);
      expect(ifRanges, [null]);
      expect(await File('${directory.path}/model.gguf.tmp.meta').exists(),
          isFalse);
    });
  }
}
