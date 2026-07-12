import 'package:get/get.dart';
import 'package:psyconfig/psyconfig.dart';

import 'inference_service.dart';
import 'logger.dart';

/// Central dependency-injection bindings used by the whole app.
///
/// Follows ADR-0005: GetX is the single DI layer. No global singletons; every
/// service and the config authority are retrieved through `Get.find()`.
class AppBindings extends Bindings {
  @override
  void dependencies() {
    // Config authority is injected here once the app has loaded the active
    // overlay. `dev` is the safe default for local builds.
    Get.put<ConfigProvider>(
      ConfigProvider.forEnvironment(environment: 'dev'),
      permanent: true,
    );

    final logger = PsyLog();
    if (!Get.isRegistered<PsyLog>()) {
      Get.put<PsyLog>(logger, permanent: true);
    }

    // Inference service loads the native library on first use. The model is
    // not loaded here; the session loop owns the lazy model-load lifecycle.
    if (!Get.isRegistered<InferenceService>()) {
      Get.put<InferenceService>(
        InferenceService.load(logger: logger),
        permanent: true,
      );
    }
  }
}

/// Typed helpers to avoid string-based lookups.
abstract class AppServices {
  static ConfigProvider get config => Get.find<ConfigProvider>();
  static PsyLog get logger => Get.find<PsyLog>();
  static InferenceService get inference => Get.find<InferenceService>();
}
