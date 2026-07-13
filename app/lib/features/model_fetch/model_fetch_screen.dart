import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../shared/l10n.dart';
import 'model_fetch_controller.dart';

/// First-run model download screen.
///
/// Shows progress, pause/resume, metered-connection posture, and error states
/// for the verified, resumable large-asset fetch.
class ModelFetchScreen extends StatelessWidget {
  const ModelFetchScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = Get.find<ModelFetchController>();
    return Scaffold(
      appBar: AppBar(title: const Text(L10n.modelFetchTitle)),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Obx(() {
          final status = controller.status.value;
          final isDownloading = status == ModelFetchUiStatus.downloading;
          final isComplete = status == ModelFetchUiStatus.complete;
          final isError = status == ModelFetchUiStatus.error;

          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                L10n.modelFetchDescription,
                style: Theme.of(context).textTheme.bodyLarge,
              ),
              const SizedBox(height: 24),
              LinearProgressIndicator(value: controller.progress.value),
              const SizedBox(height: 12),
              Text(
                L10n.modelFetchProgress(
                  (controller.progress.value * 100).toInt(),
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              Row(
                children: [
                  Checkbox(
                    value: controller.isMetered.value,
                    onChanged: isDownloading
                        ? null
                        : (v) => controller.setMetered(v ?? false),
                  ),
                  const Expanded(child: Text(L10n.modelFetchMeteredLabel)),
                ],
              ),
              const SizedBox(height: 16),
              if (isError)
                Text(
                  controller.errorMessage.value,
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.error,
                  ),
                ),
              if (isError) const SizedBox(height: 16),
              ElevatedButton(
                onPressed: isDownloading
                    ? controller.pauseFetch
                    : controller.startFetch,
                child: Text(
                  isDownloading
                      ? L10n.modelFetchPause
                      : controller.isPaused.value
                          ? L10n.modelFetchResume
                          : L10n.modelFetchStart,
                ),
              ),
              if (isComplete)
                Padding(
                  padding: const EdgeInsets.only(top: 16),
                  child: Text(
                    L10n.modelFetchComplete,
                    style: Theme.of(context).textTheme.titleMedium,
                    textAlign: TextAlign.center,
                  ),
                ),
            ],
          );
        }),
      ),
    );
  }
}
