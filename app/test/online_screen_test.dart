import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:psyconfig/psyconfig.dart';
import 'package:psychemas/psychemas.dart';
import 'package:psycore/psycore.dart' as core;
import 'package:psychosims/features/session/session_controller.dart';
import 'package:psychosims/features/session/session_screen.dart';
import 'package:psychosims/shared/logger.dart';
import 'package:psychosims/shared/response_planner.dart';
import 'fake_inference_service.dart';
import 'package:psychosims/features/online/online_screen.dart';
import 'package:psychosims/shared/api_client.dart';
import 'package:psychosims/shared/auth_service.dart';
import 'package:psychosims/shared/browser_auth_service.dart';
import 'package:psychosims/shared/online_session_service.dart';
import 'package:psychosims/shared/l10n.dart';
import 'auth_service_test.dart' show TestSecrets;

class _FixedOnline extends OnlineSessionService {
  _FixedOnline(
      {required super.auth, required super.directory, required super.network});
  @override
  Future<void> refreshStatus({String? errorKind, bool stale = true}) async {}
  @override
  Future<void> sync() async {}
}

class _NoticeController extends SessionController {
  _NoticeController(OnlineSessionContext context)
      : super(
            config: loadConfig(environment: 'test'),
            inference: FakeInferenceService(),
            logger: PsyLog(minLevel: LogLevel.warn),
            responsePlanner: const ResponsePlanner(),
            clock: const core.InjectedClock.replay(0),
            onlineContext: context);
  @override
  Future<void> loadCase() async {}
}

void main() {
  testWidgets(
      'session distinguishes conditional coverage from a confirmed award',
      (tester) async {
    final permit = SessionAuthorization.fromJson({
      'id': 'session',
      'patient_id': 'patient',
      'ruleset_version': '0.1.0',
      'expires_at': '2027-01-01T00:00:00Z',
      'reward_status': 'conditional_certified',
      'certificate_id': 'a' * 64,
      'catalog_sha256': 'b' * 64,
      'start_state': {
        'loadout': {
          'card_ids': ['open_question'],
          'slot_cap': 5
        },
        'library': {
          'owned_card_ids': ['open_question']
        },
        'controllers': const TherapyControllerSettings().toJson(),
        'initial_axes': {'trust': 40},
        'root_seed': 1729
      }
    });
    final controller = _NoticeController(
        OnlineSessionContext(accountId: 'account', authorization: permit));
    Get.put<SessionController>(controller);
    controller.status.value = SessionStatus.ready;
    await tester.pumpWidget(const GetMaterialApp(home: SessionScreen()));
    await tester.pumpAndSettle();
    expect(find.text(L10n.onlineConditional), findsOneWidget);
    expect(find.textContaining('Server rewards:'), findsNothing);
    controller.status.value = SessionStatus.completed;
    await tester.pumpAndSettle();
    expect(find.text(L10n.onlineQueued), findsOneWidget);
    expect(find.textContaining('Server rewards:'), findsNothing);
    await tester.pumpWidget(const SizedBox());
    Get.reset();
  });

  testWidgets(
      'server certification and limited coverage are visible without local rewards',
      (tester) async {
    final config = loadConfig(environment: 'test');
    for (final row in [
      ('held_unproven', null, 'Synced · rewards held'),
      ('certified', null, 'Synced · result verified'),
      ('certified_unrewarded', 'cooldown', 'Synced · verified without reward'),
      (
        'certified_unrewarded',
        'window_budget',
        'Synced · verified without reward'
      ),
      (
        'certified_unrewarded',
        'economy_disabled',
        'Synced · verified without reward'
      ),
      (
        'certified_unrewarded',
        'balance_limit',
        'Synced · verified without reward'
      ),
      (
        'certified_unrewarded',
        'already_cured',
        'Synced · verified without reward'
      ),
    ]) {
      final api = ApiClient(baseUrl: 'https://example.invalid');
      final auth = AuthService(api: api, storage: TestSecrets());
      final online = _FixedOnline(
          auth: auth,
          directory: Directory('/tmp/agent-runs'),
          network: config.network);
      final verdict = ReceiptVerdict.fromJson({
        'id': 'session',
        'idempotency_key': 'receipt',
        'status': 'accepted',
        'reward_status': row.$1,
        'profile_version': 2,
        if (row.$1 != 'held_unproven') 'certificate_id': 'a' * 64,
        if (row.$2 != null) 'reward_reason': row.$2,
        if (row.$1 == 'certified') ...{
          'xp_awarded': 100,
          'study_points_awarded': 3,
          'cash_micros_awarded': 2500000
        }
      });
      online.status.value = OnlineSyncStatus(
          accountId: 'account',
          stale: false,
          profile: {'level': 1, 'xp': 100},
          verdicts: [verdict]);
      Get.put(auth);
      Get.put<OnlineSessionService>(online);
      Get.put(BrowserAuthService(auth: auth, network: config.network));
      await tester.pumpWidget(const GetMaterialApp(home: OnlineScreen()));
      await tester.pumpAndSettle();
      expect(find.text(L10n.onlineCoverage), findsOneWidget);
      await tester.scrollUntilVisible(find.text(row.$3), 100);
      expect(find.text(row.$3), findsOneWidget);
      expect(find.text(L10n.onlineRewardDetail(verdict)), findsOneWidget);
      if (row.$1 == 'certified') {
        expect(L10n.onlineRewardDetail(verdict), contains('100 XP'));
        expect(L10n.onlineRewardDetail(verdict), contains('3 study points'));
        expect(L10n.onlineRewardDetail(verdict), contains('2.5 cash'));
      }
      await tester.pumpWidget(const SizedBox());
      Get.reset();
      api.close();
      online.dispose();
    }
  });

  testWidgets(
      'unconfigured online sign-in is explicit and has no token-entry form',
      (tester) async {
    final dir = (await tester.runAsync(
        () => Directory('/tmp/agent-runs').createTemp('w3-online-widget-')))!;
    final config = loadConfig(environment: 'test');
    final api = ApiClient(baseUrl: 'https://example.invalid');
    final auth = AuthService(api: api, storage: TestSecrets());
    final online = OnlineSessionService(
        auth: auth, directory: dir, network: config.network);
    Get.put(auth);
    Get.put(online);
    Get.put(BrowserAuthService(auth: auth, network: config.network));
    await tester.pumpWidget(const GetMaterialApp(home: OnlineScreen()));
    await tester.pump();
    await tester.pump();
    expect(find.text(L10n.onlineNotConfigured), findsOneWidget);
    expect(find.byType(TextField), findsNothing);
    final button = tester.widget<FilledButton>(
        find.widgetWithText(FilledButton, L10n.onlineGoogle));
    expect(button.onPressed, isNull);
    await tester.pumpWidget(const SizedBox());
    Get.reset();
    api.close();
    online.dispose();
    await tester.runAsync(() => dir.delete(recursive: true));
  });
}
