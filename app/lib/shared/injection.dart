import 'package:get/get.dart';
import 'package:psyconfig/psyconfig.dart';

import 'dart:io';

import 'package:path/path.dart' as p;

import 'inference_service.dart';
import 'api_client.dart';
import 'auth_service.dart';
import 'browser_auth_service.dart';
import 'secure_storage.dart';
import 'online_session_service.dart';
import 'model_cache.dart';
import 'session_persistence.dart';
import 'career_persistence.dart';
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

    final logger = Get.isRegistered<PsyLog>() ? Get.find<PsyLog>() : PsyLog();
    final storage = Get.isRegistered<SessionPersistenceService>()
        ? Get.find<SessionPersistenceService>().directory
        : null;
    Get.put<ModelCache>(
        ModelCache(
          config: Get.find<ConfigProvider>().config,
          directory: storage == null
              ? null
              : Directory(p.join(storage.path, 'models')),
        ),
        permanent: true);
    if (storage != null && !Get.isRegistered<CareerPersistenceService>()) {
      Get.put<CareerPersistenceService>(
          CareerPersistenceService(directory: storage),
          permanent: true);
    }
    if (!Get.isRegistered<PsyLog>()) {
      Get.put<PsyLog>(logger, permanent: true);
    }

    final network = Get.find<ConfigProvider>().config.network;
    if (!Get.isRegistered<ApiClient>()) {
      Get.put<ApiClient>(
          ApiClient(baseUrl: network.apiBaseUrl, network: network),
          permanent: true);
    }
    if (!Get.isRegistered<SecretStorage>()) {
      Get.put<SecretStorage>(
          PlatformSecretStorage(scope: network.secureStorageNamespace),
          permanent: true);
    }
    if (!Get.isRegistered<AuthService>()) {
      Get.put<AuthService>(
          AuthService(
              api: Get.find<ApiClient>(), storage: Get.find<SecretStorage>()),
          permanent: true);
    }
    if (!Get.isRegistered<BrowserAuthService>()) {
      Get.put<BrowserAuthService>(
          BrowserAuthService(auth: Get.find<AuthService>(), network: network),
          permanent: true);
    }
    if (storage != null && !Get.isRegistered<OnlineSessionService>()) {
      Get.put<OnlineSessionService>(
          OnlineSessionService(
              auth: Get.find<AuthService>(),
              directory: storage,
              network: network),
          permanent: true);
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
