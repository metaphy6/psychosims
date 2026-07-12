import 'dart:convert';
import 'dart:ffi' as ffi;
import 'dart:ffi' show NativeCallable;
import 'dart:io';

import 'package:ffi/ffi.dart';
import 'package:psycore/psycore.dart' as core;

import 'generated/psychosims_native_bindings.dart';
import 'logger.dart';

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

  const GenerationParams({
    required this.prompt,
    this.maxTokens = 128,
    this.temperature = 0.7,
    this.topP = 0.9,
    this.topK = 40,
    this.repetitionPenalty = 1.0,
    this.seed = 42,
    this.stopTokens = const [],
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
      };
}

/// Narrow, typed seam over the native inference backend.
///
/// Implements [core.TokenCounter] and [core.ChatTemplate] so the prompt
/// assembler can consume the active model's real tokenizer and chat template
/// once a model is loaded. No other module touches the FFI directly.
class InferenceService implements core.TokenCounter, core.ChatTemplate {
  InferenceService._(this._bindings, this._logger);

  /// Loads the native library from [libraryPath] or a platform-default name.
  factory InferenceService.load({
    String? libraryPath,
    required PsyLog logger,
  }) {
    final lib = _openLibrary(libraryPath);
    logger.info('inference', 'native_library_opened', kv: {
      if (libraryPath != null) 'path': libraryPath,
      'platform': Platform.operatingSystem,
    });
    return InferenceService._(PsychosimsNativeBindings(lib), logger);
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
    throw UnsupportedError(
      'Native inference not supported on ${Platform.operatingSystem}',
    );
  }

  final PsychosimsNativeBindings _bindings;
  final PsyLog _logger;
  ffi.Pointer<PsyContext>? _ctx;

  bool get isLoaded => _ctx != null;

  /// Native library version string (e.g. "psychosims-native-0.1.0").
  String get version => _bindings.psy_version().cast<Utf8>().toDartString();

  /// Loads a model from [modelPath] with generation parameters in [paramsJson].
  void loadModel(String modelPath, {String paramsJson = '{}'}) {
    if (_ctx != null) unloadModel();
    final pathPtr = modelPath.toNativeUtf8();
    final paramsPtr = paramsJson.toNativeUtf8();
    try {
      _ctx = _bindings.psy_context_load(pathPtr.cast(), paramsPtr.cast());
      if (_ctx == null || _ctx!.address == 0) {
        throw InferenceException('Failed to load model at $modelPath');
      }
      _logger.success('inference', 'model_loaded', kv: {'path': modelPath});
    } finally {
      calloc.free(pathPtr);
      calloc.free(paramsPtr);
    }
  }

  /// Unloads the model and frees native resources.
  void unloadModel() {
    if (_ctx == null) return;
    _bindings.psy_context_destroy(_ctx!);
    _ctx = null;
    _logger.info('inference', 'model_unloaded');
  }

  /// Resets the KV cache without unloading the model.
  void resetKvCache() {
    if (_ctx == null) return;
    _bindings.psy_reset_kv(_ctx!);
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

  /// Generates tokens from [params], streaming each complete token to [onToken].
  ///
  /// [correlationId] is forwarded to the native layer so every log line for
  /// this turn shares the same session identifier.
  ///
  /// Returns once generation completes, is cancelled, or errors.
  Future<void> generate(
    GenerationParams params,
    void Function(String token, bool isCompleteCodepoint) onToken, {
    String? correlationId,
  }) async {
    if (_ctx == null) {
      throw InferenceException('Cannot generate: no model loaded');
    }
    final jsonParams = params.toJson();
    if (correlationId != null && correlationId.isNotEmpty) {
      jsonParams['correlation_id'] = correlationId;
    }
    final paramsPtr = jsonEncode(jsonParams).toNativeUtf8();
    late final NativeCallable<PsyTokenCallbackFunction> callback;
    final buffer = StringBuffer();

    void onNativeToken(
      ffi.Pointer<ffi.Char> tokenText,
      int tokenId,
      int isCodepointComplete,
      ffi.Pointer<ffi.Void> _,
    ) {
      final text = tokenText.cast<Utf8>().toDartString();
      buffer.write(text);
      onToken(text, isCodepointComplete != 0);
    }

    // The PoC stub calls back synchronously on the generation thread, so we
    // use isolateLocal. When the real llama.cpp backend moves generation to a
    // worker isolate, switch this to `.listener`.
    callback = NativeCallable<PsyTokenCallbackFunction>.isolateLocal(
      onNativeToken,
    );

    try {
      final result = _bindings.psy_generate(
        _ctx!,
        paramsPtr.cast(),
        callback.nativeFunction,
        ffi.nullptr,
      );
      if (result == 1) {
        _logger.warn('inference', 'generation_cancelled');
      } else if (result < 0) {
        throw InferenceException('Native generation failed');
      }
      _logger.success('inference', 'generation_complete', kv: {
        'tokens': buffer.length,
      });
    } finally {
      calloc.free(paramsPtr);
      callback.close();
    }
  }

  /// Cancels an in-flight generation. Safe to call from any isolate.
  void cancel() {
    if (_ctx == null) return;
    _bindings.psy_cancel(_ctx!);
  }

  /// Disposes the service and unloads any loaded model.
  void dispose() => unloadModel();
}

class InferenceException implements Exception {
  InferenceException(this.message);
  final String message;

  @override
  String toString() => 'InferenceException: $message';
}
