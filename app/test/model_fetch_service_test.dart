import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:psyconfig/psyconfig.dart';

import 'package:psychosims/shared/logger.dart';
import 'package:psychosims/shared/model_fetch_service.dart';

String _sha256(List<int> bytes) => sha256.convert(bytes).toString();

ModelHttpResponse _okResponse(
  List<int> body, {
  int? totalLength,
}) {
  return ModelHttpResponse(
    statusCode: HttpStatus.ok,
    body: Stream.fromIterable([body]),
    totalLength: totalLength ?? body.length,
    contentLength: body.length,
  );
}

ModelHttpResponse _partialResponse(
  List<int> body, {
  required int start,
  required int totalLength,
}) {
  return ModelHttpResponse(
    statusCode: HttpStatus.partialContent,
    body: Stream.fromIterable([body]),
    totalLength: totalLength,
    contentLength: body.length,
    rangeStart: start,
    rangeEnd: start + body.length - 1,
  );
}

class _MockHttpClient implements ModelHttpClient {
  _MockHttpClient(this._handler);

  final ModelHttpResponse Function(Uri url, {int? start, int? end}) _handler;
  int callCount = 0;
  int? lastStart;
  int? lastEnd;

  @override
  Future<ModelHttpResponse> fetchRange(
    Uri url, {
    int? start,
    int? end,
    String? ifRange,
  }) async {
    callCount++;
    lastStart = start;
    lastEnd = end;
    return _handler(url, start: start, end: end);
  }
}

class _FixedDiskSpaceProvider implements DiskSpaceProvider {
  _FixedDiskSpaceProvider(this._freeBytes);
  final int _freeBytes;

  @override
  Future<int> freeBytes(Directory directory) async => _freeBytes;
}

class _DiskFullFileSystem extends DartIoFileSystemOperations {
  @override
  Future<void> writeStream(String path, Stream<List<int>> data,
      {FileMode mode = FileMode.write}) async {
    if (path.endsWith('.tmp')) {
      await super.writeStream(path, data.take(1), mode: mode);
      throw FileSystemException(
          'Disk full', path, const OSError('No space left', 28));
    }
    return super.writeStream(path, data, mode: mode);
  }
}

Config _testConfig({
  int modelFileSizeBytes = 0,
  int maxFetchRetries = 2,
  int minFreeDiskBytes = 1024 * 1024,
}) {
  return Config(
    schemaVersion: '1.0.0',
    network: const NetworkConfig(
      apiBaseUrl: 'http://localhost',
      connectTimeoutMillis: 1000,
      receiveTimeoutMillis: 1000,
    ),
    model: ModelConfig(
      tierAPrimaryUrl: '',
      tierAFallbackUrl: '',
      tierBUrl: '',
      quantization: 'Q4_K_M',
      nCtx: 512,
      nBatch: 128,
      modelFileSizeBytes: modelFileSizeBytes,
      modelChecksums: const {},
      maxFetchRetries: maxFetchRetries,
      minFreeDiskBytes: minFreeDiskBytes,
      tierAFloorBytes: 8589934592,
      tierBFloorBytes: 4294967296,
      tierAAvailableHeadroomBytes: 1073741824,
    ),
    inference: const InferenceConfig(
      threadCount: 1,
      seed: 0,
      temperature: 0.0,
      topP: 1.0,
      topK: 1,
      repetitionPenalty: 1.0,
      stopTokens: [],
      kvCacheType: 'f16',
      greedyDecode: true,
    ),
    content: const ContentConfig(
      bundledManifestPath: '',
      maxManifestBytes: 128 * 1024,
      maxManifestDepth: 8,
    ),
    promptBudget: const PromptBudgetConfig(
      maxInputTokens: 256,
      maxOutputTokens: 64,
      prefixCacheTokens: 64,
    ),
    balance: const BalanceConfig(
      startingClinicCurrency: 500,
      sessionFeeClinicCurrency: 50,
      startingStudyPoints: 0,
      studyPointsPerSession: 5,
      activeCardSlots: 5,
      relatableTrustBumpMin: 2,
      relatableTrustBumpMax: 5,
      postponingFreezeTurns: 1,
      misfortuneRollPercent: 5.0,
      doubtTransferBasePercent: 2.0,
      referralRewardXp: 1,
      discountPracticeXpPenaltyPercent: 50.0,
      ownershipLeaseTtlHours: 48,
      rulesetVersionSunsetDays: 90,
    ),
    featureFlags: const FeatureFlags(
      enableOfflineQueue: true,
      enableTelemetry: false,
    ),
    secretsRefs: const SecretsRefs(apiKeyRef: 'KEY'),
  );
}

void main() {
  final logger = PsyLog(minLevel: LogLevel.warn);

  group('verifyFile', () {
    late Directory tempDir;

    setUp(() {
      tempDir = Directory.systemTemp.createTempSync('model_fetch_test_');
    });

    tearDown(() {
      tempDir.deleteSync(recursive: true);
    });

    test('returns true when checksum matches', () async {
      final bytes = [1, 2, 3, 4, 5];
      final file = File(p.join(tempDir.path, 'model.gguf'))
        ..writeAsBytesSync(bytes);
      final service = ModelFetchService(
        _testConfig(),
        tempDir,
        logger,
      );

      expect(
        await service.verifyFile(file, _sha256(bytes)),
        isTrue,
      );
      expect(service.status, FetchStatus.complete);
    });

    test('returns false when checksum mismatches', () async {
      final bytes = [1, 2, 3, 4, 5];
      final file = File(p.join(tempDir.path, 'model.gguf'))
        ..writeAsBytesSync(bytes);
      final service = ModelFetchService(
        _testConfig(),
        tempDir,
        logger,
      );

      expect(
        await service.verifyFile(file, '0' * 64),
        isFalse,
      );
      expect(service.status, FetchStatus.verifying);
    });
  });

  group('fetchModel', () {
    late Directory tempDir;

    setUp(() {
      tempDir = Directory.systemTemp.createTempSync('model_fetch_test_');
    });

    tearDown(() {
      tempDir.deleteSync(recursive: true);
    });

    test('downloads full file, verifies checksum, and renames atomically',
        () async {
      const url = 'https://models.example/phi.gguf';
      final fullBytes = List<int>.generate(64, (i) => i);
      final checksum = _sha256(fullBytes);
      final mockClient = _MockHttpClient(
        (_, {int? start, int? end}) => _okResponse(fullBytes),
      );
      final service = ModelFetchService(
        _testConfig(),
        tempDir,
        logger,
        httpClient: mockClient,
        diskSpaceProvider: _FixedDiskSpaceProvider(1024 * 1024),
      );

      final result = await service.fetchModel(url, checksum);

      expect(result.path, p.join(tempDir.path, 'phi.gguf'));
      expect(await result.exists(), isTrue);
      expect(await result.readAsBytes(), fullBytes);
      expect(service.status, FetchStatus.complete);
      expect(mockClient.callCount, 1);
      expect(mockClient.lastStart, isNull);
    });

    test('resumes a partial download using HTTP Range', () async {
      const url = 'https://models.example/phi.gguf';
      final fullBytes = List<int>.generate(128, (i) => i);
      final checksum = _sha256(fullBytes);
      final firstHalf = fullBytes.sublist(0, 64);
      final secondHalf = fullBytes.sublist(64);

      File(p.join(tempDir.path, 'phi.gguf.tmp')).writeAsBytesSync(firstHalf);
      File(p.join(tempDir.path, 'phi.gguf.tmp.meta')).writeAsStringSync(
          jsonEncode({
        'url': url,
        'checksum': checksum,
        'total_length': fullBytes.length
      }));

      final mockClient = _MockHttpClient(
        (_, {int? start, int? end}) => _partialResponse(
          secondHalf,
          start: start ?? 0,
          totalLength: fullBytes.length,
        ),
      );
      final service = ModelFetchService(
        _testConfig(modelFileSizeBytes: fullBytes.length),
        tempDir,
        logger,
        httpClient: mockClient,
        diskSpaceProvider: _FixedDiskSpaceProvider(fullBytes.length * 4),
      );

      final result = await service.fetchModel(url, checksum);

      expect(await result.readAsBytes(), fullBytes);
      expect(mockClient.callCount, 1);
      expect(mockClient.lastStart, 64);
      expect(File(p.join(tempDir.path, 'phi.gguf.tmp')).existsSync(), isFalse);
    });

    test('re-fetches when final file is corrupt', () async {
      const url = 'https://models.example/phi.gguf';
      final fullBytes = List<int>.generate(32, (i) => i);
      final checksum = _sha256(fullBytes);

      File(p.join(tempDir.path, 'phi.gguf'))
        ..createSync()
        ..writeAsBytesSync([9, 9, 9, 9]);

      final mockClient = _MockHttpClient(
        (_, {int? start, int? end}) => _okResponse(fullBytes),
      );
      final service = ModelFetchService(
        _testConfig(),
        tempDir,
        logger,
        httpClient: mockClient,
        diskSpaceProvider: _FixedDiskSpaceProvider(1024 * 1024),
      );

      final result = await service.fetchModel(url, checksum);

      expect(await result.readAsBytes(), fullBytes);
      expect(service.status, FetchStatus.complete);
      expect(mockClient.callCount, 1);
    });

    test('deletes corrupt partial and retries from start', () async {
      const url = 'https://models.example/phi.gguf';
      final fullBytes = List<int>.generate(32, (i) => i);
      final checksum = _sha256(fullBytes);

      // Partial temp file exists with wrong content.
      File(p.join(tempDir.path, 'phi.gguf.tmp'))
        ..createSync()
        ..writeAsBytesSync([9, 9, 9, 9]);

      var call = 0;
      final mockClient = _MockHttpClient(
        (_, {int? start, int? end}) {
          call++;
          if (call == 1) {
            // First attempt: pretend server returns the (corrupt) partial.
            return _okResponse([9, 9, 9, 9]);
          }
          return _okResponse(fullBytes);
        },
      );
      final service = ModelFetchService(
        _testConfig(maxFetchRetries: 2),
        tempDir,
        logger,
        httpClient: mockClient,
        diskSpaceProvider: _FixedDiskSpaceProvider(1024 * 1024),
      );

      final result = await service.fetchModel(url, checksum);

      expect(await result.readAsBytes(), fullBytes);
      expect(service.status, FetchStatus.complete);
      expect(mockClient.callCount, 2);
    });

    test('throws on insufficient disk space and reports error status',
        () async {
      const url = 'https://models.example/phi.gguf';
      final service = ModelFetchService(
        _testConfig(
          modelFileSizeBytes: 1000,
          minFreeDiskBytes: 100,
        ),
        tempDir,
        logger,
        diskSpaceProvider: _FixedDiskSpaceProvider(1500), // < 2*1000
      );

      await expectLater(
        service.fetchModel(url, 'a' * 64),
        throwsA(isA<ModelFetchDiskSpaceException>()),
      );
      expect(service.status, FetchStatus.error);
    });

    test('defers fetch on metered connection', () async {
      const url = 'https://models.example/phi.gguf';
      final service = ModelFetchService(
        _testConfig(),
        tempDir,
        logger,
      );

      expect(
        () => service.fetchModel(url, 'a' * 64, meteredConnection: true),
        throwsA(isA<ModelFetchMeteredException>()),
      );
      expect(service.status, FetchStatus.error);
    });

    test('emits progress callbacks', () async {
      const url = 'https://models.example/phi.gguf';
      final fullBytes = List<int>.generate(100, (i) => i);
      final checksum = _sha256(fullBytes);
      final mockClient = _MockHttpClient(
        (_, {int? start, int? end}) => _okResponse(
          fullBytes,
          totalLength: fullBytes.length,
        ),
      );
      final service = ModelFetchService(
        _testConfig(modelFileSizeBytes: fullBytes.length),
        tempDir,
        logger,
        httpClient: mockClient,
        diskSpaceProvider: _FixedDiskSpaceProvider(fullBytes.length * 4),
      );

      final progressValues = <double>[];
      await service.fetchModel(
        url,
        checksum,
        onProgress: progressValues.add,
      );

      expect(progressValues, isNotEmpty);
      expect(progressValues.last, 1.0);
    });

    test(
        'disk-full failure retains the partial and never publishes or retries it',
        () async {
      final client = _MockHttpClient(
          (_, {int? start, int? end}) => _okResponse([1, 2, 3]));
      final service = ModelFetchService(_testConfig(), tempDir, logger,
          httpClient: client,
          fileSystem: _DiskFullFileSystem(),
          diskSpaceProvider: _FixedDiskSpaceProvider(1024 * 1024));
      await expectLater(
          service.fetchModel(
              'https://models.example/full.gguf', _sha256([1, 2, 3])),
          throwsA(isA<FileSystemException>()));
      expect(service.status, FetchStatus.error);
      expect(client.callCount, 1);
      expect(await File(p.join(tempDir.path, 'full.gguf')).exists(), isFalse);
      expect(
          await File(p.join(tempDir.path, 'full.gguf.tmp')).exists(), isTrue);
    });

    test('disk measurement failure never substitutes invented free capacity',
        () async {
      await expectLater(
          const DefaultDiskSpaceProvider()
              .freeBytes(Directory(p.join(tempDir.path, 'missing'))),
          throwsA(isA<ModelFetchException>()));
    });

    test('verified cached file stays available when disk space is low',
        () async {
      final bytes = [1, 2, 3];
      final cached = File(p.join(tempDir.path, 'cached.gguf'));
      await cached.writeAsBytes(bytes);
      final client = _MockHttpClient(
          (_, {int? start, int? end}) => throw StateError('must not download'));
      final service = ModelFetchService(_testConfig(), tempDir, logger,
          httpClient: client, diskSpaceProvider: _FixedDiskSpaceProvider(0));
      expect(
          await (await service.fetchModel(
                  'https://models.example/cached.gguf', _sha256(bytes)))
              .readAsBytes(),
          bytes);
      expect(client.callCount, 0);
    });

    test('an unknown-length body cannot consume the disk reserve', () async {
      final client = _MockHttpClient((_, {int? start, int? end}) =>
          ModelHttpResponse(
              statusCode: 200, body: Stream.value(List<int>.filled(501, 1))));
      final service = ModelFetchService(
          _testConfig(minFreeDiskBytes: 1), tempDir, logger,
          httpClient: client, diskSpaceProvider: _FixedDiskSpaceProvider(1000));
      await expectLater(
          service.fetchModel('https://models.example/bounded.gguf', 'a' * 64),
          throwsA(isA<ModelFetchDiskSpaceException>()));
      expect(client.callCount, 1);
      expect(
          await File(p.join(tempDir.path, 'bounded.gguf')).exists(), isFalse);
    });

    test('symlinked partial cannot overwrite another local file', () async {
      final target = File(p.join(tempDir.path, 'private-data'));
      await target.writeAsString('preserve');
      await Link(p.join(tempDir.path, 'model.gguf.tmp')).create(target.path);
      final service = ModelFetchService(_testConfig(), tempDir, logger,
          diskSpaceProvider: _FixedDiskSpaceProvider(1024 * 1024));
      await expectLater(
          service.fetchModel('https://models.example/model.gguf', 'a' * 64),
          throwsA(isA<ModelFetchException>()));
      expect(await target.readAsString(), 'preserve');
    });

    test('can be cancelled', () async {
      const url = 'https://models.example/phi.gguf';
      final fullBytes = List<int>.generate(100, (i) => i);
      final checksum = _sha256(fullBytes);
      final completer = Completer<void>();
      final mockClient = _MockHttpClient(
        (_, {int? start, int? end}) {
          return ModelHttpResponse(
            statusCode: HttpStatus.ok,
            body: Stream.fromIterable([
              fullBytes.sublist(0, 50),
            ]).asyncMap((chunk) async {
              await completer.future;
              return chunk;
            }),
            totalLength: fullBytes.length,
            contentLength: fullBytes.length,
          );
        },
      );
      final service = ModelFetchService(
        _testConfig(),
        tempDir,
        logger,
        httpClient: mockClient,
        diskSpaceProvider: _FixedDiskSpaceProvider(1024 * 1024),
      );

      final future = service.fetchModel(url, checksum);
      service.cancel();
      completer.complete();

      expect(future, throwsA(isA<ModelFetchCancelledException>()));
    });
  });
}
