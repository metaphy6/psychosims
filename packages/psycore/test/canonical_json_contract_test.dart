import 'dart:convert';

import 'package:psychemas/psychemas.dart';
import 'package:psycore/psycore.dart' as core;
import 'package:test/test.dart';

void main() {
  group('CanonicalJson contract', () {
    test('schemas round-trip through CanonicalJson byte-identically', () {
      final manifest = PatientManifest(
        id: 'case-1',
        rulesetVersion: '0.1.0',
        contentChecksum:
            'sha256:0000000000000000000000000000000000000000000000000000000000000000',
        nameKey: 'name',
        displayNameKey: 'display',
        styleArchetype: StyleArchetype.vexa,
        initialState: const {'trust': 30, 'agitation': 45},
        interactionPatterns: const [InteractionPattern.openQuestion],
        clueTokens: const ['ferve-axine'],
        maxHistoryTurns: 6,
        modelFacingTemplate: 'template',
      );

      final manifestBytes = manifest.toCanonicalBytes();
      final manifestRoundTrip = PatientManifest.fromJson(
          CanonicalJson.decode(manifestBytes) as Map<String, Object?>);
      expect(manifestRoundTrip.toCanonicalBytes(), equals(manifestBytes));

      final delta = StructuredDelta(
        rulesetVersion: '0.1.0',
        axis: 'trust',
        deltaMillis: 5,
        reasonKey: 'reason.open_question',
        cardType: CardType.disclosing,
        cardSignature: CardSignature.breaker,
        contextFit: ContextFit.aligned,
      );
      final deltaBytes = delta.toCanonicalBytes();
      final deltaRoundTrip = StructuredDelta.fromJson(
          CanonicalJson.decode(deltaBytes) as Map<String, Object?>);
      expect(deltaRoundTrip.toCanonicalBytes(), equals(deltaBytes));

      final state = core.SimState(seed: 42, axes: const {'trust': 30});
      final stateBytes = state.toCanonicalBytes();
      final stateRoundTrip = core.SimState.fromJson(
          CanonicalJson.decode(stateBytes) as Map<String, Object?>);
      expect(stateRoundTrip.toCanonicalBytes(), equals(stateBytes));

      final turnOutput = core.TurnOutput(
        nextState: state,
        deltas: [delta],
        requiredClueTokens: const ['ferve-axine'],
      );
      final outputBytes = turnOutput.toCanonicalBytes();
      // Decode-only check: TurnOutput has no fromJson, but the bytes must be
      // stable across two serializations.
      expect(turnOutput.toCanonicalBytes(), equals(outputBytes));
    });

    test('only snake_case keys appear in canonical bytes', () {
      final receipt = SessionReceipt(
        id: 'r-1',
        rulesetVersion: '0.1.0',
        patientId: 'p-1',
        idempotencyKey: 'idemp-1',
        correlationId: 'corr-1',
        turnCount: 3,
        startState: {'seed': 42, 'turn': 0, 'axes': <String, Object?>{}},
        actions: const [],
        deltas: const [],
      );
      final json = utf8.decode(receipt.toCanonicalBytes());
      expect(json, isNot(contains('schemaVersion')));
      expect(json, isNot(contains('rulesetVersion')));
      expect(json, isNot(contains('patientId')));
      expect(json, contains('schema_version'));
      expect(json, contains('ruleset_version'));
      expect(json, contains('patient_id'));
    });
  });
}
