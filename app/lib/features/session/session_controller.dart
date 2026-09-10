import 'dart:async';
import 'dart:io';
import 'dart:math';

import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:psychemas/psychemas.dart';
import 'package:psycore/psycore.dart' as core;
import 'package:psyconfig/psyconfig.dart';

import '../../shared/inference_service.dart';
import '../../shared/online_session_service.dart';
import '../../shared/api_client.dart';
import '../../shared/model_cache.dart';
import '../../shared/career_persistence.dart';
import '../../shared/l10n.dart';
import '../../shared/logger.dart';
import '../../shared/model_profile_resolver.dart';
import '../../shared/response_planner.dart';
import '../../shared/session_persistence.dart';

/// UI-facing state for the session screen.
enum SessionStatus { loading, ready, generating, completed, error }

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
    this.modelCache,
    this.careerPersistence,
    this.online,
    this.onlineContext,
    Loadout? initialLoadout,
    CardLibrary? initialLibrary,
    TherapyControllerSettings? initialControllers,
  })  : _initialLoadout = initialLoadout,
        _initialLibrary = initialLibrary,
        _initialControllers = initialControllers;

  final Config config;
  final InferenceService inference;
  final PsyLog logger;
  final ResponsePlanner responsePlanner;
  final core.Clock clock;

  /// Optional durable checkpointing service. When provided, the controller
  /// persists structured session state at each turn boundary and resumes it
  /// on restart. Starting the next completed session explicitly clears it.
  final SessionPersistenceService? persistence;

  /// Optional explicitly resolved model path for harnesses. App routes use the
  /// shared verified cache; missing models fail with a download instruction.
  final String? modelPath;
  final ModelCache? modelCache;
  final CareerPersistenceService? careerPersistence;
  final OnlineSessionService? online;
  final OnlineSessionContext? onlineContext;

  final Loadout? _initialLoadout;
  final CardLibrary? _initialLibrary;
  final TherapyControllerSettings? _initialControllers;
  late TherapyControllerSettings _controllers;

  final status = SessionStatus.loading.obs;
  final errorMessage = ''.obs;
  final manifest = Rxn<PatientManifest>();
  final displayTurns = <DisplayTurn>[].obs;
  final isActionLocked = false.obs;
  final result = Rxn<CareerSessionRecord>();
  core.SimState get currentState => _currentState;
  final List<InteractionPattern> _actions = [];
  final List<core.TurnOutput> _outputs = [];
  late SessionStartState _startState;

  late core.SimState _currentState;
  final List<core.ConversationTurn> _conversationWindow = [];
  final List<StructuredDelta> _deltaLog = [];
  late final core.TurnResolver _resolver;
  late Loadout _loadout;
  late CardLibrary _library;
  CancelToken _cancelToken = CancelToken();
  Future<void>? _loadCaseFuture;
  bool _closed = false;
  String? _loadedModelPath;

  bool get hasManifest => manifest.value != null;

  late String _correlationId;
  late PsyLog _sessionLogger;

  @override
  void onInit() {
    super.onInit();
    _correlationId = _generateCorrelationId();
    _sessionLogger = PsyLog(
      minLevel: logger.minLevel,
      jsonMode: logger.jsonMode,
      correlationId: _correlationId,
    );
    _resolver = core.TurnResolver(
      clock,
      balance: core.CardBalance.fromConfig(config.balance),
    );
    loadCase();
  }

  String _generateCorrelationId() {
    final random = Random.secure();
    final suffix = List.generate(
            16, (_) => random.nextInt(256).toRadixString(16).padLeft(2, '0'))
        .join();
    return 'psy-$suffix';
  }

  @override
  void onClose() {
    _closed = true;
    _cancelToken.cancel();
    inference.cancel();
    super.onClose();
  }

  /// Loads the bundled manifest configured by [config.content.bundledManifestPath].
  ///
  /// Re-entrant: if a load is already in progress, awaits that load instead of
  /// starting a second one. This prevents races when [onInit] and a test both
  /// call loadCase close together.
  Future<void> loadCase() async {
    if (_closed) return;
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
      if (_closed) return;
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
      final savedCareer =
          onlineContext == null ? await careerPersistence?.load() : null;
      if (_closed) return;
      final history = loaded.memoryClass == MemoryClass.persistent
          ? savedCareer?.ownedCases[loaded.id] ?? CaseHistoryEnvelope.empty
          : CaseHistoryEnvelope.empty;
      _currentState = const core.MultiSessionResolver().startingState(
        rootSeed: config.inference.seed,
        initialState: loaded.initialState,
        envelope: history,
      );
      final resolvedCardIds = loaded.resolvedCards.map((c) => c.id).toList();
      _loadout = _initialLoadout ??
          Loadout(
            cardIds:
                resolvedCardIds.take(config.balance.activeCardSlots).toList(),
            slotCap: config.balance.activeCardSlots,
          );
      _library =
          _initialLibrary ?? CardLibrary(ownedCardIds: resolvedCardIds.toSet());
      _controllers = _initialControllers ?? const TherapyControllerSettings();
      _conversationWindow.clear();
      _deltaLog.clear();
      _actions.clear();
      _outputs.clear();
      displayTurns.clear();
      result.value = null;
      isActionLocked.value = false;
      _startState = SessionStartState(
        loadout: _loadout,
        library: _library,
        controllers: _controllers,
        initialAxes: {
          'trust': _currentState.trustScore,
          'agitation': _currentState.agitationLevel,
          'resistance': _currentState.resistance,
          'trauma': _currentState.trauma,
          'session_progress': _currentState.sessionProgress,
        },
        rootSeed: _currentState.seed,
      );
      final onlineSession = onlineContext;
      if (onlineSession != null) {
        final permit = onlineSession.authorization;
        if (online == null ||
            permit.startState['case_id'] != loaded.id ||
            permit.rulesetVersion != loaded.rulesetVersion ||
            permit.startState['manifest_checksum'] != loaded.contentChecksum) {
          throw const ApiException(statusCode: 409, kind: 'content_mismatch');
        }
        _startState = SessionStartState.fromJson(permit.startState);
        _loadout = _startState.loadout;
        _library = _startState.library;
        _controllers = _startState.controllers;
        _currentState = core.SimState.fromInitialState(
            _startState.rootSeed, _startState.initialAxes);
        _correlationId = permit.id;
      }
      final checkpoint = await persistence?.load();
      if (_closed) return;
      if (checkpoint != null &&
          checkpoint.version == 2 &&
          (onlineContext == null ||
              checkpoint.correlationId == onlineContext!.authorization.id) &&
          checkpoint.manifestId == loaded.id &&
          checkpoint.manifestChecksum == loaded.contentChecksum &&
          checkpoint.rulesetVersion == loaded.rulesetVersion &&
          checkpoint.startState != null &&
          _isPlayableLoadout(loaded, checkpoint.startState!.loadout,
              checkpoint.startState!.library) &&
          checkpoint.actions.length == checkpoint.outputs.length &&
          checkpoint.state.turn == checkpoint.actions.length) {
        _correlationId = checkpoint.correlationId;
        _startState = checkpoint.startState!;
        _loadout = _startState.loadout;
        _library = _startState.library;
        _controllers = _startState.controllers;
        _currentState = checkpoint.state;
        _actions.addAll(checkpoint.actions);
        _outputs.addAll(checkpoint.outputs);
        _deltaLog.addAll(checkpoint.deltaLog);
      }
      if (!_isPlayableLoadout(loaded, _loadout, _library)) {
        status.value = SessionStatus.error;
        errorMessage.value = L10n.loadoutInvalid;
        return;
      }
      _sessionLogger = PsyLog(
          minLevel: logger.minLevel,
          jsonMode: logger.jsonMode,
          correlationId: _correlationId);
      if (_outputs.isNotEmpty && _outputs.last.isTerminal) {
        await _completeSession(loaded);
        return;
      }
      inference.resetKvCache();
      final resolvedModelPath = modelCache == null
          ? _resolveModelPath()
          : await modelCache!.requireModelPath();
      if (_closed) return;
      _loadedModelPath = resolvedModelPath;
      await inference.loadModel(
        resolvedModelPath,
        params: ModelLoadParams(
          nCtx: config.model.nCtx,
          nBatch: config.model.nBatch,
          nThreads: config.inference.threadCount,
          useMmap: config.model.useMmap,
          kvCacheType: config.inference.kvCacheType,
          correlationId: _correlationId,
        ),
      );
      if (_closed) return;
      await inference.warmUp();
      if (_closed) return;
      await _saveCheckpoint(loaded);
      if (_closed) return;

      status.value = SessionStatus.ready;
      _sessionLogger
          .success('session', 'case_loaded', kv: {'case_id': loaded.id});
    } catch (e, st) {
      status.value = SessionStatus.error;
      errorMessage.value = _mapErrorMessage(e);
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
    return (manifest.value?.interactionPatterns ?? <InteractionPattern>[])
        .where((action) {
      final cardId = cardFromInteractionPattern(action).id;
      return _loadout.contains(cardId) && _library.owns(cardId);
    }).toList();
  }

  bool _isPlayableLoadout(
      PatientManifest loaded, Loadout loadout, CardLibrary library) {
    final cards = loadout.cardIds;
    final actionable = loaded.interactionPatterns
        .map((action) => cardFromInteractionPattern(action).id)
        .toSet();
    return cards.isNotEmpty &&
        cards.length <= config.balance.activeCardSlots &&
        cards.toSet().length == cards.length &&
        loadout.isValidForLibrary(library.ownedCardIds) &&
        cards.every(actionable.contains);
  }

  /// Submits a player action and runs one turn end-to-end.
  Future<void> submitAction(InteractionPattern action) async {
    if (isActionLocked.value || status.value != SessionStatus.ready) return;
    final loaded = manifest.value;
    if (loaded == null || !availableActions().contains(action)) return;
    if (onlineContext != null &&
        !onlineContext!.authorization.expiresAt
            .isAfter(DateTime.now().toUtc())) {
      status.value = SessionStatus.error;
      errorMessage.value = L10n.onlineExpired;
      return;
    }

    _cancelToken = CancelToken();
    isActionLocked.value = true;
    status.value = SessionStatus.generating;
    errorMessage.value = '';

    // Snapshot state so a cancellation or failure can roll back transactionally.
    final previousState = _currentState;
    final previousWindow = List<core.ConversationTurn>.of(_conversationWindow);
    final previousDeltas = List<StructuredDelta>.of(_deltaLog);
    final previousDisplay = List<DisplayTurn>.of(displayTurns);
    final previousActionCount = _actions.length;
    var durable = false;

    try {
      // 1. Deterministic core resolves mechanics.
      final turnOutput = _resolver.resolve(core.TurnInput(
        rulesetVersion: loaded.rulesetVersion,
        manifest: loaded,
        state: _currentState,
        action: action,
        loadout: _loadout,
        library: _library,
        controllers: _controllers,
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
        roleplayFrame: const core.PatientRoleplayFrame(),
      );
      String assemble({core.PromptCorrection? correction, int attempt = 1}) =>
          assembler.assemble(
            rulesetVersion: loaded.rulesetVersion,
            manifest: loaded,
            state: turnOutput.nextState,
            conversationWindow: _conversationWindow,
            correction: correction,
            correctionAttempt: attempt,
            inputBudget: config.promptBudget.maxInputTokens,
            outputReserve: config.promptBudget.maxOutputTokens,
          );

      final prompt = assemble();

      // 4. Generate and stream the model response off the UI isolate.
      const streamingTurn = DisplayTurn(
        isPlayer: false,
        text: '',
        isStreaming: true,
      );
      displayTurns.add(streamingTurn);
      final streamIndex = displayTurns.length - 1;

      final activeProfile = const ModelProfileResolver().resolve(
        _loadedModelPath!,
        config,
      );

      Future<String> generate(String requestPrompt) async {
        final buffer = StringBuffer();
        await inference.generate(
          GenerationParams(
            prompt: requestPrompt,
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
          },
          correlationId: _correlationId,
          nCtx: config.model.nCtx,
        );
        if (_cancelToken.isCancelled) {
          throw InferenceException('Generation cancelled',
              kind: InferenceErrorKind.cancelled);
        }
        return buffer.toString();
      }

      final planned = await responsePlanner.plan(
        generate: () => generate(prompt),
        regenerate: (reason, attempt) =>
            generate(assemble(correction: reason, attempt: attempt)),
        fallback: _fallbackDialogue(action),
        requiredClueTokens: turnOutput.requiredClueTokens,
        systemFrame: prompt,
        clueTokens: loaded.clueTokens,
      );

      // 5. Commit the turn if generation succeeded.
      _currentState = turnOutput.nextState;
      _actions.add(action);
      _outputs.add(turnOutput);
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

      await _saveCheckpoint(loaded);
      if (_closed) return;
      durable = true;
      if (turnOutput.isTerminal) await _completeSession(loaded);

      _sessionLogger.success('session', 'turn_complete', kv: {
        'turn': _currentState.turn,
        'used_fallback': planned.usedFallback,
      });
    } catch (e, st) {
      // Once the checkpoint is committed, recovery must continue from it.
      if (!durable) {
        _currentState = previousState;
        _actions.removeRange(previousActionCount, _actions.length);
        _outputs.removeRange(previousActionCount, _outputs.length);
        _conversationWindow
          ..clear()
          ..addAll(previousWindow);
        _deltaLog
          ..clear()
          ..addAll(previousDeltas);
        displayTurns
          ..clear()
          ..addAll(previousDisplay);
      }
      final cancelled =
          e is InferenceException && e.kind == InferenceErrorKind.cancelled;
      status.value = cancelled ? SessionStatus.ready : SessionStatus.error;
      errorMessage.value = _mapErrorMessage(e);
      _sessionLogger.error('session', 'turn_failed',
          errorKind: ErrorKind.system, message: '$e\n$st');
    } finally {
      isActionLocked.value = status.value == SessionStatus.completed;
      if (status.value == SessionStatus.generating) {
        status.value = SessionStatus.ready;
      }
    }
  }

  Future<void> _saveCheckpoint(PatientManifest loaded) async {
    if (_closed) return;
    await persistence?.save(
        SessionCheckpoint(
          correlationId: _correlationId,
          manifestId: loaded.id,
          manifestChecksum: loaded.contentChecksum,
          rulesetVersion: loaded.rulesetVersion,
          state: _currentState,
          conversationWindow: const [],
          deltaLog: List.of(_deltaLog),
          startState: _startState,
          actions: List.of(_actions),
          outputs: List.of(_outputs),
        ),
        canCommit: () => !_closed);
  }

  Future<void> _completeSession(PatientManifest loaded) async {
    final context = onlineContext;
    if (context != null) {
      final receipt = SessionReceipt(
        id: context.authorization.id,
        rulesetVersion: context.authorization.rulesetVersion,
        patientId: context.authorization.patientId,
        idempotencyKey: 'rcp_${context.authorization.id}',
        correlationId: _correlationId,
        turnCount: _actions.length,
        startState: context.authorization.startState,
        actions: List.of(_actions),
        deltas: _outputs.expand((output) => output.deltas).toList(),
      );
      await online!.enqueue(context, receipt);
      result.value = CareerSessionRecord(
          sessionId: context.authorization.id,
          manifestId: loaded.id,
          outcome: _outputs.last.outcome,
          receipt: receipt,
          rewards: const []);
    } else if (careerPersistence != null) {
      result.value = await careerPersistence!.completeSession(
        sessionId: _correlationId,
        manifest: loaded,
        startState: _startState,
        actions: _actions,
        outputs: _outputs,
        timestampSeconds: clock.nowMillis() ~/ 1000,
        config: config,
      );
    }
    status.value = SessionStatus.completed;
    isActionLocked.value = true;
  }

  /// Starts another session only after a terminal result has been saved.
  Future<void> startNextSession() async {
    if (status.value != SessionStatus.completed) return;
    status.value = SessionStatus.loading;
    try {
      if (onlineContext != null) {
        await online!.finish(onlineContext!);
        if (!_closed) Get.back<void>();
        return;
      }
      await persistence?.clear(canCommit: () => !_closed);
      if (_closed) return;
      _correlationId = _generateCorrelationId();
      await loadCase();
    } catch (error) {
      status.value = SessionStatus.error;
      errorMessage.value = _mapErrorMessage(error);
    }
  }

  void _trimConversationWindow(int maxTurns) {
    while (_conversationWindow.length > maxTurns) {
      _conversationWindow.removeAt(0);
    }
  }

  String _resolveModelPath() {
    final requested = modelPath;
    if (requested != null &&
        requested.isNotEmpty &&
        File(requested).existsSync()) {
      return requested;
    }
    throw InferenceException('Download the selected model first.',
        kind: InferenceErrorKind.missingModel);
  }

  String _fallbackDialogue(InteractionPattern action) {
    return 'I need a moment to gather my thoughts.';
  }

  String _mapErrorMessage(Object error) {
    if (error is ApiException) return L10n.onlineError(error.kind);
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
