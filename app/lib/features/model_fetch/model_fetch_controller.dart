import 'dart:io';

import 'package:get/get.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:psyconfig/psyconfig.dart';

import '../../shared/l10n.dart';
import '../../shared/logger.dart';
import '../../shared/model_fetch_service.dart';

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
  });

  final Config config;
  final PsyLog logger;

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

    final source = _resolveSource();
    if (source == null) {
      status.value = ModelFetchUiStatus.error;
      errorMessage.value = L10n.modelFetchNoSource;
      return;
    }

    final dir = Directory(p.join(
      (await getApplicationDocumentsDirectory()).path,
      'models',
    ));
    _service = ModelFetchService(config, dir, logger);

    try {
      final file = await _service!.fetchModel(
        source.url,
        source.checksum,
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

  ({String url, String checksum, String fileName})? _resolveSource() {
    final urls = config.model.modelChecksums;
    final primary = config.model.tierAPrimaryUrl;
    if (primary.isNotEmpty && urls.containsKey(primary)) {
      return (
        url: primary,
        checksum: urls[primary]!,
        fileName: p.basename(primary),
      );
    }
    final tierB = config.model.tierBUrl;
    if (tierB.isNotEmpty && urls.containsKey(tierB)) {
      return (
        url: tierB,
        checksum: urls[tierB]!,
        fileName: p.basename(tierB),
      );
    }
    return null;
  }
}
