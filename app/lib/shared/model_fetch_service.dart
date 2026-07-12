import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:convert/convert.dart';
import 'package:path/path.dart' as p;
import 'package:psyconfig/psyconfig.dart';

import 'logger.dart';

/// Current state of a model fetch operation.
enum FetchStatus {
  pending,
  downloading,
  verifying,
  complete,
  error,
}

/// Exceptions emitted by [ModelFetchService].
class ModelFetchException implements Exception {
  ModelFetchException(this.message);
  final String message;

  @override
  String toString() => 'ModelFetchException: $message';
}

class ModelFetchNetworkException extends ModelFetchException {
  ModelFetchNetworkException(super.message);
}

class ModelFetchChecksumException extends ModelFetchException {
  ModelFetchChecksumException(this.expectedChecksum)
      : super('Checksum mismatch; expected $expectedChecksum');
  final String expectedChecksum;
}

class ModelFetchDiskSpaceException extends ModelFetchException {
  ModelFetchDiskSpaceException(this.requiredBytes, this.freeBytes)
      : super(
            'Insufficient disk space: required $requiredBytes, free $freeBytes');
  final int requiredBytes;
  final int freeBytes;
}

class ModelFetchCancelledException extends ModelFetchException {
  ModelFetchCancelledException() : super('Model fetch was cancelled');
}

class ModelFetchMeteredException extends ModelFetchException {
  ModelFetchMeteredException(this.url)
      : super('Fetch deferred until unmetered connection: $url');
  final String url;
}

/// HTTP seam so tests can mock range responses without real network I/O.
abstract class ModelHttpClient {
  Future<ModelHttpResponse> fetchRange(
    Uri url, {
    int? start,
    int? end,
  });
}

/// Response returned by [ModelHttpClient.fetchRange].
class ModelHttpResponse {
  const ModelHttpResponse({
    required this.statusCode,
    required this.body,
    this.totalLength,
    this.contentLength,
  });

  final int statusCode;
  final Stream<List<int>> body;

  /// Total bytes in the resource, parsed from a `Content-Range` header.
  final int? totalLength;

  /// Bytes in this response body.
  final int? contentLength;
}

/// Default HTTP adapter backed by `dart:io` [HttpClient].
class DartIoHttpClientAdapter implements ModelHttpClient {
  DartIoHttpClientAdapter([this._logger]);

  final PsyLog? _logger;

  @override
  Future<ModelHttpResponse> fetchRange(
    Uri url, {
    int? start,
    int? end,
  }) async {
    final client = HttpClient();
    try {
      _logger?.debug('model_fetch', 'http_request', kv: {
        'url': url.toString(),
        if (start != null) 'range_start': start,
        if (end != null) 'range_end': end,
      });
      final request = await client.getUrl(url);
      if (start != null) {
        final rangeValue = end != null ? 'bytes=$start-$end' : 'bytes=$start-';
        request.headers.set(HttpHeaders.rangeHeader, rangeValue);
      }
      final response = await request.close();
      final totalLength = _parseTotalLength(response);

      final controller = StreamController<List<int>>(onCancel: client.close);
      var closed = false;
      void closeClient() {
        if (!closed) {
          closed = true;
          client.close();
        }
      }

      response.listen(
        controller.add,
        onError: (Object error, StackTrace stack) {
          controller.addError(error, stack);
          closeClient();
        },
        onDone: () {
          controller.close();
          closeClient();
        },
        cancelOnError: true,
      );

      return ModelHttpResponse(
        statusCode: response.statusCode,
        body: controller.stream,
        totalLength: totalLength,
        contentLength: response.contentLength,
      );
    } on Exception {
      client.close(force: true);
      rethrow;
    }
  }

  int? _parseTotalLength(HttpClientResponse response) {
    final header = response.headers.value(HttpHeaders.contentRangeHeader);
    if (header == null) return null;
    final match = RegExp(r'bytes \d+-\d+/(\d+|\*)').firstMatch(header);
    if (match == null) return null;
    final total = match.group(1);
    if (total == null || total == '*') return null;
    return int.tryParse(total);
  }
}

/// Disk-space seam so tests can control the preflight result.
abstract class DiskSpaceProvider {
  Future<int> freeBytes(Directory directory);
}

/// Best-effort disk-space provider. Uses `df` on Unix-like systems and a
/// conservative placeholder on Windows (real free-space there needs FFI).
class DefaultDiskSpaceProvider implements DiskSpaceProvider {
  const DefaultDiskSpaceProvider();

  static const int _fallbackBytes = 100 * 1024 * 1024 * 1024; // 100 GiB

  @override
  Future<int> freeBytes(Directory directory) async {
    if (Platform.isWindows) return _fallbackBytes;
    try {
      final result = await Process.run('df', ['-B1', directory.path]);
      if (result.exitCode != 0) return _fallbackBytes;
      final lines = LineSplitter.split(result.stdout.toString())
          .where((line) => line.trim().isNotEmpty)
          .toList();
      if (lines.length < 2) return _fallbackBytes;
      final parts = lines.last.trim().split(RegExp(r'\s+'));
      if (parts.length < 4) return _fallbackBytes;
      return int.tryParse(parts[3]) ?? _fallbackBytes;
    } on Exception {
      return _fallbackBytes;
    }
  }
}

/// File-system seam for testable I/O.
abstract class FileSystemOperations {
  Future<bool> exists(String path);
  Future<int> length(String path);
  Stream<List<int>> readStream(String path);
  Future<void> writeStream(
    String path,
    Stream<List<int>> data, {
    FileMode mode = FileMode.write,
  });
  Future<void> delete(String path);
  Future<void> rename(String sourcePath, String targetPath);
}

/// Default file-system implementation backed by `dart:io`.
class DartIoFileSystemOperations implements FileSystemOperations {
  const DartIoFileSystemOperations();

  @override
  Future<bool> exists(String path) => File(path).exists();

  @override
  Future<int> length(String path) => File(path).length();

  @override
  Stream<List<int>> readStream(String path) => File(path).openRead();

  @override
  Future<void> writeStream(
    String path,
    Stream<List<int>> data, {
    FileMode mode = FileMode.write,
  }) async {
    await data.pipe(File(path).openWrite(mode: mode));
  }

  @override
  Future<void> delete(String path) async {
    final file = File(path);
    if (await file.exists()) await file.delete();
  }

  @override
  Future<void> rename(String sourcePath, String targetPath) async {
    await File(sourcePath).rename(targetPath);
  }
}

class _CancelToken {
  bool _cancelled = false;
  bool get isCancelled => _cancelled;
  void cancel() => _cancelled = true;
}

/// Fetches and verifies a model file using resumable HTTP Range requests.
///
/// The service is designed for first-run model onboarding: it preflights free
/// disk space, resumes partial downloads, verifies SHA-256 checksums, and
/// atomically moves a completed temp file to its final path.
class ModelFetchService {
  ModelFetchService(
    this.config,
    this.directory,
    this.logger, {
    ModelHttpClient? httpClient,
    DiskSpaceProvider? diskSpaceProvider,
    FileSystemOperations? fileSystem,
  })  : _httpClient = httpClient ?? DartIoHttpClientAdapter(logger),
        _diskSpaceProvider =
            diskSpaceProvider ?? const DefaultDiskSpaceProvider(),
        _fileSystem = fileSystem ?? const DartIoFileSystemOperations();

  final Config config;
  final Directory directory;
  final PsyLog logger;

  final ModelHttpClient _httpClient;
  final DiskSpaceProvider _diskSpaceProvider;
  final FileSystemOperations _fileSystem;

  FetchStatus _status = FetchStatus.pending;
  FetchStatus get status => _status;

  _CancelToken? _activeToken;

  /// Cancels the in-flight fetch. The next cancellation check will throw
  /// [ModelFetchCancelledException]. Safe to call when idle.
  void cancel() {
    logger.info('model_fetch', 'cancellation_requested');
    _activeToken?.cancel();
  }

  /// Downloads [url] to [directory], verifies it against [expectedChecksum],
  /// and returns the final [File].
  ///
  /// When [meteredConnection] is true the fetch is deferred by throwing
  /// [ModelFetchMeteredException]; callers should retry once an unmetered
  /// connection is available.
  Future<File> fetchModel(
    String url,
    String expectedChecksum, {
    bool meteredConnection = false,
    void Function(double progress)? onProgress,
  }) async {
    final token = _CancelToken();
    _activeToken = token;
    try {
      _status = FetchStatus.pending;
      logger.info('model_fetch', 'fetch_started', kv: {
        'url': url,
        'metered_connection': meteredConnection,
      });

      if (meteredConnection) {
        _status = FetchStatus.error;
        logger.warn('model_fetch', 'fetch_deferred_metered', kv: {'url': url});
        throw ModelFetchMeteredException(url);
      }

      final fileName = _fileNameFromUrl(url);
      final tempPath = p.join(directory.path, '$fileName.tmp');
      final finalPath = p.join(directory.path, fileName);

      await _ensureDirectoryExists();
      await _preflightDiskSpace(url);

      final maxAttempts = config.model.maxFetchRetries + 1;
      var attempt = 0;
      Object? lastError;

      while (attempt < maxAttempts) {
        if (token.isCancelled) throw ModelFetchCancelledException();

        try {
          return await _download(
            url: url,
            tempPath: tempPath,
            finalPath: finalPath,
            expectedChecksum: expectedChecksum,
            onProgress: onProgress,
            token: token,
          );
        } on ModelFetchChecksumException catch (e) {
          lastError = e;
          logger.warn('model_fetch', 'checksum_retry', kv: {
            'url': url,
            'attempt': attempt,
            'expected': e.expectedChecksum,
          });
          await _fileSystem.delete(tempPath);
          attempt++;
        } on ModelFetchNetworkException catch (e) {
          lastError = e;
          logger.warn('model_fetch', 'network_retry', kv: {
            'url': url,
            'attempt': attempt,
            'error': e.message,
          });
          // Keep the partial temp file so the next attempt can resume.
          attempt++;
        }
      }

      _status = FetchStatus.error;
      logger.error('model_fetch', 'fetch_exhausted',
          kv: {
            'url': url,
            'attempts': attempt,
          },
          errorKind: ErrorKind.external);
      if (lastError is Exception) {
        throw lastError;
      }
      throw ModelFetchException('Fetch exhausted after $attempt attempts');
    } finally {
      if (_activeToken == token) _activeToken = null;
    }
  }

  Future<void> _ensureDirectoryExists() async {
    if (!await directory.exists()) {
      await directory.create(recursive: true);
    }
  }

  Future<void> _preflightDiskSpace(String url) async {
    final requiredBytes = config.model.modelFileSizeBytes > 0
        ? config.model.modelFileSizeBytes * 2
        : config.model.minFreeDiskBytes;
    final freeBytes = await _diskSpaceProvider.freeBytes(directory);

    if (freeBytes < requiredBytes) {
      _status = FetchStatus.error;
      logger.error('model_fetch', 'insufficient_disk_space',
          kv: {
            'url': url,
            'required_bytes': requiredBytes,
            'free_bytes': freeBytes,
          },
          errorKind: ErrorKind.system);
      throw ModelFetchDiskSpaceException(requiredBytes, freeBytes);
    }

    logger.info('model_fetch', 'disk_space_ok', kv: {
      'required_bytes': requiredBytes,
      'free_bytes': freeBytes,
    });
  }

  Future<File> _download({
    required String url,
    required String tempPath,
    required String finalPath,
    required String expectedChecksum,
    required void Function(double progress)? onProgress,
    required _CancelToken token,
  }) async {
    // Re-fetch-on-corruption: if the final file exists but does not verify,
    // delete it and start over.
    if (await _fileSystem.exists(finalPath)) {
      _status = FetchStatus.verifying;
      if (await verifyFile(File(finalPath), expectedChecksum)) {
        _status = FetchStatus.complete;
        logger.success('model_fetch', 'final_file_verified', kv: {
          'path': finalPath,
        });
        return File(finalPath);
      }
      logger.warn('model_fetch', 'final_file_corrupt', kv: {
        'path': finalPath,
      });
      await _fileSystem.delete(finalPath);
    }

    var startByte = 0;
    if (await _fileSystem.exists(tempPath)) {
      startByte = await _fileSystem.length(tempPath);
      if (startByte > 0) {
        logger.info('model_fetch', 'resume_attempt', kv: {
          'url': url,
          'start_byte': startByte,
        });
      }
    }

    if (token.isCancelled) throw ModelFetchCancelledException();

    _status = FetchStatus.downloading;
    final response = await _httpClient.fetchRange(
      Uri.parse(url),
      start: startByte > 0 ? startByte : null,
    );

    if (response.statusCode == HttpStatus.ok && startByte > 0) {
      // Server ignored the Range header; restart from the beginning.
      logger.warn('model_fetch', 'range_not_supported', kv: {'url': url});
      startByte = 0;
      await _fileSystem.delete(tempPath);
    } else if (response.statusCode != HttpStatus.ok &&
        response.statusCode != HttpStatus.partialContent) {
      throw ModelFetchNetworkException('HTTP ${response.statusCode}');
    }

    final expectedTotal =
        response.totalLength ?? config.model.modelFileSizeBytes;
    final trackedBody = _trackProgress(
      response.body,
      bytesAlready: startByte,
      expectedTotal: expectedTotal > 0 ? expectedTotal : null,
      onProgress: onProgress,
      token: token,
    );

    await _fileSystem.writeStream(
      tempPath,
      trackedBody,
      mode: startByte > 0 ? FileMode.writeOnlyAppend : FileMode.write,
    );

    if (token.isCancelled) throw ModelFetchCancelledException();

    if (!await verifyFile(File(tempPath), expectedChecksum)) {
      throw ModelFetchChecksumException(expectedChecksum);
    }

    await _fileSystem.rename(tempPath, finalPath);
    _status = FetchStatus.complete;
    logger.success('model_fetch', 'download_complete', kv: {
      'url': url,
      'path': finalPath,
    });
    return File(finalPath);
  }

  Stream<List<int>> _trackProgress(
    Stream<List<int>> stream, {
    required int bytesAlready,
    required int? expectedTotal,
    required void Function(double progress)? onProgress,
    required _CancelToken token,
  }) {
    var received = bytesAlready;
    return stream.map((chunk) {
      if (token.isCancelled) throw ModelFetchCancelledException();
      received += chunk.length;
      if (expectedTotal != null && expectedTotal > 0) {
        onProgress?.call((received / expectedTotal).clamp(0.0, 1.0));
      } else {
        onProgress?.call(0.0);
      }
      return chunk;
    });
  }

  /// Verifies [file] against [expectedSha256].
  ///
  /// Returns `true` when the hashes match (case-insensitive), otherwise
  /// `false`. Structured log events are emitted either way.
  Future<bool> verifyFile(File file, String expectedSha256) async {
    _status = FetchStatus.verifying;
    final actual = (await _sha256(file.path)).toLowerCase();
    final expected = expectedSha256.toLowerCase();
    final ok = actual == expected;

    _status = ok ? FetchStatus.complete : FetchStatus.verifying;
    logger.log(
      ok ? LogLevel.success : LogLevel.error,
      'model_fetch',
      ok ? 'checksum_verified' : 'checksum_mismatch',
      kv: {
        'path': file.path,
        'expected': expected,
        'actual': actual,
      },
      errorKind: ok ? null : ErrorKind.external,
    );
    return ok;
  }

  Future<String> _sha256(String path) async {
    final sink = AccumulatorSink<Digest>();
    final conversion = sha256.startChunkedConversion(sink);
    await for (final chunk in _fileSystem.readStream(path)) {
      conversion.add(chunk);
    }
    conversion.close();
    return sink.events.single.toString();
  }

  String _fileNameFromUrl(String url) {
    final uri = Uri.parse(url);
    final segments = uri.pathSegments;
    if (segments.isEmpty) return 'model.bin';
    return segments.last;
  }
}
