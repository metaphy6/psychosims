// ignore_for_file: avoid_print

@Tags(['model_acceptance'])
library;

import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:psyconfig/psyconfig.dart';

import '../tools/model_acceptance.dart';
import 'test_manifest_data.dart';

void main() {
  final config = loadConfig(environment: 'dev');
  final candidates = {
    'Tier A primary (Qwen2.5-1.5B)': config.model.tierAPrimaryUrl,
    'comparator (Phi-3.5-mini)': config.model.tierAFallbackUrl,
    'Tier B fallback (SmolLM2-1.7B)': config.model.tierBUrl,
  };
  for (final entry in candidates.entries) {
    test('diagnose ${entry.key} prompt direction on Linux desktop', () async {
      final report = await diagnoseCandidate(
          config: config,
          candidate: ModelCandidate.fromConfig(
              config, entry.value, Directory(p.join('..', 'assets', 'models'))),
          manifest: testManifest(),
          libraryPath:
              p.join('..', 'native', 'build', 'libpsychosims_native.so'));
      expect(report['kind'], 'diagnostic_only');
      expect(report['acceptance'], 'not established');
      expect(report['mature_probes'], hasLength(3));
      print('MODEL_DIAGNOSTIC ${jsonEncode(report)}');
    }, timeout: const Timeout(Duration(minutes: 20)));
    test('measure ${entry.key} on Linux desktop', () async {
      final report = await measureCandidate(
        config: config,
        candidate: ModelCandidate.fromConfig(
            config, entry.value, Directory(p.join('..', 'assets', 'models'))),
        manifest: testManifest(),
        libraryPath: p.join('..', 'native', 'build', 'libpsychosims_native.so'),
      );
      expect(report['deterministic_pairs'], 20);
      expect(report['raw_quality_n'], 20);
      expect(report['mature_probes'], hasLength(3));
      // A complete host measurement is distinct from passing the reference
      // device's performance targets. Target misses remain explicit in JSON.
      print('MODEL_ACCEPTANCE ${jsonEncode(report)}');
    }, timeout: const Timeout(Duration(minutes: 60)));
  }
}
