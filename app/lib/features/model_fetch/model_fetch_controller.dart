import 'package:get/get.dart';
import 'package:psyconfig/psyconfig.dart';

import '../../shared/l10n.dart';
import '../../shared/logger.dart';
import '../../shared/model_fetch_service.dart';
import '../../shared/model_cache.dart';

/// UI state for the first-run model fetch screen.
enum ModelFetchUiStatus { idle, downloading, verifying, complete, error }

/// Controller for the first-run model fetch screen.
///
/// Surfaces download progress, pause/resume, metered-connection posture, and
/// the 0.10 verified-fetch error taxonomy as localized, actionable states.
class ModelFetchController extends GetxController {
  ModelFetchController({
    required this.config,
    required this.logger,
    required this.modelCache,
  });

  final Config config;
  final PsyLog logger;
  final ModelCache modelCache;

  final status = ModelFetchUiStatus.idle.obs;
  final progress = 0.0.obs;
  final errorMessage = ''.obs;
  final isMetered = false.obs;
  final isPaused = false.obs;

  ModelFetchService? _service;

  /// Starts (or resumes) the fetch for the selected tier.
  Future<void> startFetch() async {
    if (status.value == ModelFetchUiStatus.downloading) return;

    status.value = ModelFetchUiStatus.downloading;
    errorMessage.value = '';
    isPaused.value = false;
    progress.value = 0.0;

    try {
      final source = modelCache.source;
      final checksum = source.checksum;
      if (checksum == null || checksum.isEmpty || source.url.isEmpty) {
        status.value = ModelFetchUiStatus.error;
        errorMessage.value = L10n.modelFetchNoSource;
        return;
      }
      _service = ModelFetchService(config, await modelCache.directory, logger);
      final file = await _service!.fetchModel(
        source.url,
        checksum,
        meteredConnection: isMetered.value,
        onProgress: (p) => progress.value = p,
      );
      status.value = ModelFetchUiStatus.complete;
      progress.value = 1.0;
      logger.success('model_fetch_ui', 'fetch_complete', kv: {
        'path': file.path,
      });
    } on ModelFetchMeteredException catch (_) {
      status.value = ModelFetchUiStatus.error;
      errorMessage.value = L10n.modelFetchMetered;
    } on ModelFetchDiskSpaceException catch (e) {
      status.value = ModelFetchUiStatus.error;
      errorMessage.value = L10n.modelFetchDiskSpace(
        e.requiredBytes,
        e.freeBytes,
      );
    } on ModelFetchChecksumException catch (_) {
      status.value = ModelFetchUiStatus.error;
      errorMessage.value = L10n.modelFetchChecksumError;
    } on ModelFetchCancelledException catch (_) {
      status.value = ModelFetchUiStatus.idle;
      isPaused.value = true;
    } on ModelFetchException catch (e) {
      status.value = ModelFetchUiStatus.error;
      errorMessage.value = e.message;
    } on Exception catch (e) {
      status.value = ModelFetchUiStatus.error;
      errorMessage.value = e.toString();
    }
  }

  /// Pauses the active fetch.
  void pauseFetch() {
    _service?.cancel();
  }

  /// Toggles the metered-connection posture.
  void setMetered(bool value) {
    isMetered.value = value;
  }

  @override
  void onClose() {
    _service?.cancel();
    super.onClose();
  }
}
