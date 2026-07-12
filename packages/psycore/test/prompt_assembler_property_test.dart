import 'package:psychemas/psychemas.dart';
import 'package:psycore/psycore.dart';
import 'package:test/test.dart';

void main() {
  group('PromptAssembler property', () {
    const counter = WhitespaceTokenCounter();
    const template = PlainChatTemplate();
    const assembler = PromptAssembler(
      tokenCounter: counter,
      chatTemplate: template,
    );

    PatientManifest buildManifest({required int templateWords}) {
      return PatientManifest(
        id: 'poc-vexa-001',
        rulesetVersion: 'poc-1.0.0',
        contentChecksum:
            'sha256:0000000000000000000000000000000000000000000000000000000000000000',
        nameKey: 'manifests.poc_vexa_001.name',
        displayNameKey: 'manifests.poc_vexa_001.display_name',
        styleArchetype: StyleArchetype.vexa,
        initialState: const {'trust': 30, 'agitation': 45, 'resistance': 25},
        interactionPatterns: const [InteractionPattern.openQuestion],
        clueTokens: const ['ferve-axine'],
        maxHistoryTurns: 6,
        modelFacingTemplate: List.filled(templateWords, 'word').join(' '),
      );
    }

    test('output tokens never exceed input budget and T1 is preserved', () {
      final random = SeededPrng(12345);

      for (var i = 0; i < 100; i++) {
        final manifest = buildManifest(
          templateWords: 2 + random.nextInt(20),
        );
        final windowLength = random.nextInt(12);
        final window = <ConversationTurn>[
          for (var j = 0; j < windowLength; j++)
            ConversationTurn(
              role: j.isEven ? 'user' : 'assistant',
              text: List.filled(1 + random.nextInt(8), 'token').join(' '),
            ),
        ];
        final state = SimState(
          seed: random.nextInt(0x7fffffff),
          axes: {
            'trust': random.nextInt(100),
            'agitation': random.nextInt(100),
            'resistance': random.nextInt(100),
          },
        );
        final inputBudget = 32 + random.nextInt(128);
        final outputReserve = 4 + random.nextInt(16);

        String prompt;
        try {
          prompt = assembler.assemble(
            rulesetVersion: 'poc-1.0.0',
            manifest: manifest,
            state: state,
            conversationWindow: window,
            inputBudget: inputBudget,
            outputReserve: outputReserve,
          );
        } on PromptAssemblyException catch (e) {
          // Tier-1 overflow is an expected, loud failure for over-budget
          // manifests; it is not a budget violation.
          expect(e.kind, equals(PromptAssemblyError.tier1Overflow));
          continue;
        }

        final usedTokens = counter.count(prompt);
        expect(
          usedTokens,
          lessThanOrEqualTo(inputBudget),
          reason: 'Used $usedTokens tokens against budget $inputBudget',
        );
        expect(prompt, contains('ruleset_version=poc-1.0.0'));
        expect(prompt, contains('clue_tokens=ferve-axine'));
      }
    });
  });
}
