import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:psyconfig/psyconfig.dart';
import 'package:psychosims/shared/inference_service.dart';
import 'package:psychosims/shared/model_cache.dart';
import 'package:psychosims/shared/tier_selector.dart';

class _LowMemoryDevice implements DeviceCapabilityProvider {
  @override
  DeviceCapability getCapabilities() => const DeviceCapability(
        totalRamBytes: 1000000,
        availableRamBytes: 1000000,
        abi: 'arm64',
        hasAvx2: false,
        cpuCount: 2,
        isEmulator: false,
      );
}

void main() {
  test('selection and downloaded path stay on the same tier', () async {
    final config = loadConfig(environment: 'test');
    final directory = Directory('/tmp/agent-runs/models-test');
    final cache = ModelCache(
        config: config, directory: directory, capabilities: _LowMemoryDevice());
    expect(cache.source.tier, TierSelection.tierB);
    expect(cache.source.url, config.model.tierBUrl);
    expect(
        await cache.selectedPath, '${directory.path}/${cache.source.fileName}');
    expect(await cache.directory, directory);
  });

  test('a missing selected model cannot become a development stub', () async {
    final dir =
        await Directory('/tmp/agent-runs').createTemp('psychosims-cache-');
    try {
      final cache =
          ModelCache(config: loadConfig(environment: 'test'), directory: dir);
      await expectLater(
          cache.requireModelPath(),
          throwsA(isA<InferenceException>()
              .having((e) => e.kind, 'kind', InferenceErrorKind.missingModel)));
    } finally {
      await dir.delete(recursive: true);
    }
  });

  test('an existing corrupt or unpinned model fails closed', () async {
    final dir =
        await Directory('/tmp/agent-runs').createTemp('psychosims-cache-');
    try {
      final cache =
          ModelCache(config: loadConfig(environment: 'test'), directory: dir);
      await File(await cache.selectedPath).writeAsBytes([0, 1, 2]);
      await expectLater(
          cache.requireModelPath(),
          throwsA(isA<InferenceException>()
              .having((e) => e.kind, 'kind', InferenceErrorKind.corruptModel)));
    } finally {
      await dir.delete(recursive: true);
    }
  });
}
