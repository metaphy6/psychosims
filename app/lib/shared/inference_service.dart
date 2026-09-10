import 'dart:async';
import 'dart:convert';
import 'dart:ffi' as ffi;
import 'dart:ffi' show NativeCallable;
import 'dart:io';
import 'dart:isolate';

import 'package:ffi/ffi.dart';
import 'package:psycore/psycore.dart' as core;

import 'generated/psychosims_native_bindings.dart';
import 'logger.dart';

/// Parameters for loading a model context.
class ModelLoadParams {
  final int nCtx;
  final int nBatch;
  final int nThreads;
  final bool useMmap;

  /// Explicit development backend; normal application loads use llama.cpp.
  final String backend;
  final String? kvCacheType;
  final String? correlationId;

  const ModelLoadParams({
    this.nCtx = 2048,
    this.nBatch = 512,
    this.nThreads = 4,
    this.useMmap = true,
    this.backend = 'llama.cpp',
    this.kvCacheType,
    this.correlationId,
  });

  Map<String, Object?> toJson() => {
        'n_ctx': nCtx,
        'n_batch': nBatch,
        'n_threads': nThreads,
        'use_mmap': useMmap,
        'backend': backend,
        if (kvCacheType != null && kvCacheType!.isNotEmpty)
          'kv_cache_type': kvCacheType,
        if (correlationId != null && correlationId!.isNotEmpty)
          'correlation_id': correlationId,
      };
}

/// Parameters for a single generation request.
class GenerationParams {
  final String prompt;
  final int maxTokens;
  final double temperature;
  final double topP;
  final int topK;
  final double repetitionPenalty;
  final int seed;
  final List<String> stopTokens;
  final String? grammar;

  const GenerationParams({
    required this.prompt,
    this.maxTokens = 128,
    this.temperature = 0.7,
    this.topP = 0.9,
    this.topK = 40,
    this.repetitionPenalty = 1.0,
    this.seed = 42,
    this.stopTokens = const [],
    this.grammar,
  });

  Map<String, Object?> toJson() => {
        'prompt': prompt,
        'max_tokens': maxTokens,
        'temperature': temperature,
        'top_p': topP,
        'top_k': topK,
        'repetition_penalty': repetitionPenalty,
        'seed': seed,
        'stop': stopTokens,
        if (grammar != null && grammar!.isNotEmpty) 'grammar': grammar,
      };
}

/// Error taxonomy for inference failures (0.7).
enum InferenceErrorKind {
  missingModel,
  corruptModel,
  unsupportedAbi,
  loadFailure,
  outOfMemory,
  cancelled,
  generationError,
  contextOverflow,
}

/// Typed exception thrown by [InferenceService].
class InferenceException implements Exception {
  InferenceException(this.message,
      {this.kind = InferenceErrorKind.generationError});

  final String message;
  final InferenceErrorKind kind;

  @override
  String toString() => 'InferenceException: $message';
}

// ---------------------------------------------------------------------------
// Worker isolate protocol
// ---------------------------------------------------------------------------

sealed class _WorkerRequest {}

class _LoadRequest implements _WorkerRequest {
  _LoadRequest(this.modelPath, this.paramsJson);
  final String modelPath;
  final String paramsJson;
}

class _GenerateRequest implements _WorkerRequest {
  _GenerateRequest(this.paramsJson);
  final String paramsJson;
}

class _UnloadRequest implements _WorkerRequest {}

class _ResetKvRequest implements _WorkerRequest {}

class _DisposeRequest implements _WorkerRequest {}

sealed class _WorkerResponse {}

class _PortResponse implements _WorkerResponse {
  _PortResponse(this.sendPort);
  final SendPort sendPort;
}

class _LoadedResponse implements _WorkerResponse {
  _LoadedResponse({required this.success, this.contextAddress, this.error});
  final bool success;
  final int? contextAddress;
  final String? error;
}

class _TokenResponse implements _WorkerResponse {
  _TokenResponse(this.text, this.isCompleteCodepoint);
  final String text;
  final bool isCompleteCodepoint;
}

class _GenerateDoneResponse implements _WorkerResponse {
  _GenerateDoneResponse(this.result, this.stats);
  final int result;
  final Map<String, Object?> stats;
}

class _DisposedResponse implements _WorkerResponse {}

class _ErrorResponse implements _WorkerResponse {
  _ErrorResponse(this.message);
  final String message;
}

// ---------------------------------------------------------------------------
// Worker isolate entry point
// ---------------------------------------------------------------------------

/// Lightweight native wrapper used only inside the worker isolate.
///
/// Unlike [InferenceService], this class never spawns another isolate and has
/// no generation lock; the main isolate already serializes requests.
class _WorkerService {
  _WorkerService(this._libraryPath);

  final String? _libraryPath;
  late final PsychosimsNativeBindings _bindings =
      PsychosimsNativeBindings(InferenceService._openLibrary(_libraryPath));
  ffi.Pointer<PsyContext>? _ctx;

  bool get isLoaded => _ctx != null;

  void load(String modelPath, String paramsJson) {
    unload();
    final pathPtr = modelPath.toNativeUtf8();
    final paramsPtr = paramsJson.toNativeUtf8();
    try {
      _ctx = _bindings.psy_context_load(pathPtr.cast(), paramsPtr.cast());
      if (_ctx == null || _ctx!.address == 0) {
        _ctx = null;
        throw InferenceException('Failed to load model at $modelPath');
      }
    } finally {
      calloc.free(pathPtr);
      calloc.free(paramsPtr);
    }
  }

  void unload() {
    if (_ctx != null) {
      _bindings.psy_context_destroy(_ctx!);
      _ctx = null;
    }
  }

  void resetKvCache() {
    if (_ctx != null) _bindings.psy_reset_kv(_ctx!);
  }

  Map<String, Object?> lastGenerateStats() {
    if (_ctx == null) return const {};
    return jsonDecode(_bindings
        .psy_last_generate_stats(_ctx!)
        .cast<Utf8>()
        .toDartString()) as Map<String, Object?>;
  }

  int generate(
    String paramsJson,
    NativeCallable<PsyTokenCallbackFunction> callback,
  ) {
    final paramsPtr = paramsJson.toNativeUtf8();
    try {
      return _bindings.psy_generate(
        _ctx!,
        paramsPtr.cast(),
        callback.nativeFunction,
        ffi.nullptr,
      );
    } finally {
      calloc.free(paramsPtr);
    }
  }
}

/// Accumulates raw token bytes and emits only complete UTF-8 codepoints.
///
/// Real tokenizers can split a multi-byte Unicode codepoint across two or more
/// tokens. Holding the partial sequence until it is complete prevents the UI
/// from rendering mojibake or split graphemes.
class _Utf8Accumulator {
  final _bytes = <int>[];

  /// Appends [text] bytes and returns the complete codepoints that can now be
  /// decoded, or an empty string if [isComplete] is false and the bytes form
  /// only a partial codepoint.
  String add(String text, bool isComplete) =>
      addBytes(utf8.encode(text), isComplete);

  /// Appends raw [bytes] directly from the native callback. This avoids an
  /// intermediate Dart-string decode that would corrupt partial codepoints.
  String addBytes(List<int> bytes, bool isComplete) {
    _bytes.addAll(bytes);
    if (!isComplete) return '';
    final decoded = utf8.decode(_bytes, allowMalformed: true);
    _bytes.clear();
    return decoded;
  }

  /// Flushes any remaining bytes, returning the best-effort decoded text.
  String flush() {
    if (_bytes.isEmpty) return '';
    final decoded = utf8.decode(_bytes, allowMalformed: true);
    _bytes.clear();
    return decoded;
  }
}

/// Reads the raw UTF-8 bytes from a null-terminated native token string.
List<int> _readTokenBytes(ffi.Pointer<ffi.Char> ptr) {
  const maxLen = 4096;
  final view = ptr.cast<ffi.Uint8>().asTypedList(maxLen);
  var len = 0;
  while (len < maxLen && view[len] != 0) {
    len++;
  }
  return view.sublist(0, len);
}

void _inferenceWorker(Map<String, Object?> init) {
  final receivePort = ReceivePort();
  final mainSendPort = init['port']! as SendPort;
  final libraryPath = init['lib'] as String?;
  mainSendPort.send(_PortResponse(receivePort.sendPort));

  _WorkerService? service;
  NativeCallable<PsyTokenCallbackFunction>? tokenCallback;
  _Utf8Accumulator? utf8Accumulator;

  void disposeCallback() {
    tokenCallback?.close();
    tokenCallback = null;
  }

  receivePort.listen((message) {
    final request = message as _WorkerRequest;

    if (request is _DisposeRequest) {
      disposeCallback();
      service?.unload();
      service = null;
      mainSendPort.send(_DisposedResponse());
      receivePort.close();
      return;
    }

    if (request is _LoadRequest) {
      try {
        service ??= _WorkerService(libraryPath);
        service!.load(request.modelPath, request.paramsJson);
        mainSendPort.send(_LoadedResponse(
            success: true, contextAddress: service!._ctx!.address));
      } on InferenceException catch (e) {
        mainSendPort.send(_LoadedResponse(success: false, error: e.message));
      } on Exception catch (e) {
        mainSendPort.send(_LoadedResponse(success: false, error: e.toString()));
      }
      return;
    }

    final s = service;
    if (s == null) {
      mainSendPort.send(_ErrorResponse('No model loaded in worker'));
      return;
    }

    if (request is _UnloadRequest) {
      disposeCallback();
      s.unload();
    } else if (request is _ResetKvRequest) {
      s.resetKvCache();
    } else if (request is _GenerateRequest) {
      disposeCallback();
      utf8Accumulator = _Utf8Accumulator();

      void onNativeToken(
        ffi.Pointer<ffi.Char> tokenText,
        int tokenId,
        int isCodepointComplete,
        ffi.Pointer<ffi.Void> _,
      ) {
        final bytes = _readTokenBytes(tokenText);
        final complete =
            utf8Accumulator!.addBytes(bytes, isCodepointComplete != 0);
        if (complete.isNotEmpty) {
          mainSendPort.send(_TokenResponse(complete, true));
        }
      }

      tokenCallback = NativeCallable<PsyTokenCallbackFunction>.isolateLocal(
        onNativeToken,
      );

      try {
        final result = s.generate(request.paramsJson, tokenCallback!);
        final flush = utf8Accumulator!.flush();
        if (flush.isNotEmpty) {
          mainSendPort.send(_TokenResponse(flush, true));
        }
        mainSendPort.send(_GenerateDoneResponse(result, s.lastGenerateStats()));
      } on Exception catch (e) {
        mainSendPort.send(_ErrorResponse(e.toString()));
      } finally {
        utf8Accumulator = null;
      }
    }
  });
}

/// Narrow, typed seam over the native inference backend.
///
/// Implements [core.TokenCounter] and [core.ChatTemplate] so the prompt
/// assembler can consume the active model's real tokenizer and chat template
/// once a model is loaded. No other module touches the FFI directly.
///
/// The worker owns the only native model/context and loads it asynchronously.
/// The UI borrows its handle for read-only tokenizer/template operations and
/// the native thread-safe cancellation flag. All context mutations and frees
/// run on the worker, serialized after active generation completes.
class InferenceService implements core.TokenCounter, core.ChatTemplate {
  InferenceService._(this._logger, this._libraryPath);

  /// Loads the native library in the current isolate.
  ///
  /// Generation is still offloaded to a worker isolate created lazily on first
  /// [generate] call. Use this factory from the UI isolate; cheap operations
  /// such as tokenization execute here, while heavy decode runs elsewhere.
  factory InferenceService.load({
    String? libraryPath,
    required PsyLog logger,
  }) {
    final lib = _openLibrary(libraryPath);
    logger.info('inference', 'native_library_opened', kv: {
      if (libraryPath != null) 'path': libraryPath,
      'platform': Platform.operatingSystem,
    });
    return InferenceService._(logger, libraryPath)
      .._bindings = PsychosimsNativeBindings(lib);
  }

  static ffi.DynamicLibrary _openLibrary(String? path) {
    if (path != null && path.isNotEmpty) {
      return ffi.DynamicLibrary.open(path);
    }
    if (Platform.isAndroid || Platform.isLinux) {
      return ffi.DynamicLibrary.open('libpsychosims_native.so');
    }
    if (Platform.isWindows) {
      return ffi.DynamicLibrary.open('psychosims_native.dll');
    }
    if (Platform.isMacOS) {
      return ffi.DynamicLibrary.open('libpsychosims_native.dylib');
    }
    throw InferenceException(
      'Native inference not supported on ${Platform.operatingSystem}',
      kind: InferenceErrorKind.unsupportedAbi,
    );
  }

  late final PsychosimsNativeBindings _bindings;
  final PsyLog _logger;
  final String? _libraryPath;
  // Borrowed from the worker; this isolate must never destroy this context.
  ffi.Pointer<PsyContext>? _ctx;
  Map<String, Object?> _lastStats = const {};

  Isolate? _worker;
  SendPort? _workerSendPort;
  Future<void>? _workerInitFuture;
  final _receivePort = ReceivePort();
  final _responseController = StreamController<_WorkerResponse>.broadcast();

  final _generationLock = Lock();
  bool _generationInFlight = false;
  bool _cancelRequested = false;
  bool _disposed = false;

  bool get isLoaded => _ctx != null;

  /// Native library version string (e.g. "psychosims-native-0.1.0").
  String get version => _bindings.psy_version().cast<Utf8>().toDartString();

  Future<void> _ensureWorker() {
    if (_disposed) {
      return Future.error(InferenceException('Service is disposed'));
    }
    if (_workerSendPort != null) return Future.value();
    return _workerInitFuture ??= _initWorker();
  }

  Future<void> _initWorker() async {
    final completer = Completer<void>();

    _receivePort.listen((message) {
      final response = message as _WorkerResponse;
      if (response is _PortResponse && _workerSendPort == null) {
        _workerSendPort = response.sendPort;
        _logger.debug('inference', 'worker_port_received');
        completer.complete();
      }
      _responseController.add(response);
    });

    _worker = await Isolate.spawn(
      _inferenceWorker,
      <String, Object?>{
        'port': _receivePort.sendPort,
        'lib': _libraryPath,
      },
      debugName: 'psychosims_inference_worker',
    );

    await completer.future;
  }

  void _send(_WorkerRequest request) {
    if (_workerSendPort == null) {
      throw InferenceException('Worker not initialized');
    }
    _workerSendPort!.send(request);
  }

  /// Loads a model from [modelPath] with load-time parameters in [params].
  ///
  /// One worker-owned context serves tokenizer, template and generation calls.
  Future<void> loadModel(
    String modelPath, {
    ModelLoadParams params = const ModelLoadParams(),
  }) async {
    if (_disposed) throw InferenceException('Service is disposed');
    if (_generationInFlight) {
      throw InferenceException('Cannot load a model during generation');
    }
    await _generationLock.synchronized(() async {
      if (_disposed) throw InferenceException('Service is disposed');
      _ctx = null;
      _lastStats = const {};
      await _ensureWorker();
      final completer = Completer<void>();
      late final StreamSubscription<_WorkerResponse> sub;
      sub = _responseController.stream.listen((response) {
        if (response is _LoadedResponse) {
          if (response.success) {
            _ctx =
                ffi.Pointer<PsyContext>.fromAddress(response.contextAddress!);
            completer.complete();
          } else {
            completer.completeError(InferenceException(
              response.error ?? 'Worker failed to load model at $modelPath',
              kind: InferenceErrorKind.loadFailure,
            ));
          }
          sub.cancel();
        } else if (response is _ErrorResponse) {
          completer.completeError(InferenceException(response.message));
          sub.cancel();
        }
      });
      _send(_LoadRequest(modelPath, jsonEncode(params.toJson())));
      await completer.future;
      _logger.success('inference', 'model_loaded', kv: {
        'backend': params.backend,
        'n_ctx': params.nCtx,
        'n_batch': params.nBatch,
      });
    });
  }

  /// Runs a short warm-up generation so the first real turn is not a latency
  /// outlier. Safe to call after [loadModel]; no-op if no model is loaded.
  Future<void> warmUp() async {
    if (_ctx == null || _disposed) return;
    await generate(
      const GenerationParams(prompt: 'hello', maxTokens: 1),
      (_, __) {},
    );
    _logger.info('inference', 'warmup_complete');
  }

  /// Unloads the model and frees native resources.
  void unloadModel() {
    if (_generationLock.locked && !_generationInFlight) {
      throw InferenceException('Cannot unload while loading or disposing');
    }
    if (_ctx == null && _worker == null) return;
    cancel();
    _ctx = null;
    _lastStats = const {};
    if (_worker != null) {
      _send(_UnloadRequest());
    }
    _logger.info('inference', 'model_unloaded');
  }

  /// Resets the KV cache without unloading the model.
  void resetKvCache() {
    if (_worker != null) _send(_ResetKvRequest());
  }

  /// Returns model metadata as a JSON object, or an empty map if unloaded.
  Map<String, Object?> metadata() {
    if (_ctx == null) return const {};
    final ptr = _bindings.psy_model_metadata(_ctx!);
    final json = ptr.cast<Utf8>().toDartString();
    try {
      return jsonDecode(json) as Map<String, Object?>;
    } on FormatException {
      return const {};
    }
  }

  /// Returns statistics for the last generation as a JSON object.
  ///
  /// Fields include `prompt_tokens`, `prompt_eval_ms`, `generated_tokens`,
  /// `generation_ms`, and `total_ms`. Returns an empty map if unloaded.
  Map<String, Object?> lastGenerateStats() {
    if (_ctx == null) return const {};
    return Map.unmodifiable(_lastStats);
  }

  @override
  int count(String text) {
    if (_ctx == null) return const core.WhitespaceTokenCounter().count(text);
    final textPtr = text.toNativeUtf8();
    try {
      final n = _bindings.psy_tokenize(
        _ctx!,
        textPtr.cast(),
        ffi.nullptr,
        0,
      );
      return n < 0 ? 0 : n;
    } finally {
      calloc.free(textPtr);
    }
  }

  @override
  String render({
    required String systemFrame,
    required List<core.ConversationTurn> turns,
  }) {
    if (_ctx == null) {
      return const core.PlainChatTemplate().render(
        systemFrame: systemFrame,
        turns: turns,
      );
    }
    final conversation = _conversationJson(systemFrame, turns);
    final jsonPtr = conversation.toNativeUtf8();
    var outPtr = calloc<ffi.Char>(4096);
    try {
      var written = _bindings.psy_apply_chat_template(
        _ctx!,
        jsonPtr.cast(),
        outPtr,
        4096,
      );
      if (written >= 4096) {
        calloc.free(outPtr);
        final capacity = written + 1;
        outPtr = calloc<ffi.Char>(capacity);
        written = _bindings.psy_apply_chat_template(
            _ctx!, jsonPtr.cast(), outPtr, capacity);
      }
      if (written < 0) {
        return const core.PlainChatTemplate().render(
          systemFrame: systemFrame,
          turns: turns,
        );
      }
      return outPtr.cast<Utf8>().toDartString();
    } finally {
      calloc.free(jsonPtr);
      calloc.free(outPtr);
    }
  }

  static String _conversationJson(
    String systemFrame,
    List<core.ConversationTurn> turns,
  ) {
    final messages = <Map<String, Object?>>[
      {'role': 'system', 'content': systemFrame},
      for (final t in turns) {'role': t.role, 'content': t.text},
    ];
    return jsonEncode(messages);
  }

  /// Verifies that the prompt plus the requested max output fit in the
  /// configured context window. Throws [InferenceException] with
  /// [InferenceErrorKind.contextOverflow] when it does not.
  void guardContextWindow({
    required String prompt,
    required int maxOutputTokens,
    required int nCtx,
  }) {
    final promptTokens = count(prompt);
    final total = promptTokens + maxOutputTokens;
    if (total > nCtx) {
      throw InferenceException(
        'Prompt ($promptTokens tokens) + max output ($maxOutputTokens tokens) '
        'exceeds context window ($nCtx)',
        kind: InferenceErrorKind.contextOverflow,
      );
    }
  }

  /// Generates tokens from [params], streaming each complete token to [onToken].
  ///
  /// [correlationId] is forwarded to the native layer so every log line for
  /// this turn shares the same session identifier.
  ///
  /// Returns once generation completes, is cancelled, or errors. Only one
  /// generation may be in flight at a time; concurrent calls are rejected
  /// with [InferenceException] to prevent races against the native context.
  /// [nCtx], when positive, applies an additional caller cap; omission uses
  /// the actual loaded model context and a caller can never enlarge it.
  Future<void> generate(
    GenerationParams params,
    void Function(String token, bool isCompleteCodepoint) onToken, {
    String? correlationId,
    int nCtx = 0,
  }) async {
    if (_generationInFlight) {
      throw InferenceException(
        'A generation is already in flight',
        kind: InferenceErrorKind.generationError,
      );
    }

    await _generationLock.synchronized(() async {
      _generationInFlight = true;
      _cancelRequested = false;
      try {
        if (_ctx == null) {
          throw InferenceException(
            'Cannot generate: no model loaded',
            kind: InferenceErrorKind.missingModel,
          );
        }

        final loadedContext = metadata()['n_ctx'];
        if (loadedContext is! int || loadedContext <= 0) {
          throw InferenceException('Loaded model context size is unavailable',
              kind: InferenceErrorKind.loadFailure);
        }
        guardContextWindow(
          prompt: params.prompt,
          maxOutputTokens: params.maxTokens,
          nCtx: nCtx > 0 && nCtx < loadedContext ? nCtx : loadedContext,
        );

        await _ensureWorker();

        final jsonParams = params.toJson();
        if (correlationId != null && correlationId.isNotEmpty) {
          jsonParams['correlation_id'] = correlationId;
        }
        final paramsJson = jsonEncode(jsonParams);

        final completer = Completer<void>();
        final buffer = StringBuffer();
        late final StreamSubscription<_WorkerResponse> sub;

        sub = _responseController.stream.listen((response) {
          if (response is _TokenResponse) {
            buffer.write(response.text);
            onToken(response.text, response.isCompleteCodepoint);
          } else if (response is _GenerateDoneResponse) {
            sub.cancel();
            _lastStats = response.stats;
            _generationInFlight = false;
            // The final native token may already have completed when the UI
            // asks to cancel. Clear that late flag before any following turn.
            if (_cancelRequested && response.result != 1) resetKvCache();
            if (response.result == 1) {
              _logger.warn('inference', 'generation_cancelled');
              // A cancelled turn leaves partial KV state; reset it so the next
              // turn starts from a clean cache without unloading the model.
              resetKvCache();
              completer.completeError(InferenceException(
                'Generation was cancelled',
                kind: InferenceErrorKind.cancelled,
              ));
            } else if (response.result < 0) {
              completer.completeError(InferenceException(
                'Native generation failed',
                kind: response.result == -2
                    ? InferenceErrorKind.contextOverflow
                    : InferenceErrorKind.generationError,
              ));
            } else {
              _logger.success('inference', 'generation_complete', kv: {
                'tokens': buffer.length,
              });
              completer.complete();
            }
          } else if (response is _ErrorResponse) {
            sub.cancel();
            _generationInFlight = false;
            completer.completeError(InferenceException(response.message));
          }
        });

        _send(_GenerateRequest(paramsJson));
        await completer.future;
      } catch (_) {
        _generationInFlight = false;
        rethrow;
      }
    });
  }

  /// Writes the native atomic cancellation flag directly; a worker message
  /// cannot be processed while that worker is inside a blocking FFI decode.
  void cancel() {
    if (_generationInFlight && _ctx != null) {
      _cancelRequested = true;
      _bindings.psy_cancel(_ctx!);
    }
  }

  /// Disposes the service, terminates the worker isolate, and unloads the model.
  Future<void> dispose() async {
    if (_disposed) return;
    _disposed = true;
    cancel();
    await _generationLock.synchronized(() async {
      _ctx = null;
      if (_worker != null) {
        final disposed = _responseController.stream
            .firstWhere((response) => response is _DisposedResponse);
        _send(_DisposeRequest());
        await disposed;
        _worker = null;
        _workerSendPort = null;
      }
      _receivePort.close();
      await _responseController.close();
    });
  }
}

/// Minimal non-reentrant lock used to serialize generation requests.
class Lock {
  Future<dynamic>? _active;
  bool get locked => _active != null;

  Future<T> synchronized<T>(Future<T> Function() task) async {
    while (_active != null) {
      await _active;
    }
    // Waiters observe release, not the preceding task's error. In particular,
    // disposal must still run after an active generation was cancelled.
    final released = Completer<void>();
    _active = released.future;
    try {
      return await task();
    } finally {
      _active = null;
      released.complete();
    }
  }
}
