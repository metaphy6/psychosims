import 'package:get/get.dart';
import 'package:psyconfig/psyconfig.dart';

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
  }
}

/// Typed helpers to avoid string-based lookups.
abstract class AppServices {
  static ConfigProvider get config => Get.find<ConfigProvider>();
}
