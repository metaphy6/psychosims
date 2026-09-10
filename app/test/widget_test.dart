import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:psychemas/psychemas.dart';
import 'package:psyconfig/psyconfig.dart';
import 'package:psychosims/shared/career_persistence.dart';
import 'package:psychosims/main.dart';
import 'package:psychosims/features/session/session_controller.dart';
import 'package:psychosims/features/loadout/loadout_controller.dart';
import 'package:psychosims/shared/inference_service.dart';
import 'package:psychosims/shared/l10n.dart';
import 'package:psychosims/shared/model_cache.dart';
import 'package:psychosims/shared/session_persistence.dart';

import 'fake_inference_service.dart';

class _ReadyCache extends ModelCache {
  _ReadyCache({required super.config});

  @override
  Future<String> requireModelPath() async => 'verified-fixture.gguf';
}

class _PausedFirstCheckpoint extends SessionPersistenceService {
  _PausedFirstCheckpoint({required super.directory});
  final started = Completer<void>();
  final release = Completer<void>();
  bool _paused = false;

  @override
  Future<void> save(SessionCheckpoint checkpoint,
      {bool Function()? canCommit}) async {
    if (!_paused) {
      _paused = true;
      started.complete();
      await release.future;
    }
    await super.save(checkpoint, canCommit: canCommit);
  }
}

void main() {
  late Directory directory;
  setUp(() async {
    Get.reset();
    directory =
        await Directory('/tmp/agent-runs').createTemp('psychosims-startup-');
    Get.put<InferenceService>(FakeInferenceService(), permanent: true);
    Get.put<SessionPersistenceService>(
        SessionPersistenceService(directory: directory),
        permanent: true);
  });
  tearDown(() async {
    Get.reset();
    await directory.delete(recursive: true);
  });

  testWidgets('home shows durable local progress and completed history',
      (tester) async {
    await tester
        .runAsync(() => CareerPersistenceService(directory: directory).save(
              const CareerSave(
                profile: CareerProfile(
                    profileId: 'local-practice',
                    rulesetVersion: '0.1.0',
                    snapshotBalancesMicros: {'xp': 100000000}),
                completedSessions: [
                  CareerSessionRecord(
                    sessionId: 'finished',
                    manifestId: 'poc-vexa-001',
                    outcome: SessionOutcome.succeed,
                    receipt: SessionReceipt(
                        id: 'finished',
                        rulesetVersion: '0.1.0',
                        patientId: 'poc-vexa-001',
                        idempotencyKey: 'finished',
                        correlationId: 'finished',
                        turnCount: 7,
                        startState: {},
                        actions: [],
                        deltas: []),
                    rewards: [],
                  )
                ],
              ),
            ));
    await tester.runAsync(() async {
      await tester.pumpWidget(const PsychosimsApp());
      await tester.pumpAndSettle();
      await Get.find<CareerPersistenceService>().load();
    });
    await tester.pumpAndSettle();
    expect(find.text(L10n.careerSessions(1)), findsOneWidget);
    expect(find.textContaining('XP: 100'), findsOneWidget);
    expect(find.text(L10n.careerTurns(7)), findsOneWidget);
  });

  testWidgets(
      'production startup navigates to model download without Config injection',
      (tester) async {
    await tester.pumpWidget(const PsychosimsApp());
    await tester.tap(find.text(L10n.homeFetchModel));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(find.text(L10n.modelFetchTitle), findsOneWidget);
  });

  testWidgets(
      'production startup navigates loadout to session without Config injection',
      (tester) async {
    await tester.pumpWidget(const PsychosimsApp());
    expect(find.byType(MaterialApp), findsOneWidget);
    await tester.tap(find.text(L10n.homeStartPocSession));
    await tester.pumpAndSettle();
    await tester.runAsync(() async {
      await tester.tap(find.text(L10n.loadoutStartSession));
      await tester.pump();
      await Get.find<SessionController>().loadCase();
    });
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    // Missing downloaded models must surface an actionable state, never a stub.
    expect(find.text(const L10n().errorMessage('errors.model_load_failed')),
        findsOneWidget);
  });

  testWidgets(
      'empty loadout cannot start and equipping a card enables navigation',
      (tester) async {
    await tester.pumpWidget(const PsychosimsApp());
    await tester.tap(find.text(L10n.homeStartPocSession));
    await tester.pumpAndSettle();
    final loadout = Get.find<LoadoutController>();
    final card = loadout.activeCardIds.first;
    for (final id in loadout.activeCardIds) {
      loadout.unequip(id);
    }
    await tester.pump();
    final start = find.widgetWithText(ElevatedButton, L10n.loadoutStartSession);
    expect(tester.widget<ElevatedButton>(start).onPressed, isNull);
    await tester.tap(start);
    await tester.pumpAndSettle();
    expect(Get.isRegistered<SessionController>(), isFalse);
    expect(
        await tester
            .runAsync(() => Get.find<SessionPersistenceService>().load()),
        isNull);
    await tester.tap(find.byTooltip('${L10n.loadoutAddTooltip} $card'));
    await tester.pump();
    expect(tester.widget<ElevatedButton>(start).onPressed, isNotNull);
    await tester.runAsync(() async {
      await tester.tap(start);
      await tester.pump();
      await Get.find<SessionController>().loadCase();
    });
    await tester.pumpAndSettle();
    expect(Get.find<SessionController>().availableActions(), hasLength(1));
    expect(tester.takeException(), isNull);
  });

  testWidgets(
      'back and restart retire a slow checkpoint and preserve the new run',
      (tester) async {
    await tester.pumpWidget(const PsychosimsApp());
    Get.replace<ModelCache>(
        _ReadyCache(config: Get.find<ConfigProvider>().config));
    late _PausedFirstCheckpoint persistence;
    await tester.runAsync(() async {
      persistence = _PausedFirstCheckpoint(directory: directory);
      Get.replace<SessionPersistenceService>(persistence);
    });
    await tester.tap(find.text(L10n.homeStartPocSession));
    await tester.pumpAndSettle();
    late Future<void> pending;
    late SessionController retired;
    await tester.runAsync(() async {
      await tester.tap(find.text(L10n.loadoutStartSession));
      await tester.pump();
      retired = Get.find<SessionController>();
      pending = retired.loadCase();
      await persistence.started.future.timeout(const Duration(seconds: 5),
          onTimeout: () => throw StateError(
              'Checkpoint not reached: ${retired.status.value}, ${retired.errorMessage.value}'));
    });
    await tester.pump(const Duration(seconds: 1));
    await tester.pageBack();
    await tester.pumpAndSettle();
    expect(retired.isClosed, isTrue);
    final loadout = Get.find<LoadoutController>();
    final card = loadout.activeCardIds.first;
    for (final id in loadout.activeCardIds.where((id) => id != card)) {
      loadout.unequip(id);
    }
    await tester.pump();
    late SessionController replacement;
    late SessionCheckpoint saved;
    await tester.runAsync(() async {
      await tester.tap(find.text(L10n.loadoutStartSession));
      await tester.pump();
      replacement = Get.find<SessionController>();
      await replacement.loadCase().timeout(const Duration(seconds: 5));
      await replacement
          .submitAction(replacement.availableActions().single)
          .timeout(const Duration(seconds: 5));
      saved = (await persistence.load())!;
      persistence.release.complete();
      await pending.timeout(const Duration(seconds: 5));
      expect((await persistence.load())!.correlationId, saved.correlationId);
      expect((await persistence.load())!.state.turn, 1);
    });
    await tester.pumpAndSettle();
    await tester.pageBack();
    await tester.pumpAndSettle();
    loadout.equip(loadout.ownedCardIds.firstWhere((id) => id != card));
    await tester.pump();
    await tester.runAsync(() async {
      await tester.tap(find.text(L10n.loadoutStartSession));
      await tester.pump();
      final resumed = Get.find<SessionController>();
      await resumed.loadCase().timeout(const Duration(seconds: 5));
      expect(resumed.currentState.turn, 1);
      expect(resumed.availableActions(), hasLength(1));
      expect((await persistence.load())!.correlationId, saved.correlationId);
    });
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });
}
