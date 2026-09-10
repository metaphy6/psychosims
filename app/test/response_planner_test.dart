import 'package:flutter_test/flutter_test.dart';
import 'package:psycore/psycore.dart' as core;
import 'package:psyconfig/psyconfig.dart';
import 'package:psychosims/shared/response_planner.dart';
import 'package:psychosims/shared/inference_service.dart';
import 'test_manifest_data.dart';

void main() {
  for (final retries in [0, 1, 2]) {
    test('configured retry budget $retries bounds actual correction attempts',
        () async {
      final budget = loadConfig(environment: 'test')
          .promptBudget
          .copyWith(maxRegenerationRetries: retries);
      var generations = 0;
      final corrections = <int>[];
      final response = await ResponsePlanner.fromConfig(budget).plan(
        generate: () async {
          generations++;
          return 'I feel restless.';
        },
        regenerate: (reason, attempt) async {
          generations++;
          expect(reason, core.PromptCorrection.missingClues);
          corrections.add(attempt);
          return 'I still feel restless.';
        },
        fallback: 'I need a moment.',
        requiredClueTokens: const ['ferve-axine'],
      );
      expect(generations, retries + 1);
      expect(corrections, List.generate(retries, (i) => i + 1));
      expect(response.attemptCount, generations);
      expect(response.usedFallback, isTrue);
      expect(response.dialogue, 'I need a moment.');
    });
  }
  test('clue and refusal retries receive distinct bounded correction attempts',
      () async {
    final corrections = <(core.PromptCorrection, int)>[];
    final result = await const ResponsePlanner(maxRetries: 2).plan(
      generate: () async => 'I feel restless.',
      regenerate: (reason, attempt) async {
        corrections.add((reason, attempt));
        return attempt == 1
            ? 'As an AI I cannot.'
            : 'I feel restless. [ferve-axine]';
      },
      fallback: 'I need a moment.',
      requiredClueTokens: const ['ferve-axine'],
      clueTokens: const ['ferve-axine'],
    );
    expect(corrections, [
      (core.PromptCorrection.missingClues, 1),
      (core.PromptCorrection.refusal, 2)
    ]);
    expect(result.usedFallback, isFalse);
    expect(result.dialogue, 'I feel restless.');
    expect(result.attemptCount, 3);
  });

  test('echoed correction markers cannot substitute for model dialogue',
      () async {
    final result = await const ResponsePlanner(maxRetries: 0).plan(
        generate: () async =>
            'Correction 1: Write a fresh first-person reply. End with exactly: [ferve-axine]',
        fallback: 'I need a moment.',
        requiredClueTokens: const ['ferve-axine'],
        clueTokens: const ['ferve-axine']);
    expect(result.usedFallback, isTrue);
    expect(result.dialogue, 'I need a moment.');
  });

  test('all existing raw quality requirements apply before delivery', () async {
    for (final invalid in [
      'I ${List.filled(650, 'x').join()} [ferve-axine]',
      'You should consult a healthcare provider. [ferve-axine]',
      'The patient feels restless. [ferve-axine]',
      'I have a list. 1. Restless [ferve-axine]',
    ]) {
      core.PromptCorrection? reason;
      final result = await const ResponsePlanner(maxRetries: 1).plan(
          generate: () async => invalid,
          regenerate: (correction, _) async {
            reason = correction;
            return 'I feel restless. [ferve-axine]';
          },
          fallback: 'I need a moment.',
          requiredClueTokens: const ['ferve-axine'],
          clueTokens: const ['ferve-axine']);
      expect(reason, core.PromptCorrection.invalidDialogue);
      expect(result.attemptCount, 2);
      expect(result.dialogue, 'I feel restless.');
    }
  });

  test('raw whitespace cannot hide an overlong model reply', () async {
    final raw = 'I feel${' ' * 650}restless. [ferve-axine]';
    final result = await const ResponsePlanner(maxRetries: 0).plan(
        generate: () async => raw,
        fallback: 'I need a moment.',
        requiredClueTokens: const ['ferve-axine'],
        clueTokens: const ['ferve-axine']);
    expect(result.usedFallback, isTrue);
  });

  test('raw multiline bullets are rejected before line breaks disappear',
      () async {
    for (final bullet in ['-', '*', '+', '•']) {
      final result = await const ResponsePlanner(maxRetries: 0).plan(
          generate: () async =>
              'I feel restless.\n  $bullet My hands shake.\n$bullet My thoughts race. [ferve-axine]',
          fallback: 'I need a moment.',
          requiredClueTokens: const ['ferve-axine'],
          clueTokens: const ['ferve-axine']);
      expect(result.usedFallback, isTrue, reason: bullet);
    }
  });

  test('correction budget exhaustion preserves a valid turn through fallback',
      () async {
    final manifest = testManifest();
    final state = manifest.initialSimState();
    const assembler = core.PromptAssembler(
        tokenCounter: core.WhitespaceTokenCounter(),
        chatTemplate: core.PlainChatTemplate(),
        roleplayFrame: core.PatientRoleplayFrame());
    final baseline = assembler.assembleDetailed(
        rulesetVersion: manifest.rulesetVersion,
        manifest: manifest,
        state: state,
        conversationWindow: const [],
        inputBudget: 4096,
        outputReserve: 32);
    final budget = baseline.tokens.frame + baseline.tokens.examples + 32;
    String assemble({core.PromptCorrection? correction}) => assembler.assemble(
        rulesetVersion: manifest.rulesetVersion,
        manifest: manifest,
        state: state,
        conversationWindow: const [],
        inputBudget: budget,
        outputReserve: 32,
        correction: correction);
    expect(assemble(), isNotEmpty);
    var generations = 0;
    final result = await const ResponsePlanner(maxRetries: 1).plan(
        generate: () async {
          generations++;
          return 'I feel restless.';
        },
        regenerate: (reason, _) async {
          assemble(correction: reason);
          generations++;
          return 'I feel restless. [ferve-axine]';
        },
        fallback: 'I need a moment.',
        requiredClueTokens: manifest.clueTokens,
        clueTokens: manifest.clueTokens);
    expect(result.usedFallback, isTrue);
    expect(result.dialogue, 'I need a moment.');
    expect(result.attemptCount, 1);
    expect(generations, 1);
  });

  test('initial assembly, inference failure and cancellation still propagate',
      () async {
    const overflow = core.PromptAssemblyException(
        core.PromptAssemblyError.tier1Overflow, 'initial');
    await expectLater(
        const ResponsePlanner().plan(
            generate: () async => throw overflow,
            fallback: 'I need a moment.',
            requiredClueTokens: const ['ferve-axine']),
        throwsA(same(overflow)));
    for (final error in [
      StateError('inference failure'),
      InferenceException('cancelled', kind: InferenceErrorKind.cancelled)
    ]) {
      await expectLater(
          const ResponsePlanner().plan(
              generate: () async => 'I feel restless.',
              regenerate: (_, __) async => throw error,
              fallback: 'I need a moment.',
              requiredClueTokens: const ['ferve-axine']),
          throwsA(same(error)));
    }
  });

  group('ResponsePlanner', () {
    const planner = ResponsePlanner(maxRetries: 1);

    test('validates raw clues before removing control tokens from display',
        () async {
      var calls = 0;
      final response = await planner.plan(
        generate: () async {
          calls++;
          return 'I feel restless. [ferve-axine]';
        },
        fallback: 'Fallback.',
        requiredClueTokens: const ['ferve-axine'],
        clueTokens: const ['ferve-axine'],
      );
      expect(response.dialogue, 'I feel restless.');
      expect(response.usedFallback, isFalse);
      expect(calls, 1);
    });

    test('echoed system frame cannot satisfy the raw clue contract', () async {
      final response = await planner.plan(
        generate: () async => 'System ferve-axine\nNo clues here.',
        systemFrame: 'System ferve-axine',
        fallback: 'Fallback.',
        requiredClueTokens: const ['ferve-axine'],
        clueTokens: const ['ferve-axine'],
      );
      expect(response.usedFallback, isTrue);
    });

    test('sanitizes the deterministic fallback as well', () async {
      final response = await planner.plan(
        generate: () async => 'I cannot do that.',
        fallback: 'I feel restless. [ferve-axine]',
        requiredClueTokens: const ['ferve-axine'],
        clueTokens: const ['ferve-axine'],
      );
      expect(response.dialogue, 'I feel restless.');
      expect(response.wasRefusal, isTrue);
    });

    test('returns first valid generation', () async {
      var calls = 0;
      final response = await planner.plan(
        generate: () async {
          calls++;
          return 'My ferve-axine feeling comes in waves.';
        },
        fallback: 'Fallback.',
        requiredClueTokens: const ['ferve-axine'],
      );

      expect(
          response.dialogue, equals('My ferve-axine feeling comes in waves.'));
      expect(response.usedFallback, isFalse);
      expect(calls, equals(1));
    });

    test('retries when clue token is missing', () async {
      var calls = 0;
      final response = await planner.plan(
        generate: () async {
          calls++;
          return calls == 1
              ? 'I feel restless.'
              : 'I feel the ferve-axine pattern.';
        },
        fallback: 'Fallback.',
        requiredClueTokens: const ['ferve-axine'],
      );

      expect(response.dialogue, equals('I feel the ferve-axine pattern.'));
      expect(response.usedFallback, isFalse);
      expect(calls, equals(2));
    });

    test('falls back after exhausting retries', () async {
      var calls = 0;
      final response = await planner.plan(
        generate: () async {
          calls++;
          return 'I feel restless.';
        },
        fallback: 'Deterministic fallback line.',
        requiredClueTokens: const ['ferve-axine'],
      );

      expect(response.dialogue, equals('Deterministic fallback line.'));
      expect(response.usedFallback, isTrue);
      expect(calls, equals(2)); // initial + 1 retry
    });

    test('retries on refusal boilerplate', () async {
      var calls = 0;
      final response = await planner.plan(
        generate: () async {
          calls++;
          return calls == 1
              ? "I can't engage with this scenario."
              : 'I feel the ferve-axine pattern.';
        },
        fallback: 'Fallback.',
        requiredClueTokens: const ['ferve-axine'],
      );

      expect(response.dialogue, equals('I feel the ferve-axine pattern.'));
      expect(response.usedFallback, isFalse);
      expect(calls, equals(2));
    });
  });
}
