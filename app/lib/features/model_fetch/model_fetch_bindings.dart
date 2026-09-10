import 'package:get/get.dart';
import 'package:psyconfig/psyconfig.dart';

import '../../shared/logger.dart';
import '../../shared/model_cache.dart';
import 'model_fetch_controller.dart';

/// Bindings for the first-run model fetch flow.
class ModelFetchBindings extends Bindings {
  @override
  void dependencies() {
    Get.put<ModelFetchController>(
      ModelFetchController(
        config: Get.find<ConfigProvider>().config,
        modelCache: Get.find<ModelCache>(),
        logger: Get.find<PsyLog>(),
      ),
    );
  }
}
