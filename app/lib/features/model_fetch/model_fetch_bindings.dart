import 'package:get/get.dart';
import 'package:psyconfig/psyconfig.dart';

import '../../shared/logger.dart';
import 'model_fetch_controller.dart';

/// Bindings for the first-run model fetch flow.
class ModelFetchBindings extends Bindings {
  @override
  void dependencies() {
    Get.put<ModelFetchController>(
      ModelFetchController(
        config: Get.find<Config>(),
        logger: Get.find<PsyLog>(),
      ),
    );
  }
}
