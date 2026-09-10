import 'package:get/get.dart';
import 'package:psychemas/psychemas.dart';
import 'package:psycore/psycore.dart' as core;
import 'package:psyconfig/psyconfig.dart';

import '../../shared/logger.dart';
import '../../shared/online_session_service.dart';
import '../../shared/response_planner.dart';
import '../../shared/session_persistence.dart';
import '../../shared/model_cache.dart';
import '../../shared/career_persistence.dart';
import 'session_controller.dart';

/// Bindings for the session flow.
class SessionBindings extends Bindings {
  @override
  void dependencies() {
    final config = Get.find<ConfigProvider>().config;
    final logger = Get.find<PsyLog>();

    final args = Get.arguments as Map<String, dynamic>?;
    final loadout = args?['loadout'] as Loadout?;
    final library = args?['library'] as CardLibrary?;
    final controllers = args?['controllers'] as TherapyControllerSettings?;
    final onlineContext = args?['online_context'] as OnlineSessionContext?;
    final online =
        onlineContext == null ? null : Get.find<OnlineSessionService>();

    Get.put<SessionController>(
      SessionController(
        config: config,
        inference: Get.find(),
        logger: logger,
        responsePlanner: ResponsePlanner.fromConfig(config.promptBudget),
        clock: core.InjectedClock.replay(DateTime.now().millisecondsSinceEpoch),
        modelCache: Get.find<ModelCache>(),
        careerPersistence: Get.find<CareerPersistenceService>(),
        persistence: onlineContext == null
            ? Get.find<SessionPersistenceService>()
            : online!.checkpoints(onlineContext.accountId),
        online: online,
        onlineContext: onlineContext,
        initialLoadout: loadout,
        initialLibrary: library,
        initialControllers: controllers,
      ),
    );
  }
}
