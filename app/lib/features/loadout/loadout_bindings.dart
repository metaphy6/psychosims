import 'package:get/get.dart';
import 'package:psyconfig/psyconfig.dart';

import '../../shared/injection.dart';
import 'loadout_controller.dart';

/// GetX bindings for the clinical-preparation / loadout feature.
class LoadoutBindings extends Bindings {
  @override
  void dependencies() {
    Get.put<LoadoutController>(
      LoadoutController(
        config: Get.find<ConfigProvider>().config,
        logger: AppServices.logger,
        ownedCardIds: const [],
      ),
    );
  }
}
