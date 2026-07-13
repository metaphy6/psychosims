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
  final String? kvCacheType;
  final String? correlationId;

  const ModelLoadParams({
    this.nCtx = 2048,
    this.nBatch = 512,
    this.nThreads = 4,
    this.kvCacheType,
    this.correlationId,
  });

  Map<String, Object?> toJson() => {
        'n_ctx': nCtx,
        'n_batch': nBatch,
        'n_threads': nThreads,
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

class _CancelRequest implements _WorkerRequest {}

class _UnloadRequest implements _WorkerRequest {}

class _ResetKvRequest implements _WorkerRequest {}

class _DisposeRequest implements _WorkerRequest {}

sealed class _WorkerResponse {}

class _PortResponse implements _WorkerResponse {
  _PortResponse(this.sendPort);
  final SendPort sendPort;
}

class _LoadedResponse implements _WorkerResponse {
  _LoadedResponse({required this.success, this.error});
  final bool success;
  final String? error;
}

class _TokenResponse implements _WorkerResponse {
  _TokenResponse(this.text, this.isCompleteCodepoint);
  final String text;
  final bool isCompleteCodepoint;
}

class _GenerateDoneResponse implements _WorkerResponse {
  _GenerateDoneResponse(this.result);
  final int result;
}

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

  void cancel() {
    if (_ctx != null) _bindings.psy_cancel(_ctx!);
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
      receivePort.close();
      return;
    }

    if (request is _LoadRequest) {
      try {
        service ??= _WorkerService(libraryPath);
        service!.load(request.modelPath, request.paramsJson);
        mainSendPort.send(_LoadedResponse(success: true));
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
        mainSendPort.send(_GenerateDoneResponse(result));
      } on Exception catch (e) {
        mainSendPort.send(_ErrorResponse(e.toString()));
      } finally {
        utf8Accumulator = null;
      }
    } else if (request is _CancelRequest) {
      s.cancel();
    }
  });
}

/// Narrow, typed seam over the native inference backend.
///
/// Implements [core.TokenCounter] and [core.ChatTemplate] so the prompt
/// assembler can consume the active model's real tokenizer and chat template
/// once a model is loaded. No other module touches the FFI directly.
///
/// Tokenization and chat-template rendering run synchronously on the owning
/// isolate so the pure prompt assembler stays synchronous. Generation runs on
/// a dedicated worker isolate so the UI isolate is never blocked by FFI calls.
class InferenceService implements core.TokenCounter, core.ChatTemplate {
  InferenceService._(
    this._logger,
    this._libraryPath, {
    bool isWorker = false,
  }) : _isWorker = isWorker;

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
  final bool _isWorker;
  ffi.Pointer<PsyContext>? _ctx;

  Isolate? _worker;
  SendPort? _workerSendPort;
  Future<void>? _workerInitFuture;
  final _receivePort = ReceivePort();
  final _responseController = StreamController<_WorkerResponse>.broadcast();

  final _generationLock = Lock();
  bool _generationInFlight = false;
  bool _disposed = false;

  bool get isLoaded => _ctx != null;

  /// Native library version string (e.g. "psychosims-native-0.1.0").
  String get version => _bindings.psy_version().cast<Utf8>().toDartString();

  Future<void> _ensureWorker() {
    if (_isWorker) return Future.value();
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
  /// The model is loaded both in the owning isolate (for tokenization/template)
  /// and in the dedicated worker isolate (for generation). When the real
  /// llama.cpp backend uses mmap, the weight memory is shared by the OS; the
  /// KV cache is allocated per context.
  Future<void> loadModel(
    String modelPath, {
    ModelLoadParams params = const ModelLoadParams(),
  }) async {
    if (_disposed) throw InferenceException('Service is disposed');
    if (_ctx != null) unloadModel();
    final paramsJson = jsonEncode(params.toJson());
    final pathPtr = modelPath.toNativeUtf8();
    final paramsPtr = paramsJson.toNativeUtf8();
    try {
      _ctx = _bindings.psy_context_load(pathPtr.cast(), paramsPtr.cast());
      if (_ctx == null || _ctx!.address == 0) {
        throw InferenceException(
          'Failed to load model at $modelPath',
          kind: InferenceErrorKind.loadFailure,
        );
      }
      _logger.success('inference', 'model_loaded', kv: {
        'path': modelPath,
        'n_ctx': params.nCtx,
        'n_batch': params.nBatch,
      });
    } finally {
      calloc.free(pathPtr);
      calloc.free(paramsPtr);
    }
    // Eagerly spawn the worker and load the same model there so the first
    // generate() call does not pay the load latency.
    await _ensureWorker();
    final completer = Completer<void>();
    late final StreamSubscription<_WorkerResponse> sub;
    sub = _responseController.stream.listen((response) {
      if (response is _LoadedResponse) {
        if (response.success) {
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
    _send(_LoadRequest(modelPath, paramsJson));
    return completer.future;
  }

  /// Runs a short warm-up generation so the first real turn is not a latency
  /// outlier. Safe to call after [loadModel]; no-op if no model is loaded.
  Future<void> warmUp() async {
    if (_ctx == null || _disposed) return;
    await generate(
      const GenerationParams(prompt: '', maxTokens: 1),
      (_, __) {},
    );
    _logger.info('inference', 'warmup_complete');
  }

  /// Unloads the model and frees native resources.
  void unloadModel() {
    if (_ctx == null && _worker == null) return;
    if (_ctx != null) {
      _bindings.psy_context_destroy(_ctx!);
      _ctx = null;
    }
    if (_worker != null) {
      _send(_UnloadRequest());
    }
    _logger.info('inference', 'model_unloaded');
  }

  /// Resets the KV cache without unloading the model.
  void resetKvCache() {
    if (_ctx != null) _bindings.psy_reset_kv(_ctx!);
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
    final outPtr = calloc<ffi.Char>(4096);
    try {
      final written = _bindings.psy_apply_chat_template(
        _ctx!,
        jsonPtr.cast(),
        outPtr,
        4096,
      );
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
  Future<void> generate(
    GenerationParams params,
    void Function(String token, bool isCompleteCodepoint) onToken, {
    String? correlationId,
    int nCtx = 2048,
  }) async {
    if (_generationInFlight) {
      throw InferenceException(
        'A generation is already in flight',
        kind: InferenceErrorKind.generationError,
      );
    }

    await _generationLock.synchronized(() async {
      _generationInFlight = true;
      try {
        if (_ctx == null) {
          throw InferenceException(
            'Cannot generate: no model loaded',
            kind: InferenceErrorKind.missingModel,
          );
        }

        guardContextWindow(
          prompt: params.prompt,
          maxOutputTokens: params.maxTokens,
          nCtx: nCtx,
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
            _generationInFlight = false;
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
                kind: InferenceErrorKind.generationError,
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

  /// Cancels an in-flight generation. Safe to call from any isolate.
  void cancel() {
    if (_worker != null) _send(_CancelRequest());
  }

  /// Disposes the service, terminates the worker isolate, and unloads the model.
  Future<void> dispose() async {
    if (_disposed) return;
    _disposed = true;
    unloadModel();
    if (_worker != null) {
      _send(_DisposeRequest());
      _worker!.kill(priority: Isolate.immediate);
      _worker = null;
    }
    _receivePort.close();
    await _responseController.close();
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
    final future = task();
    _active = future;
    try {
      return await future;
    } finally {
      _active = null;
    }
  }
}
