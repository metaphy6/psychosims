// ignore_for_file: avoid_print

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:psychemas/psychemas.dart';
import 'package:psycore/psycore.dart' as core;
import 'package:psyconfig/psyconfig.dart';

import 'package:psychosims/shared/headless_harness.dart';
import 'package:psychosims/shared/inference_service.dart';
import 'package:psychosims/shared/logger.dart';
import 'package:psychosims/shared/metrics_service.dart';

String _libraryPath() =>
    p.join('..', 'native', 'build', 'libpsychosims_native.so');

String _modelPath(String fileName) =>
    p.join('..', 'assets', 'models', fileName);

/// Returns true if the response leaks internal prompt-frame structure — the
/// key=value pin block, an ALL-CAPS control token, or an echoed frame marker.
bool _leaksFrame(String response) {
  final lower = response.toLowerCase();
  const markers = [
    'ruleset_version',
    'case_id',
    'style_archetype',
    'clue_tokens',
    'history_digest',
    'based_analysis',
    'model_facing',
  ];
  if (markers.any(lower.contains)) return true;
  if (RegExp(r'\b[a-z_]+=[a-z0-9]').hasMatch(lower)) return true;
  if (RegExp(r'\b[A-Z][A-Z_]{4,}\b').hasMatch(response)) return true;
  return false;
}

class _Variant {
  const _Variant({
    required this.label,
    required this.archetype,
    required this.clue,
    required this.axes,
    required this.persona,
  });

  final String label;
  final StyleArchetype archetype;
  final String clue;
  final Map<String, int> axes;
  final String persona;

  PatientManifest manifest() => PatientManifest(
        id: 'poc-${archetype.name}-001',
        rulesetVersion: 'poc-1.0.0',
        contentChecksum:
            'sha256:0000000000000000000000000000000000000000000000000000000000000000',
        nameKey: 'manifests.poc.name',
        displayNameKey: 'manifests.poc.display_name',
        styleArchetype: archetype,
        initialState: axes,
        interactionPatterns: const [InteractionPattern.openQuestion],
        clueTokens: [clue],
        maxHistoryTurns: 6,
        modelFacingTemplate: persona,
      );
}

const _variants = [
  _Variant(
    label: 'vexa/agitated',
    archetype: StyleArchetype.vexa,
    clue: 'ferve-axine',
    axes: {'trust': 30, 'agitation': 90, 'resistance': 20},
    persona: 'The patient is restless and cannot sit still.',
  ),
  _Variant(
    label: 'torpida/withdrawn',
    archetype: StyleArchetype.torpida,
    clue: 'lumendarow',
    axes: {'trust': 20, 'agitation': 10, 'resistance': 30},
    persona: 'The patient is withdrawn and speaks in short, flat sentences.',
  ),
  _Variant(
    label: 'vulnax/guarded',
    archetype: StyleArchetype.vulnax,
    clue: 'sabrenoxa',
    axes: {'trust': 10, 'agitation': 40, 'resistance': 85},
    persona: 'The patient is guarded and suspicious of the therapist.',
  ),
];

void main() {
  final config = loadConfig(environment: 'dev').copyWith(
    inference: loadConfig(environment: 'dev').inference.copyWith(
          greedyDecode: true,
        ),
  );

  test(
    'Tier A primary acts in character across manifest variations',
    () async {
      const modelFile = 'qwen2.5-1.5b-instruct-q4_k_m.gguf';
      if (!File(_modelPath(modelFile)).existsSync()) {
        markTestSkipped('Qwen model not present on disk');
        return;
      }

      final logger = PsyLog(minLevel: LogLevel.warn);
      final inference = InferenceService.load(
        libraryPath: _libraryPath(),
        logger: logger,
      );
      await inference.loadModel(_modelPath(modelFile));
      final harness = HeadlessHarness(
        config: config,
        inference: inference,
        metrics: MetricsService(),
        logger: logger,
      );

      for (final variant in _variants) {
        final manifest = variant.manifest();
        final result = await harness.runTurn(
          manifest: manifest,
          state: core.SimState.fromInitialState(42, variant.axes),
          action: manifest.interactionPatterns.first,
          modelPath: _modelPath(modelFile),
        );

        final raw = result.rawResponse.trim();
        final normalized = raw.toLowerCase();
        final firstPerson =
            RegExp(r"\b(i|i'm|i've|i'd|i'll|me|my|myself)\b").hasMatch(
          normalized,
        );
        final noLeak = !_leaksFrame(raw);
        final noListicle = !RegExp(r'\b\d+[.)]\s').hasMatch(raw);
        final honoursClue = normalized.contains(variant.clue.toLowerCase());

        print('[${variant.label}] first_person=$firstPerson no_leak=$noLeak '
            'no_listicle=$noListicle honours_clue=$honoursClue');
        print('[${variant.label}] response:\n$raw\n');

        // Acting must hold for every manifest variation, not just the one PoC
        // case. Clue-token weaving is a reported signal (the model does not
        // always weave it), so it is not hard-asserted here.
        expect(firstPerson, isTrue,
            reason: '${variant.label} should speak in first person');
        expect(noLeak, isTrue,
            reason: '${variant.label} must not leak the prompt frame');
        expect(noListicle, isTrue,
            reason: '${variant.label} must not emit a numbered listicle');
      }

      await inference.dispose();
    },
    timeout: const Timeout(Duration(minutes: 5)),
  );
}
