import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/services.dart';
import 'package:crypto/crypto.dart';
import 'package:psychosims/shared/l10n.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:psychemas/psychemas.dart';
import 'package:psyconfig/psyconfig.dart';
import 'package:psycore/psycore.dart' as core;
import 'package:psychosims/features/session/session_controller.dart';
import 'package:psychosims/shared/auth_service.dart';
import 'package:psychosims/shared/api_client.dart';
import 'package:psychosims/shared/career_persistence.dart';
import 'package:psychosims/shared/online_session_service.dart';
import 'package:psychosims/shared/logger.dart';
import 'package:psychosims/shared/response_planner.dart';
import 'auth_service_test.dart' show TestSecrets;
import 'fake_inference_service.dart';
import 'test_manifest_data.dart';

class CapturingOnline extends OnlineSessionService {
  CapturingOnline(Directory dir)
      : super(
            auth: AuthService(
                api: ApiClient(baseUrl: 'https://example.invalid'),
                storage: TestSecrets()),
            directory: dir,
            network: loadConfig(environment: 'test').network);
  final receipts = <SessionReceipt>[];
  @override
  Future<void> enqueue(
      OnlineSessionContext context, SessionReceipt receipt) async {
    receipts.add(receipt);
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test(
      'online controller uses trusted start and queues held result without local rewards',
      () async {
    final dir =
        await Directory('/tmp/agent-runs').createTemp('w3-online-controller-');
    addTearDown(() => dir.delete(recursive: true));
    final config = loadConfig(environment: 'test');
    final manifest = testManifest();
    final data = Uint8List.fromList(utf8.encode(testManifestJson()));
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMessageHandler(
            'flutter/assets', (message) async => ByteData.view(data.buffer));
    addTearDown(() => TestDefaultBinaryMessengerBinding
        .instance.defaultBinaryMessenger
        .setMockMessageHandler('flutter/assets', null));
    final model = File('${dir.path}/fixture.gguf');
    await model.writeAsBytes([1]);
    final online = CapturingOnline(dir);
    addTearDown(online.auth.api.close);
    addTearDown(online.dispose);
    final start = const SessionStartState(
            loadout: Loadout(cardIds: ['open_question'], slotCap: 6),
            library: CardLibrary(ownedCardIds: {'open_question'}),
            controllers: TherapyControllerSettings(),
            initialAxes: {
              'trust': 40,
              'agitation': 10,
              'resistance': 0,
              'trauma': 0,
              'session_progress': 0
            },
            rootSeed: 9123)
        .toJson();
    start['manifest_checksum'] = manifest.contentChecksum;
    start['case_id'] = manifest.id;
    final context = OnlineSessionContext(
        accountId: 'account',
        authorization: SessionAuthorization.fromJson({
          'id': 'server-permit',
          'patient_id': 'patient_instance_1',
          'ruleset_version': manifest.rulesetVersion,
          'start_state': start,
          'expires_at': DateTime.now()
              .toUtc()
              .add(const Duration(hours: 1))
              .toIso8601String(),
          'reward_status': 'held_unproven'
        }));
    final career = CareerPersistenceService(directory: dir);
    final controller = SessionController(
        config: config,
        inference: FakeInferenceService(),
        logger: PsyLog(minLevel: LogLevel.error),
        responsePlanner: const ResponsePlanner(),
        clock: const core.InjectedClock.replay(1000),
        modelPath: model.path,
        careerPersistence: career,
        online: online,
        onlineContext: context);
    controller.onInit();
    addTearDown(controller.onClose);
    await controller.loadCase();
    expect(controller.currentState.seed, 9123);
    expect(controller.currentState.trustScore, 40);
    final snapshot = SessionStartState.fromJson(start);
    final witness = core.SolvabilityOracle(
            balance: core.CardBalance.fromConfig(config.balance))
        .analyze(manifest,
            rootSeed: snapshot.rootSeed,
            startState: controller.currentState,
            loadout: snapshot.loadout,
            library: snapshot.library,
            controllers: snapshot.controllers);
    expect(witness.solved, isTrue);
    expect(witness.actions, hasLength(100));
    for (final action in witness.actions) {
      await controller.submitAction(action);
    }
    expect(controller.status.value, SessionStatus.completed);
    expect(online.receipts.single.turnCount, 100);
    expect(online.receipts.single.id, 'server-permit');
    expect(online.receipts.single.startState, start);
    expect(controller.result.value!.rewards, isEmpty);
    expect(await career.load(), isNull);
  });
  test('six equipped server cards fail production setup before the first turn',
      () async {
    final dir =
        await Directory('/tmp/agent-runs').createTemp('w3-slot-parity-');
    addTearDown(() => dir.delete(recursive: true));
    final config = loadConfig(environment: 'prod');
    expect(config.balance.activeCardSlots, 5);
    final cards = InteractionPattern.values
        .map((action) => cardFromInteractionPattern(action).id)
        .toList();
    expect(cards, hasLength(6));
    final json = jsonDecode(testManifestJson()) as Map<String, Object?>;
    json['interaction_patterns'] =
        InteractionPattern.values.map((action) => action.toJson()).toList();
    json['content_checksum'] = '';
    json['content_checksum'] =
        'sha256:${sha256.convert(CanonicalJson.encode(json))}';
    final data = Uint8List.fromList(CanonicalJson.encode(json));
    final manifest = const ManifestLoader().load(data);
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMessageHandler(
            'flutter/assets', (_) async => ByteData.view(data.buffer));
    addTearDown(() => TestDefaultBinaryMessengerBinding
        .instance.defaultBinaryMessenger
        .setMockMessageHandler('flutter/assets', null));
    final start = SessionStartState(
            loadout: Loadout(cardIds: cards, slotCap: 6),
            library: CardLibrary(ownedCardIds: cards.toSet()),
            controllers: const TherapyControllerSettings(),
            initialAxes: manifest.initialState,
            rootSeed: 9123)
        .toJson()
      ..['case_id'] = manifest.id
      ..['manifest_checksum'] = manifest.contentChecksum;
    final online = CapturingOnline(dir);
    addTearDown(online.auth.api.close);
    addTearDown(online.dispose);
    final inference = FakeInferenceService();
    final controller = SessionController(
        config: config,
        inference: inference,
        logger: PsyLog(minLevel: LogLevel.error),
        responsePlanner: const ResponsePlanner(),
        clock: const core.InjectedClock.replay(1000),
        online: online,
        onlineContext: OnlineSessionContext(
            accountId: 'account',
            authorization: SessionAuthorization.fromJson({
              'id': 'six-card-permit',
              'patient_id': 'patient',
              'ruleset_version': manifest.rulesetVersion,
              'start_state': start,
              'expires_at': DateTime.now()
                  .toUtc()
                  .add(const Duration(hours: 1))
                  .toIso8601String(),
              'reward_status': 'held_unproven'
            })));
    controller.onInit();
    addTearDown(controller.onClose);
    await controller.loadCase();
    expect(controller.status.value, SessionStatus.error);
    expect(controller.errorMessage.value, L10n.loadoutInvalid);
    expect(inference.loadedPath, isNull);
    await controller.submitAction(InteractionPattern.openQuestion);
    expect(inference.generationCalls, 0);
    expect(controller.currentState.turn, 0);
    expect(online.receipts, isEmpty);
  });
}
