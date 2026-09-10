import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:psychemas/psychemas.dart';
import 'package:psyconfig/psyconfig.dart';
import 'package:psycore/psycore.dart' as core;
import 'package:psychosims/features/session/session_controller.dart';
import 'package:psychosims/features/session/session_bindings.dart';
import 'package:psychosims/shared/inference_service.dart';
import 'package:psychosims/shared/career_persistence.dart';
import 'package:psychosims/shared/logger.dart';
import 'package:psychosims/shared/model_cache.dart';
import 'package:psychosims/shared/response_planner.dart';
import 'package:psychosims/shared/session_persistence.dart';

import 'fake_inference_service.dart';
import 'test_manifest_data.dart';

class _ConfiguredProvider implements ConfigProvider {
  _ConfiguredProvider(this.config);
  @override
  final Config config;
}

class _SelectedCache extends ModelCache {
  _SelectedCache(this.path) : super(config: loadConfig(environment: 'test'));
  final String path;
  @override
  Future<String> requireModelPath() async => path;
}

class _FailingCareer extends CareerPersistenceService {
  _FailingCareer({required super.directory});
  @override
  Future<void> save(CareerSave save) async =>
      throw const FileSystemException('injected career failure');
}

class _FailingCheckpoint extends SessionPersistenceService {
  _FailingCheckpoint({required super.directory});
  bool fail = false;
  bool failClear = false;
  @override
  Future<void> clear({bool Function()? canCommit}) async {
    if (failClear) throw const FileSystemException('injected clear failure');
    await super.clear(canCommit: canCommit);
  }

  @override
  Future<void> save(SessionCheckpoint checkpoint,
      {bool Function()? canCommit}) async {
    if (fail) throw const FileSystemException('injected checkpoint failure');
    await super.save(checkpoint, canCommit: canCommit);
  }
}

class _DelayedCheckpoint extends SessionPersistenceService {
  _DelayedCheckpoint({required super.directory});
  final started = Completer<void>();
  final release = Completer<void>();

  @override
  Future<void> save(SessionCheckpoint checkpoint,
      {bool Function()? canCommit}) async {
    started.complete();
    await release.future;
    await super.save(checkpoint, canCommit: canCommit);
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory directory;
  late SessionPersistenceService persistence;
  late CareerPersistenceService career;
  late FakeInferenceService inference;
  late String modelPath;
  var terminalStart = false;

  setUp(() async {
    Get.reset();
    directory =
        await Directory('/tmp/agent-runs').createTemp('psychosims-controller-');
    persistence = SessionPersistenceService(directory: directory);
    career = CareerPersistenceService(directory: directory);
    inference = FakeInferenceService();
    modelPath = '${directory.path}/verified-model.gguf';
    await File(modelPath).writeAsBytes([1]);
    terminalStart = false;
    final manifestPath =
        loadConfig(environment: 'test').content.bundledManifestPath;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMessageHandler('flutter/assets', (message) async {
      final key = utf8.decode(message!.buffer.asUint8List());
      if (key != manifestPath) return null;
      final bytes = Uint8List.fromList(utf8.encode(testManifestJson(
        initialState: terminalStart
            ? {
                'agitation': 45,
                'resistance': 20,
                'trust': 30,
                'session_progress': 99
              }
            : null,
      )));
      return ByteData.view(bytes.buffer);
    });
  });
  tearDown(() async {
    Get.reset();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMessageHandler('flutter/assets', null);
    await directory.delete(recursive: true);
  });

  Future<SessionController> start(
      {Loadout? loadout,
      CardLibrary? library,
      ModelCache? cache,
      CareerPersistenceService? careerOverride,
      void Function(SessionController)? afterInit}) async {
    final controller = SessionController(
      config: loadConfig(environment: 'test'),
      inference: inference,
      logger: PsyLog(minLevel: LogLevel.warn),
      responsePlanner: const ResponsePlanner(maxRetries: 1),
      clock: const core.InjectedClock.replay(1000),
      modelPath: cache == null ? modelPath : null,
      modelCache: cache,
      persistence: persistence,
      careerPersistence: careerOverride ?? career,
      initialLoadout: loadout,
      initialLibrary: library,
    );
    controller.onInit();
    afterInit?.call(controller);
    await controller.loadCase();
    return controller;
  }

  test('loads case and exposes available actions', () async {
    final controller = await start();
    expect(controller.hasManifest, isTrue);
    expect(controller.status.value, SessionStatus.ready);
    expect(controller.availableActions(), isNotEmpty);
  });

  for (final retries in [0, 1, 2]) {
    test('production session binding honors configured retries=$retries',
        () async {
      final base = loadConfig(environment: 'test');
      final config = base.copyWith(
          promptBudget:
              base.promptBudget.copyWith(maxRegenerationRetries: retries));
      validateConfig(config);
      Get.put<ConfigProvider>(_ConfiguredProvider(config));
      Get.put<PsyLog>(PsyLog(minLevel: LogLevel.warn));
      Get.put<InferenceService>(inference);
      Get.put<ModelCache>(_SelectedCache(modelPath));
      Get.put<CareerPersistenceService>(career);
      Get.put<SessionPersistenceService>(persistence);
      inference.responses.addAll(List.filled(3, 'I feel restless.'));
      SessionBindings().dependencies();
      final controller = Get.find<SessionController>();
      await controller.loadCase();
      await controller.submitAction(controller.availableActions().first);
      expect(inference.generationCalls, retries + 1);
      expect(inference.prompts.toSet(), hasLength(retries + 1));
      expect(controller.displayTurns.last.text,
          'I need a moment to gather my thoughts.');
      expect((await persistence.load())!.actions, hasLength(1));
    });
  }

  test(
      'controller retries with a corrected prompt and commits only model dialogue',
      () async {
    inference.responses
        .addAll(['I feel restless.', 'I feel heard. [ferve-axine]']);
    final controller = await start();
    await controller.submitAction(controller.availableActions().first);
    expect(inference.prompts, hasLength(2));
    expect(inference.prompts[0], isNot(inference.prompts[1]));
    expect(inference.prompts[1], contains('Correction 1:'));
    expect(inference.prompts[1], contains('End with exactly: [ferve-axine]'));
    expect(controller.displayTurns.last.text, 'I feel heard.');
    expect((await persistence.load())!.actions, hasLength(1));
  });

  test(
      'exhausted model retries display first-person fallback without action IDs',
      () async {
    inference.responses.addAll(['No marker.', 'Still no marker.']);
    final controller = await start();
    await controller.submitAction(controller.availableActions().first);
    expect(controller.displayTurns.last.text,
        'I need a moment to gather my thoughts.');
    expect(inference.generationCalls, 2);
  });

  test('submitAction streams a response and commits the turn', () async {
    final controller = await start();
    await controller.submitAction(controller.availableActions().first);
    expect(controller.displayTurns.length, 2);
    expect(controller.displayTurns.last.text, 'I feel restless.');
    expect(controller.status.value, SessionStatus.ready);
  });

  test('generation uses the profile of the model selected by the shared cache',
      () async {
    final cachePath = '${directory.path}/phi-3.5-mini-instruct-q4_k_m.gguf';
    final controller = await start(cache: _SelectedCache(cachePath));
    await controller.submitAction(controller.availableActions().first);
    expect(inference.loadedPath, cachePath);
    expect(inference.generations.single.stopTokens, contains('<|end|>'));
  });

  test('only equipped owned actions can be listed or submitted', () async {
    final action = testManifest().interactionPatterns.first;
    final controller = await start(
        loadout: Loadout(
            cardIds: [cardFromInteractionPattern(action).id], slotCap: 6));
    expect(controller.availableActions(), [action]);
    await controller.submitAction(InteractionPattern.reframe);
    expect(controller.displayTurns, isEmpty);
    expect(inference.generationCalls, 0);
  });

  test('new sessions reject empty, unowned, duplicate or unknown loadouts',
      () async {
    final cardId =
        cardFromInteractionPattern(testManifest().interactionPatterns.first).id;
    for (final (loadout, library) in [
      (const Loadout.empty(slotCap: 6), CardLibrary(ownedCardIds: {cardId})),
      (
        const Loadout(cardIds: ['unknown'], slotCap: 6),
        const CardLibrary(ownedCardIds: {'unknown'})
      ),
      (
        Loadout(cardIds: [cardId, cardId], slotCap: 6),
        CardLibrary(ownedCardIds: {cardId})
      ),
      (
        Loadout(cardIds: [cardId], slotCap: 6),
        const CardLibrary(ownedCardIds: {})
      ),
    ]) {
      final controller = await start(loadout: loadout, library: library);
      expect(controller.status.value, SessionStatus.error);
      expect(inference.loadedPath, isNull);
      expect(await persistence.load(), isNull);
      controller.onClose();
    }
  });

  test('restart replaces an invalid empty checkpoint with the chosen loadout',
      () async {
    final original = await start();
    final checkpoint = (await persistence.load())!;
    original.onClose();
    final json = checkpoint.toJson();
    (json['start_state']! as Map<String, Object?>)['loadout'] =
        const Loadout.empty(slotCap: 6).toJson();
    await persistence.save(SessionCheckpoint.fromJson(json));
    final action = testManifest().interactionPatterns.last;
    final recovered = await start(
        loadout: Loadout(
            cardIds: [cardFromInteractionPattern(action).id], slotCap: 6));
    expect(recovered.status.value, SessionStatus.ready);
    expect(recovered.availableActions(), [action]);
    expect((await persistence.load())!.correlationId,
        isNot(checkpoint.correlationId));
    await recovered.submitAction(action);
    recovered.onClose();
    final resumed = await start();
    expect(resumed.currentState.turn, 1);
    expect(resumed.availableActions(), [action]);
  });

  test('retry buffers are isolated and raw invalid text never reaches the UI',
      () async {
    inference.responses.addAll(
        ['I cannot continue. [ferve-axine]', 'I feel restless. [ferve-axine]']);
    final controller = await start();
    inference.duringGeneration = () {
      expect(controller.displayTurns.last.text, isEmpty);
    };
    await controller.submitAction(controller.availableActions().first);
    expect(inference.generationCalls, 2);
    expect(controller.displayTurns.last.text, 'I feel restless.');
  });

  test('restart resumes the same turn and loadout without storing dialogue',
      () async {
    final controller = await start();
    await controller.submitAction(controller.availableActions().first);
    final checkpoint = (await persistence.load())!;
    controller.onClose();
    final resumed = await start(loadout: const Loadout.empty(slotCap: 6));
    expect((await persistence.load())!.correlationId, checkpoint.correlationId);
    expect(resumed.currentState.turn, 1);
    expect(resumed.availableActions(), isNotEmpty);
    expect(resumed.displayTurns, isEmpty);
    await resumed.submitAction(resumed.availableActions().first);
    expect((await persistence.load())!.state.turn, 2);
    expect(
        await File('${directory.path}/session_checkpoint.json').readAsString(),
        isNot(contains('I feel restless.')));
  });

  test('terminal result locks actions and persists rewards once across restart',
      () async {
    terminalStart = true;
    final controller = await start();
    final action = controller.availableActions().first;
    await controller.submitAction(action);
    expect(controller.status.value, SessionStatus.completed);
    expect(controller.isActionLocked.value, isTrue);
    expect(controller.result.value!.outcome, SessionOutcome.succeed);
    final saved = (await career.load())!;
    expect(saved.completedSessions, hasLength(1));
    expect(
        saved.profile.eventTail
            .where((e) => e.currency == CurrencyType.xp)
            .single
            .amountMicros,
        greaterThan(0));
    await controller.submitAction(action);
    expect(inference.generationCalls, 1);
    controller.onClose();
    final resumed = await start();
    expect(resumed.status.value, SessionStatus.completed);
    expect((await career.load())!.completedSessions, hasLength(1));
    expect((await career.load())!.profile.eventTail,
        hasLength(saved.profile.eventTail.length));
    final completedId = resumed.result.value!.sessionId;
    await resumed.startNextSession();
    expect(resumed.status.value, SessionStatus.ready);
    await resumed.submitAction(action);
    expect(resumed.result.value!.sessionId, isNot(completedId));
    expect((await career.load())!.completedSessions, hasLength(2));
  });

  test('a terminal checkpoint repairs an interrupted career commit on restart',
      () async {
    terminalStart = true;
    final failed =
        await start(careerOverride: _FailingCareer(directory: directory));
    await failed.submitAction(failed.availableActions().first);
    expect(failed.status.value, SessionStatus.error);
    expect((await persistence.load())!.outputs.last.isTerminal, isTrue);
    expect(await career.load(), isNull);
    failed.onClose();
    final recovered = await start();
    expect(recovered.status.value, SessionStatus.completed);
    expect((await career.load())!.completedSessions, hasLength(1));
    expect(inference.generationCalls, 1);
  });

  test('checkpoint write failure rolls back mechanics and display', () async {
    final failing = _FailingCheckpoint(directory: directory);
    persistence = failing;
    final controller = await start();
    failing.fail = true;
    await controller.submitAction(controller.availableActions().first);
    expect(controller.status.value, SessionStatus.error);
    expect(controller.currentState.turn, 0);
    expect(controller.displayTurns, isEmpty);
    expect((await failing.load())!.state.turn, 0);
  });

  test('retired controller cannot overwrite a newer checkpoint after slow load',
      () async {
    final gate = Completer<void>();
    final started = Completer<void>();
    inference.loadDelay = gate.future;
    inference.loadStarted = started;
    late SessionController retired;
    final pending = start(afterInit: (controller) => retired = controller);
    await started.future;
    retired.onClose();
    inference = FakeInferenceService();
    final replacement = await start();
    await replacement.submitAction(replacement.availableActions().first);
    final checkpoint = (await persistence.load())!;
    gate.complete();
    await pending;
    expect((await persistence.load())!.correlationId, checkpoint.correlationId);
    expect((await persistence.load())!.state.turn, 1);
  });

  test('failed next-session transition preserves the saved terminal result',
      () async {
    terminalStart = true;
    final failing = _FailingCheckpoint(directory: directory);
    persistence = failing;
    final controller = await start();
    await controller.submitAction(controller.availableActions().first);
    failing.failClear = true;
    await controller.startNextSession();
    expect(controller.status.value, SessionStatus.error);
    expect((await failing.load())!.outputs.last.isTerminal, isTrue);
    expect((await career.load())!.completedSessions, hasLength(1));
  });

  test('retired slow save cannot replace a new controller checkpoint',
      () async {
    final delayed = _DelayedCheckpoint(directory: directory);
    persistence = delayed;
    late SessionController retired;
    final pending = start(afterInit: (controller) => retired = controller);
    await delayed.started.future;
    retired.onClose();
    persistence = SessionPersistenceService(directory: directory);
    final replacement = await start();
    await replacement.submitAction(replacement.availableActions().first);
    final checkpoint = (await persistence.load())!;
    delayed.release.complete();
    await pending;
    expect((await persistence.load())!.correlationId, checkpoint.correlationId);
    expect((await persistence.load())!.state.turn, 1);
  });

  test('cancelled turn is rolled back and a new action remains possible',
      () async {
    final controller = await start();
    inference.duringGeneration = controller.cancelTurn;
    await controller.submitAction(controller.availableActions().first);
    expect(controller.currentState.turn, 0);
    expect(controller.displayTurns, isEmpty);
    expect(controller.status.value, SessionStatus.ready);
    inference.duringGeneration = null;
    await controller.submitAction(controller.availableActions().first);
    expect(controller.currentState.turn, 1);
  });
}
