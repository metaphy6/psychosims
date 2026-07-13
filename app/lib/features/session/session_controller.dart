import 'dart:async';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:psychemas/psychemas.dart';
import 'package:psycore/psycore.dart' as core;
import 'package:psyconfig/psyconfig.dart';

import '../../shared/inference_service.dart';
import '../../shared/l10n.dart';
import '../../shared/logger.dart';
import '../../shared/model_profile_resolver.dart';
import '../../shared/response_planner.dart';
import '../../shared/session_persistence.dart';

/// UI-facing state for the session screen.
enum SessionStatus { loading, ready, generating, error }

/// One displayed exchange in the session view.
class DisplayTurn {
  final bool isPlayer;
  final String text;
  final bool isStreaming;

  const DisplayTurn({
    required this.isPlayer,
    required this.text,
    this.isStreaming = false,
  });

  DisplayTurn copyWith({String? text, bool? isStreaming}) => DisplayTurn(
        isPlayer: isPlayer,
        text: text ?? this.text,
        isStreaming: isStreaming ?? this.isStreaming,
      );
}

/// Controller for the Phase 1 end-to-end session loop.
///
/// Loads a bundled case, exposes the available actions, resolves each turn
/// through the deterministic core, assembles a token-budgeted prompt, runs
/// inference off the UI isolate via [InferenceService], and streams the
/// sanitized response back into the view.
class SessionController extends GetxController {
  SessionController({
    required this.config,
    required this.inference,
    required this.logger,
    required this.responsePlanner,
    required this.clock,
    this.persistence,
    this.modelPath,
  });

  final Config config;
  final InferenceService inference;
  final PsyLog logger;
  final ResponsePlanner responsePlanner;
  final core.Clock clock;

  /// Optional durable checkpointing service. When provided, the controller
  /// persists the structured session state at each turn boundary and clears it
  /// when a new case is loaded.
  final SessionPersistenceService? persistence;

  /// Optional resolved local model path. When null or missing, the controller
  /// falls back to the PoC stub path so first-run development/CI still works.
  final String? modelPath;

  final status = SessionStatus.loading.obs;
  final errorMessage = ''.obs;
  final manifest = Rxn<PatientManifest>();
  final displayTurns = <DisplayTurn>[].obs;
  final isActionLocked = false.obs;

  late core.SimState _currentState;
  final List<core.ConversationTurn> _conversationWindow = [];
  final List<StructuredDelta> _deltaLog = [];
  late final core.TurnResolver _resolver;
  final _cancelToken = CancelToken();
  Future<void>? _loadCaseFuture;

  bool get hasManifest => manifest.value != null;

  late final String _correlationId;
  late final PsyLog _sessionLogger;

  @override
  void onInit() {
    super.onInit();
    _correlationId = _generateCorrelationId();
    _sessionLogger = PsyLog(
      minLevel: logger.minLevel,
      jsonMode: logger.jsonMode,
      correlationId: _correlationId,
    );
    _resolver = core.TurnResolver(clock);
    loadCase();
  }

  String _generateCorrelationId() {
    final ts = clock.nowMillis();
    final rand = (clock.monotonicMillis() ^ ts) & 0xFFFFFF;
    return 'psy-${ts.toRadixString(36)}-${rand.toRadixString(36)}';
  }

  @override
  void onClose() {
    _cancelToken.cancel();
    super.onClose();
  }

  /// Loads the bundled manifest configured by [config.content.bundledManifestPath].
  ///
  /// Re-entrant: if a load is already in progress, awaits that load instead of
  /// starting a second one. This prevents races when [onInit] and a test both
  /// call loadCase close together.
  Future<void> loadCase() async {
    if (_loadCaseFuture != null) {
      return _loadCaseFuture!;
    }
    _loadCaseFuture = _doLoadCase();
    try {
      await _loadCaseFuture!;
    } finally {
      _loadCaseFuture = null;
    }
  }

  Future<void> _doLoadCase() async {
    status.value = SessionStatus.loading;
    errorMessage.value = '';
    try {
      final path = config.content.bundledManifestPath;
      final bytes = await rootBundle.load(path);
      final data = bytes.buffer.asUint8List();
      final loader = ManifestLoader(
        limits: ManifestLoaderLimits(
          maxBytes: config.content.maxManifestBytes,
          maxMapDepth: config.content.maxManifestDepth,
        ),
        catalog: const L10n(),
      );
      final loaded = loader.load(data);
      manifest.value = loaded;
      _currentState = core.SimState(
        seed: config.inference.seed,
        axes: Map<String, int>.from(loaded.initialState),
      );
      _conversationWindow.clear();
      _deltaLog.clear();
      displayTurns.clear();
      inference.resetKvCache();
      await persistence?.clear();
      final resolvedModelPath = _resolveModelPath();
      await inference.loadModel(
        resolvedModelPath,
        params: ModelLoadParams(
          nCtx: config.model.nCtx,
          nBatch: config.model.nBatch,
          nThreads: config.inference.threadCount,
          kvCacheType: config.inference.kvCacheType,
          correlationId: _correlationId,
        ),
      );
      await inference.warmUp();

      status.value = SessionStatus.ready;
      _sessionLogger
          .success('session', 'case_loaded', kv: {'case_id': loaded.id});
    } on Exception catch (e, st) {
      status.value = SessionStatus.error;
      errorMessage.value = e.toString();
      _sessionLogger.error('session', 'case_load_failed',
          errorKind: ErrorKind.system, message: '$e\n$st');
    }
  }

  /// Returns the localized case title, or a fallback key if not loaded.
  String caseTitle() {
    final key = manifest.value?.nameKey;
    if (key == null) return const L10n().manifestName('unknown');
    return const L10n().manifestName(key);
  }

  /// Returns the available interaction patterns for the loaded case.
  List<InteractionPattern> availableActions() {
    return manifest.value?.interactionPatterns ?? [];
  }

  /// Submits a player action and runs one turn end-to-end.
  Future<void> submitAction(InteractionPattern action) async {
    if (isActionLocked.value || status.value != SessionStatus.ready) return;
    final loaded = manifest.value;
    if (loaded == null) return;

    isActionLocked.value = true;
    status.value = SessionStatus.generating;
    errorMessage.value = '';

    // Snapshot state so a cancellation or failure can roll back transactionally.
    final previousState = _currentState;
    final previousWindow = List<core.ConversationTurn>.of(_conversationWindow);
    final previousDeltas = List<StructuredDelta>.of(_deltaLog);
    final previousDisplay = List<DisplayTurn>.of(displayTurns);

    try {
      // 1. Deterministic core resolves mechanics.
      final turnOutput = _resolver.resolve(core.TurnInput(
        rulesetVersion: loaded.rulesetVersion,
        manifest: loaded,
        state: _currentState,
        action: action,
      ));

      // 2. Append player action to the conversation window.
      _conversationWindow.add(core.ConversationTurn(
        role: 'user',
        text: action.name,
      ));
      displayTurns.add(DisplayTurn(
        isPlayer: true,
        text: action.name,
      ));

      // 3. Assemble a token-budgeted prompt using the real tokenizer/template
      //    when a model is loaded, falling back to deterministic stubs.
      final assembler = core.PromptAssembler(
        tokenCounter: inference,
        chatTemplate: inference,
      );
      final prompt = assembler.assemble(
        rulesetVersion: loaded.rulesetVersion,
        manifest: loaded,
        state: turnOutput.nextState,
        conversationWindow: _conversationWindow,
        inputBudget: config.promptBudget.maxInputTokens,
        outputReserve: config.promptBudget.maxOutputTokens,
      );

      // 4. Generate and stream the model response off the UI isolate.
      const streamingTurn = DisplayTurn(
        isPlayer: false,
        text: '',
        isStreaming: true,
      );
      displayTurns.add(streamingTurn);
      final streamIndex = displayTurns.length - 1;

      final activeProfile = const ModelProfileResolver().resolve(
        modelPath ?? '/tmp/model.gguf',
        config,
      );

      final buffer = StringBuffer();
      Future<String> generate() async {
        await inference.generate(
          GenerationParams(
            prompt: prompt,
            maxTokens: config.promptBudget.maxOutputTokens,
            temperature: config.inference.greedyDecode
                ? 0.0
                : config.inference.temperature,
            topP: config.inference.greedyDecode ? 1.0 : config.inference.topP,
            topK: config.inference.greedyDecode ? 1 : config.inference.topK,
            repetitionPenalty: config.inference.repetitionPenalty,
            seed: config.inference.seed,
            stopTokens: activeProfile.stopTokens,
            grammar: config.inference.grammarPath,
          ),
          (token, _) {
            buffer.write(token);
            displayTurns[streamIndex] =
                displayTurns[streamIndex].copyWith(text: buffer.toString());
          },
          correlationId: _correlationId,
          nCtx: config.model.nCtx,
        );
        return buffer.toString();
      }

      final planned = await responsePlanner.plan(
        generate: generate,
        fallback: _fallbackDialogue(action),
        requiredClueTokens: turnOutput.requiredClueTokens,
        systemFrame: prompt,
        clueTokens: loaded.clueTokens,
      );

      // 5. Commit the turn if generation succeeded.
      _currentState = turnOutput.nextState;
      _deltaLog.addAll(turnOutput.deltas);
      displayTurns[streamIndex] = DisplayTurn(
        isPlayer: false,
        text: planned.dialogue,
        isStreaming: false,
      );
      _conversationWindow.add(core.ConversationTurn(
        role: 'assistant',
        text: planned.dialogue,
      ));
      _trimConversationWindow(loaded.maxHistoryTurns);

      await persistence?.save(SessionCheckpoint(
        correlationId: _correlationId,
        manifestId: loaded.id,
        state: _currentState,
        conversationWindow: _conversationWindow,
        deltaLog: _deltaLog,
      ));

      _sessionLogger.success('session', 'turn_complete', kv: {
        'turn': _currentState.turn,
        'used_fallback': planned.usedFallback,
      });
    } on Exception catch (e, st) {
      // Roll back to the pre-turn snapshot.
      _currentState = previousState;
      _conversationWindow
        ..clear()
        ..addAll(previousWindow);
      _deltaLog
        ..clear()
        ..addAll(previousDeltas);
      displayTurns
        ..clear()
        ..addAll(previousDisplay);
      status.value = SessionStatus.error;
      errorMessage.value = _mapErrorMessage(e);
      _sessionLogger.error('session', 'turn_failed',
          errorKind: ErrorKind.system, message: '$e\n$st');
    } finally {
      isActionLocked.value = false;
      if (status.value == SessionStatus.generating) {
        status.value = SessionStatus.ready;
      }
    }
  }

  void _trimConversationWindow(int maxTurns) {
    while (_conversationWindow.length > maxTurns) {
      _conversationWindow.removeAt(0);
    }
  }

  String _resolveModelPath() {
    const stubPath = '/tmp/psychosims_poc_model.gguf';
    final requested = modelPath;
    if (requested != null &&
        requested.isNotEmpty &&
        File(requested).existsSync()) {
      return requested;
    }
    if (requested != null && requested.isNotEmpty) {
      _sessionLogger.warn('session', 'resolved_model_missing',
          kv: {'requested': requested, 'fallback': stubPath});
    }
    return stubPath;
  }

  String _fallbackDialogue(InteractionPattern action) {
    return 'The patient responds to ${action.name}.';
  }

  String _mapErrorMessage(Object error) {
    if (error is InferenceException) {
      switch (error.kind) {
        case InferenceErrorKind.missingModel:
        case InferenceErrorKind.loadFailure:
          return const L10n().errorMessage('errors.model_load_failed');
        case InferenceErrorKind.corruptModel:
          return const L10n().errorMessage('errors.model_corrupt');
        case InferenceErrorKind.outOfMemory:
          return const L10n().errorMessage('errors.out_of_memory');
        case InferenceErrorKind.cancelled:
          return const L10n().errorMessage('errors.generation_cancelled');
        case InferenceErrorKind.contextOverflow:
        case InferenceErrorKind.generationError:
        case InferenceErrorKind.unsupportedAbi:
          return const L10n().errorMessage('errors.generation_failed');
      }
    }
    return error.toString();
  }

  /// Cancels an in-flight generation and rolls the turn back.
  void cancelTurn() {
    inference.cancel();
    _cancelToken.cancel();
    _sessionLogger.warn('session', 'turn_cancelled_by_user');
  }
}

/// Simple cancellation token used by the controller.
class CancelToken {
  bool _cancelled = false;
  bool get isCancelled => _cancelled;
  void cancel() => _cancelled = true;
}
