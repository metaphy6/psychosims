import 'package:flutter_test/flutter_test.dart';
import 'package:psychosims/shared/dialogue_sanitizer.dart';

void main() {
  test('clue matching and removal agree on case', () {
    const sanitizer = DialogueSanitizer();
    expect(
        sanitizer
            .hasRequiredClueTokens('A feeling. [FERVE-AXINE]', ['ferve-axine']),
        isTrue);
    expect(
        sanitizer
            .sanitize('A feeling. [FERVE-AXINE]', clueTokens: ['ferve-axine']),
        'A feeling.');
  });

  group('DialogueSanitizer', () {
    const sanitizer = DialogueSanitizer();

    test('strips echoed system frame', () {
      const frame = 'You are a therapist.';
      const output = 'You are a therapist. I feel restless today.';

      expect(
        sanitizer.sanitize(output, systemFrame: frame),
        equals('I feel restless today.'),
      );
    });

    test('strips clue-token markers', () {
      const output = '[ferve-axine] I have been pacing a lot.';

      expect(
        sanitizer.sanitize(output, clueTokens: const ['ferve-axine']),
        equals('I have been pacing a lot.'),
      );
    });

    test('detects empty output as refusal', () {
      expect(sanitizer.looksLikeRefusal(''), isTrue);
      expect(sanitizer.looksLikeRefusal('   '), isTrue);
    });

    test('detects canned refusal boilerplate', () {
      expect(
        sanitizer.looksLikeRefusal("I can't continue this scenario."),
        isTrue,
      );
      expect(
        sanitizer.looksLikeRefusal('As an AI language model, I cannot...'),
        isTrue,
      );
    });

    test('passes normal dialogue', () {
      expect(
        sanitizer.looksLikeRefusal('I have been pacing around the room.'),
        isFalse,
      );
    });

    test('verifies required clue tokens', () {
      expect(
        sanitizer.hasRequiredClueTokens(
          'The ferve-axine pattern feels familiar.',
          const ['ferve-axine'],
        ),
        isTrue,
      );
      expect(
        sanitizer.hasRequiredClueTokens(
          'I just feel tired.',
          const ['ferve-axine'],
        ),
        isFalse,
      );
    });
  });
}
