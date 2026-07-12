import 'package:flutter_test/flutter_test.dart';
import 'package:psychosims/shared/response_planner.dart';

void main() {
  group('ResponsePlanner', () {
    const planner = ResponsePlanner(maxRetries: 1);

    test('returns first valid generation', () async {
      var calls = 0;
      final response = await planner.plan(
        generate: () async {
          calls++;
          return 'The ferve-axine feeling comes in waves.';
        },
        fallback: 'Fallback.',
        requiredClueTokens: const ['ferve-axine'],
      );

      expect(
          response.dialogue, equals('The ferve-axine feeling comes in waves.'));
      expect(response.usedFallback, isFalse);
      expect(calls, equals(1));
    });

    test('retries when clue token is missing', () async {
      var calls = 0;
      final response = await planner.plan(
        generate: () async {
          calls++;
          return calls == 1 ? 'I feel restless.' : 'The ferve-axine pattern.';
        },
        fallback: 'Fallback.',
        requiredClueTokens: const ['ferve-axine'],
      );

      expect(response.dialogue, equals('The ferve-axine pattern.'));
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
              : 'The ferve-axine pattern.';
        },
        fallback: 'Fallback.',
        requiredClueTokens: const ['ferve-axine'],
      );

      expect(response.dialogue, equals('The ferve-axine pattern.'));
      expect(response.usedFallback, isFalse);
      expect(calls, equals(2));
    });
  });
}
