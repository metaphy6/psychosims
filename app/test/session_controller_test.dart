import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:path/path.dart' as p;
import 'package:psyconfig/psyconfig.dart';

import 'package:psychosims/features/session/session_bindings.dart';
import 'package:psychosims/features/session/session_controller.dart';
import 'package:psychosims/shared/inference_service.dart';
import 'package:psychosims/shared/logger.dart';
import 'package:psychosims/shared/session_persistence.dart';

import 'test_manifest_data.dart';

String _libraryPath() {
  final candidate = p.join('..', 'native', 'build', 'libpsychosims_native.so');
  return candidate;
}

Config _testConfig() {
  return loadConfig(environment: 'test');
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() {
    final manifestPath = _testConfig().content.bundledManifestPath;
    final bytes = Uint8List.fromList(testManifestJson().codeUnits);
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMessageHandler('flutter/assets', (message) async {
      final key = utf8.decode(message!.buffer.asUint8List());
      if (key == manifestPath) {
        return ByteData.view(bytes.buffer);
      }
      return null;
    });
  });

  tearDownAll(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMessageHandler('flutter/assets', null);
  });

  setUp(() {
    Get.reset();
    final logger = PsyLog(minLevel: LogLevel.warn);
    final inference = InferenceService.load(
      libraryPath: _libraryPath(),
      logger: logger,
    );
    Get.put<Config>(loadConfig(environment: 'test'));
    Get.put<InferenceService>(inference);
    Get.put<PsyLog>(logger);
    Get.put<SessionPersistenceService>(
      SessionPersistenceService(directory: Directory.systemTemp),
    );
  });

  tearDown(() {
    final inference = Get.find<InferenceService>();
    inference.dispose();
    Get.reset();
  });

  test('loads case and exposes available actions', () async {
    SessionBindings().dependencies();
    final controller = Get.find<SessionController>();
    await controller.loadCase();
    expect(controller.hasManifest, isTrue);
    expect(controller.availableActions(), isNotEmpty);
  });

  test('submitAction streams a response and commits the turn', () async {
    SessionBindings().dependencies();
    final controller = Get.find<SessionController>();
    await controller.loadCase();
    final action = controller.availableActions().first;

    await controller.submitAction(action);

    expect(controller.displayTurns.length, 2); // player + assistant
    expect(controller.displayTurns.any((t) => !t.isPlayer), isTrue);
    expect(controller.status.value, SessionStatus.ready);
  });
}
