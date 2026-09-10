import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:psyconfig/psyconfig.dart';

import 'inference_service.dart';
import 'tier_selector.dart';

/// One selected tier and durable cache shared by model download and sessions.
class ModelCache {
  ModelCache(
      {required this.config,
      Directory? directory,
      DeviceCapabilityProvider? capabilities})
      : _directory = directory,
        source =
            _select(config, capabilities ?? DefaultDeviceCapabilityProvider());

  final Config config;
  final Directory? _directory;
  final ModelSource source;

  static ModelSource _select(
      Config config, DeviceCapabilityProvider capabilities) {
    final selector = TierSelector();
    return selector.resolveSource(
        selector.select(capabilities.getCapabilities(), config), config);
  }

  Future<Directory> get directory async =>
      _directory ??
      Directory(
          p.join((await getApplicationDocumentsDirectory()).path, 'models'));

  Future<String> get selectedPath async =>
      p.join((await directory).path, source.fileName);

  /// Re-verifies bytes before real loading; corrupt/unpinned files fail closed.
  Future<String> requireModelPath() async {
    final path = await selectedPath;
    final file = File(path);
    if (!await file.exists()) {
      throw InferenceException('Download the selected model first.',
          kind: InferenceErrorKind.missingModel);
    }
    final expected = source.checksum?.replaceFirst('sha256:', '').toLowerCase();
    if (expected == null ||
        expected.isEmpty ||
        (await sha256.bind(file.openRead()).first).toString() != expected) {
      throw InferenceException('Selected model checksum does not match.',
          kind: InferenceErrorKind.corruptModel);
    }
    return path;
  }
}
