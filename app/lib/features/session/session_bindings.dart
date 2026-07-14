import 'dart:io';

import 'package:get/get.dart';
import 'package:path/path.dart' as p;
import 'package:psycore/psycore.dart' as core;
import 'package:psyconfig/psyconfig.dart';

import '../../shared/logger.dart';
import '../../shared/response_planner.dart';
import '../../shared/session_persistence.dart';
import '../../shared/tier_selector.dart';
import 'session_controller.dart';

/// Bindings for the session flow.
class SessionBindings extends Bindings {
  @override
  void dependencies() {
    final config = Get.find<Config>();
    final logger = Get.find<PsyLog>();
    final resolvedPath = _resolveModelPath(config, logger);

    Get.put<SessionController>(
      SessionController(
        config: config,
        inference: Get.find(),
        logger: logger,
        responsePlanner: const ResponsePlanner(),
        clock: const core.InjectedClock.replay(0),
        modelPath: resolvedPath,
        persistence: Get.find<SessionPersistenceService>(),
      ),
    );
  }

  /// Resolves the local model path via [TierSelector] and the default device
  /// capability provider. If the resolved model file is not present, returns
  /// `null` so the controller falls back to the PoC stub path.
  String? _resolveModelPath(Config config, PsyLog logger) {
    try {
      final provider = DefaultDeviceCapabilityProvider();
      final capabilities = provider.getCapabilities();
      final selector = TierSelector();
      final tier = selector.select(capabilities, config);
      final source = selector.resolveSource(tier, config);
      // Treat the temp directory as the local model cache for the PoC.
      final localPath = p.join(Directory.systemTemp.path, source.fileName);
      logger.debug('session', 'tier_selected', kv: {
        'tier': tier.name,
        'source_url': source.url,
        'local_path': localPath,
      });
      return localPath;
    } on Exception catch (e, st) {
      logger.warn('session', 'tier_resolution_failed',
          kv: {'error': '$e', 'stack': '$st'});
      return null;
    }
  }
}
