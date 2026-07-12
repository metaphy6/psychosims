// This is a basic Flutter widget test.
//
// To perform an interaction with a widget in your test, use the WidgetTester
// utility in the flutter_test package. For example, you can send tap and scroll
// gestures. You can also use WidgetTester to find child widgets in the widget
// tree, read text, and verify that the values of widget properties are correct.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:path/path.dart' as p;
import 'package:psyconfig/psyconfig.dart';

import 'package:psychosims/main.dart';
import 'package:psychosims/shared/inference_service.dart';
import 'package:psychosims/shared/logger.dart';

String _libraryPath() =>
    p.join('..', 'native', 'build', 'libpsychosims_native.so');

void main() {
  testWidgets('App smoke test', (WidgetTester tester) async {
    final logger = PsyLog(minLevel: LogLevel.warn);
    Get.put<Config>(loadConfig(environment: 'test'));
    Get.put<PsyLog>(logger);
    Get.put<InferenceService>(
      InferenceService.load(libraryPath: _libraryPath(), logger: logger),
    );

    await tester.pumpWidget(const PsychosimsApp());
    expect(find.byType(MaterialApp), findsOneWidget);

    Get.reset();
  });
}
