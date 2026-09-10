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
    String? ifRange,
  });
}

/// Response returned by [ModelHttpClient.fetchRange].
class ModelHttpResponse {
  const ModelHttpResponse({
    required this.statusCode,
    required this.body,
    this.totalLength,
    this.contentLength,
    this.rangeStart,
    this.rangeEnd,
    this.etag,
  });

  final int statusCode;
  final Stream<List<int>> body;

  /// Total bytes in the resource, parsed from a `Content-Range` header.
  final int? totalLength;

  /// Bytes in this response body.
  final int? contentLength;
  final int? rangeStart, rangeEnd;
  final String? etag;
}

/// Default HTTP adapter backed by `dart:io` [HttpClient].
abstract interface class CancellableModelHttpClient {
  void cancel();
}

class DartIoHttpClientAdapter
    implements ModelHttpClient, CancellableModelHttpClient {
  DartIoHttpClientAdapter([this._logger, NetworkConfig? network])
      : network = network ?? loadConfig(environment: 'prod').network;
  final PsyLog? _logger;
  final NetworkConfig network;
  final _clients = <HttpClient>{};
  @override
  void cancel() {
    for (final client in _clients) {
      client.close(force: true);
    }
    _clients.clear();
  }

  @override
  Future<ModelHttpResponse> fetchRange(Uri url,
          {int? start, int? end, String? ifRange}) =>
      _fetchRange(url, start: start, end: end, ifRange: ifRange, redirects: 5);
  Future<ModelHttpResponse> _fetchRange(Uri url,
      {int? start, int? end, String? ifRange, required int redirects}) async {
    final loopback = ['127.0.0.1', '::1', 'localhost'].contains(url.host);
    if (url.host.isEmpty ||
        url.userInfo.isNotEmpty ||
        url.hasFragment ||
        (url.scheme != 'https' &&
            !(url.scheme == 'http' &&
                loopback &&
                network.allowInsecureLoopback))) {
      throw ModelFetchNetworkException('Unsafe model URL');
    }
    final client = HttpClient()
      ..connectionTimeout =
          Duration(milliseconds: network.connectTimeoutMillis);
    _clients.add(client);
    void close() {
      client.close(force: true);
      _clients.remove(client);
    }

    try {
      final request = await client
          .getUrl(url)
          .timeout(Duration(milliseconds: network.connectTimeoutMillis));
      request.followRedirects = false;
      request.headers.set(HttpHeaders.acceptEncodingHeader, 'identity');
      if (start != null) {
        request.headers.set(HttpHeaders.rangeHeader,
            end == null ? 'bytes=$start-' : 'bytes=$start-$end');
        if (ifRange != null) {
          request.headers.set(HttpHeaders.ifRangeHeader, ifRange);
        }
      }
      _logger?.debug('model_fetch', 'http_request',
          kv: {'host': url.host, if (start != null) 'range_start': start});
      final response = await request
          .close()
          .timeout(Duration(milliseconds: network.readTimeoutMillis));
      if ([301, 302, 303, 307, 308].contains(response.statusCode)) {
        final location = response.headers.value(HttpHeaders.locationHeader);
        close();
        if (location == null || redirects == 0) {
          throw ModelFetchNetworkException(
              'Invalid or excessive artifact redirects');
        }
        final next = url.resolve(location);
        if (url.scheme == 'https' && next.scheme != 'https') {
          throw ModelFetchNetworkException(
              'Artifact redirect would downgrade transport');
        }
        return _fetchRange(next,
            start: start, end: end, ifRange: ifRange, redirects: redirects - 1);
      }
      final header = response.headers.value(HttpHeaders.contentRangeHeader);
      final match = header == null
          ? null
          : RegExp(r'^bytes ([0-9]+)-([0-9]+)/([0-9]+)$').firstMatch(header);
      Stream<List<int>> body() async* {
        try {
          yield* response
              .timeout(Duration(milliseconds: network.receiveTimeoutMillis));
        } finally {
          close();
        }
      }

      return ModelHttpResponse(
          statusCode: response.statusCode,
          body: body(),
          totalLength: match == null ? null : int.tryParse(match.group(3)!),
          rangeStart: match == null ? null : int.tryParse(match.group(1)!),
          rangeEnd: match == null ? null : int.tryParse(match.group(2)!),
          contentLength:
              response.contentLength < 0 ? null : response.contentLength,
          etag: response.headers.value(HttpHeaders.etagHeader));
    } catch (_) {
      close();
      rethrow;
    }
  }
}

/// Disk-space seam so tests can control the preflight result.
abstract class DiskSpaceProvider {
  Future<int> freeBytes(Directory directory);
}

/// Uses portable POSIX df units; an unavailable measurement never invents space.
class DefaultDiskSpaceProvider implements DiskSpaceProvider {
  const DefaultDiskSpaceProvider();
  @override
  Future<int> freeBytes(Directory directory) async {
    if (Platform.isWindows) {
      throw ModelFetchException(
          'Disk space measurement is unavailable on this platform');
    }
    try {
      final result = await Process.run('df', ['-Pk', directory.path])
          .timeout(const Duration(seconds: 5));
      if (result.exitCode != 0) {
        throw ModelFetchException('Disk space measurement failed');
      }
      final lines = LineSplitter.split(result.stdout.toString())
          .where((line) => line.trim().isNotEmpty)
          .toList();
      final parts = lines.last.trim().split(RegExp(r'\s+'));
      final blocks = parts.length < 4 ? null : int.tryParse(parts[3]);
      if (blocks == null || blocks < 0) {
        throw ModelFetchException('Disk space measurement was invalid');
      }
      return blocks * 1024;
    } on ModelFetchException {
      rethrow;
    } catch (_) {
      throw ModelFetchException('Disk space measurement is unavailable');
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
  final _cancelled = Completer<void>();
  bool get isCancelled => _cancelled.isCompleted;
  Future<void> get cancelled => _cancelled.future;
  void cancel() {
    if (!isCancelled) _cancelled.complete();
  }
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
  })  : _httpClient =
            httpClient ?? DartIoHttpClientAdapter(logger, config.network),
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
  static final _pendingPaths = <String, Future<void>>{};
  Future<T> _serialize<T>(
      String path, _CancelToken token, Future<T> Function() action) {
    final previous = _pendingPaths[path] ?? Future<void>.value();
    final complete = Completer<void>();
    final result = Completer<T>();
    var started = false;
    _pendingPaths[path] = complete.future;
    token.cancelled.then((_) {
      // A queued caller can leave immediately, but its queue slot stays behind
      // the active writer until that writer has finished all file operations.
      if (!started && !result.isCompleted) {
        result.completeError(ModelFetchCancelledException());
      }
    });
    previous.then((_) async {
      try {
        if (token.isCancelled) {
          if (!result.isCompleted) {
            result.completeError(ModelFetchCancelledException());
          }
          return;
        }
        started = true;
        result.complete(await action());
      } catch (error, stack) {
        result.completeError(error, stack);
      } finally {
        complete.complete();
        if (identical(_pendingPaths[path], complete.future)) {
          _pendingPaths.remove(path);
        }
      }
    });
    return result.future;
  }

  static bool _strongEtag(Object? value) =>
      value is String &&
      value.length <= 1024 &&
      RegExp(r'^"[\x21\x23-\x7e]*"$').hasMatch(value);

  /// Cancels the in-flight fetch. The next cancellation check will throw
  /// [ModelFetchCancelledException]. Safe to call when idle.
  void cancel() {
    logger.info('model_fetch', 'cancellation_requested');
    _activeToken?.cancel();
    if (_httpClient is CancellableModelHttpClient) {
      (_httpClient as CancellableModelHttpClient).cancel();
    }
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
    if (_activeToken != null) {
      throw StateError('A model fetch is already active');
    }
    if (meteredConnection) {
      _status = FetchStatus.error;
      throw ModelFetchMeteredException(url);
    }
    final fileName = _fileNameFromUrl(url);
    if (!RegExp(r'^(sha256:)?[0-9a-fA-F]{64}$').hasMatch(expectedChecksum)) {
      throw ModelFetchException('A pinned SHA-256 is required');
    }
    expectedChecksum =
        expectedChecksum.replaceFirst('sha256:', '').toLowerCase();
    final tempPath = p.join(directory.path, '$fileName.tmp');
    final finalPath = p.join(directory.path, fileName);
    final token = _CancelToken();
    _activeToken = token;
    try {
      return await _serialize(p.normalize(p.absolute(finalPath)), token,
          () async {
        _status = FetchStatus.pending;
        logger.info('model_fetch', 'fetch_started', kv: {
          'host': Uri.parse(url).host,
          'metered_connection': meteredConnection,
        });

        if (meteredConnection) {
          _status = FetchStatus.error;
          logger.warn('model_fetch', 'fetch_deferred_metered',
              kv: {'host': Uri.parse(url).host});
          throw ModelFetchMeteredException(url);
        }

        await _ensureDirectoryExists();
        if (await directory.resolveSymbolicLinks() !=
            p.normalize(p.absolute(directory.path))) {
          throw ModelFetchException('Symlinked model cache is unsupported');
        }
        for (final path in [
          finalPath,
          tempPath,
          '$tempPath.meta',
          '$tempPath.meta.new'
        ]) {
          final type = await FileSystemEntity.type(path, followLinks: false);
          if (type != FileSystemEntityType.notFound &&
              type != FileSystemEntityType.file) {
            throw ModelFetchException(
                'Model cache contains an unsafe filesystem entry');
          }
        }
        if (token.isCancelled) throw ModelFetchCancelledException();
        if (await _fileSystem.exists(finalPath) &&
            await verifyFile(File(finalPath), expectedChecksum)) {
          if (token.isCancelled) throw ModelFetchCancelledException();
          return File(finalPath);
        }
        final freeBytes = await _preflightDiskSpace(url);

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
              maxDownloadBytes: freeBytes ~/ 2,
            );
          } on ModelFetchChecksumException catch (e) {
            lastError = e;
            logger.warn('model_fetch', 'checksum_retry', kv: {
              'host': Uri.parse(url).host,
              'attempt': attempt,
              'expected': e.expectedChecksum,
            });
            await _fileSystem.delete(tempPath);
            await _fileSystem.delete('$tempPath.meta');
            attempt++;
          } on ModelFetchNetworkException catch (e) {
            lastError = e;
            logger.warn('model_fetch', 'network_retry', kv: {
              'host': Uri.parse(url).host,
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
              'host': Uri.parse(url).host,
              'attempts': attempt,
            },
            errorKind: ErrorKind.external);
        if (lastError is Exception) {
          throw lastError;
        }
        throw ModelFetchException('Fetch exhausted after $attempt attempts');
      });
    } catch (_) {
      _status = FetchStatus.error;
      if (token.isCancelled) throw ModelFetchCancelledException();
      rethrow;
    } finally {
      if (_httpClient is CancellableModelHttpClient) {
        (_httpClient as CancellableModelHttpClient).cancel();
      }
      if (_activeToken == token) _activeToken = null;
    }
  }

  Future<void> _ensureDirectoryExists() async {
    if (!await directory.exists()) {
      await directory.create(recursive: true);
    }
  }

  Future<int> _preflightDiskSpace(String url) async {
    final requiredBytes = config.model.modelFileSizeBytes > 0
        ? config.model.modelFileSizeBytes * 2
        : config.model.minFreeDiskBytes;
    final freeBytes = await _diskSpaceProvider.freeBytes(directory);

    if (freeBytes < requiredBytes) {
      _status = FetchStatus.error;
      logger.error('model_fetch', 'insufficient_disk_space',
          kv: {
            'host': Uri.parse(url).host,
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
    return freeBytes;
  }

  Future<File> _download({
    required String url,
    required String tempPath,
    required String finalPath,
    required String expectedChecksum,
    required void Function(double progress)? onProgress,
    required _CancelToken token,
    required int maxDownloadBytes,
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
    final metadataPath = '$tempPath.meta';
    Map<String, Object?>? metadata;
    if (await _fileSystem.exists(tempPath) &&
        await _fileSystem.exists(metadataPath)) {
      try {
        if (await _fileSystem.length(metadataPath) > 16384) {
          throw const FormatException();
        }
        final raw = await _fileSystem
            .readStream(metadataPath)
            .expand((chunk) => chunk)
            .toList();
        metadata = jsonDecode(utf8.decode(raw)) as Map<String, Object?>;
        final total = metadata['total_length'];
        final partialLength = await _fileSystem.length(tempPath);
        if (metadata['url'] != url ||
            metadata['checksum'] != expectedChecksum ||
            (metadata.containsKey('etag') && !_strongEtag(metadata['etag'])) ||
            (metadata.containsKey('total_length') &&
                (total is! int ||
                    total <= 0 ||
                    total < partialLength ||
                    total > maxDownloadBytes))) {
          metadata = null;
        }
      } catch (_) {
        metadata = null;
      }
    }
    if (metadata == null) {
      await _fileSystem.delete(tempPath);
      await _fileSystem.delete(metadataPath);
    } else {
      startByte = await _fileSystem.length(tempPath);
      if (await verifyFile(File(tempPath), expectedChecksum)) {
        if (token.isCancelled) throw ModelFetchCancelledException();
        await _fileSystem.rename(tempPath, finalPath);
        await _fileSystem.delete(metadataPath);
        return File(finalPath);
      }
    }
    if (token.isCancelled) throw ModelFetchCancelledException();
    _status = FetchStatus.downloading;
    late ModelHttpResponse response;
    try {
      response = await _httpClient.fetchRange(Uri.parse(url),
          start: startByte > 0 ? startByte : null,
          ifRange: startByte > 0 ? (metadata?['etag'] as String?) : null);
    } on IOException catch (_) {
      throw ModelFetchNetworkException('Connection failed');
    } on TimeoutException {
      throw ModelFetchNetworkException('Response timed out');
    }
    Future<void> discardResponse() async {
      await response.body.listen((_) {}).cancel();
    }

    if (response.statusCode == HttpStatus.ok && startByte > 0) {
      startByte = 0;
      await _fileSystem.delete(tempPath);
    } else if (response.statusCode != HttpStatus.ok &&
        response.statusCode != HttpStatus.partialContent) {
      await discardResponse();
      if (response.statusCode == 416) {
        await _fileSystem.delete(tempPath);
        await _fileSystem.delete(metadataPath);
      }
      throw ModelFetchNetworkException('HTTP ${response.statusCode}');
    }
    final total = response.totalLength ?? response.contentLength;
    final badRange = response.statusCode == 206 &&
        (response.rangeStart != startByte ||
            response.rangeEnd == null ||
            response.totalLength == null ||
            response.rangeEnd! < startByte ||
            response.rangeEnd! >= response.totalLength! ||
            (response.contentLength != null &&
                response.contentLength != response.rangeEnd! - startByte + 1) ||
            (metadata?['total_length'] != null &&
                metadata!['total_length'] != response.totalLength) ||
            (metadata?['etag'] != null && metadata!['etag'] != response.etag));
    if (badRange) {
      await discardResponse();
      await _fileSystem.delete(tempPath);
      await _fileSystem.delete(metadataPath);
      throw ModelFetchNetworkException(
          'Resume response does not match the saved artifact');
    }
    if (total != null && total > maxDownloadBytes) {
      await discardResponse();
      throw ModelFetchDiskSpaceException(total * 2, maxDownloadBytes * 2);
    }
    final etag = response.etag;
    final resume = {
      'url': url,
      'checksum': expectedChecksum,
      if (_strongEtag(etag)) 'etag': etag,
      if (total != null) 'total_length': total
    };
    try {
      await _fileSystem.writeStream(
          '$metadataPath.new', Stream.value(utf8.encode(jsonEncode(resume))));
      await _fileSystem.rename('$metadataPath.new', metadataPath);
    } finally {
      await _fileSystem.delete('$metadataPath.new');
    }
    final expectedTotal =
        response.totalLength ?? (startByte + (response.contentLength ?? 0));
    final trackedBody = _trackProgress(response.body,
        bytesAlready: startByte,
        expectedTotal: expectedTotal > 0 ? expectedTotal : null,
        maxBytes: maxDownloadBytes,
        onProgress: onProgress,
        token: token);
    try {
      await _fileSystem.writeStream(tempPath, trackedBody,
          mode: startByte > 0 ? FileMode.writeOnlyAppend : FileMode.write);
    } on HttpException {
      throw ModelFetchNetworkException('Transfer interrupted');
    } on SocketException {
      throw ModelFetchNetworkException('Connection interrupted');
    } on TimeoutException {
      throw ModelFetchNetworkException('Transfer stalled');
    }

    if (token.isCancelled) throw ModelFetchCancelledException();

    if (!await verifyFile(File(tempPath), expectedChecksum)) {
      throw ModelFetchChecksumException(expectedChecksum);
    }

    if (token.isCancelled) throw ModelFetchCancelledException();
    await _fileSystem.rename(tempPath, finalPath);
    await _fileSystem.delete(metadataPath);
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
    required int maxBytes,
    required void Function(double progress)? onProgress,
    required _CancelToken token,
  }) {
    var received = bytesAlready;
    return stream.map((chunk) {
      if (token.isCancelled) throw ModelFetchCancelledException();
      received += chunk.length;
      if (received > maxBytes) {
        throw ModelFetchDiskSpaceException(received * 2, maxBytes * 2);
      }
      if (expectedTotal != null && received > expectedTotal) {
        throw ModelFetchNetworkException(
            'Response exceeds the declared artifact length');
      }
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
      if (_activeToken?.isCancelled == true) {
        throw ModelFetchCancelledException();
      }
      conversion.add(chunk);
    }
    conversion.close();
    return sink.events.single.toString();
  }

  String _fileNameFromUrl(String url) {
    final uri = Uri.parse(url);
    if (!uri.hasAuthority ||
        uri.userInfo.isNotEmpty ||
        uri.hasFragment ||
        uri.pathSegments.isEmpty) {
      throw ModelFetchException('Invalid model URL');
    }
    final name = uri.pathSegments.last;
    if (name.isEmpty ||
        name == '.' ||
        name == '..' ||
        name.contains('/') ||
        name.contains('\\') ||
        name.codeUnits.any((unit) => unit < 32) ||
        name.length > 240) {
      throw ModelFetchException('Invalid model filename');
    }
    return name;
  }
}
