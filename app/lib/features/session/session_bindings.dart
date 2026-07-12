import 'package:get/get.dart';
import 'package:psycore/psycore.dart' as core;

import '../../shared/response_planner.dart';
import 'session_controller.dart';

/// Bindings for the session flow.
class SessionBindings extends Bindings {
  @override
  void dependencies() {
    Get.put<SessionController>(
      SessionController(
        config: Get.find(),
        inference: Get.find(),
        logger: Get.find(),
        responsePlanner: const ResponsePlanner(),
        clock: core.InjectedClock(0),
      ),
    );
  }
}
