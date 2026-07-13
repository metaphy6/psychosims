import 'package:psychemas/psychemas.dart';
import 'package:psycore/psycore.dart';
import 'package:test/test.dart';

void main() {
  final manifest = PatientManifest(
    id: 'poc-vexa-001',
    rulesetVersion: 'poc-1.0.0',
    contentChecksum:
        'sha256:0000000000000000000000000000000000000000000000000000000000000000',
    nameKey: 'manifests.poc_vexa_001.name',
    displayNameKey: 'manifests.poc_vexa_001.display_name',
    styleArchetype: StyleArchetype.vexa,
    initialState: const {'trust': 30, 'agitation': 90, 'resistance': 20},
    interactionPatterns: const [InteractionPattern.openQuestion],
    clueTokens: const ['ferve-axine'],
    maxHistoryTurns: 6,
    modelFacingTemplate: 'The patient is restless.',
  );

  const state = SimState(
    seed: 42,
    axes: {'trust': 30, 'agitation': 90, 'resistance': 20},
  );

  group('PatientRoleplayFrame', () {
    const frame = PatientRoleplayFrame();

    test('instruction tells the model to act, not analyse', () {
      final text = frame.instruction(manifest: manifest, state: state);

      expect(text, contains('in the first person'));
      expect(text, contains('Never analyse'));
      expect(text.toLowerCase(), contains('patient'));
      // The clue token is woven in as an instruction, not a key=value dump.
      expect(text, contains('ferve-axine'));
      // High agitation maps to natural-language wording, never a raw number.
      expect(text, contains('very agitated'));
      expect(text, isNot(contains('agitation=90')));
    });

    test('instruction is deterministic for a fixed state', () {
      final a = frame.instruction(manifest: manifest, state: state);
      final b = frame.instruction(manifest: manifest, state: state);
      expect(a, equals(b));
    });

    test('provides in-character few-shot exemplars', () {
      final exemplars = frame.exemplars();
      expect(exemplars, isNotEmpty);
      expect(exemplars.first.role, equals('user'));
      expect(exemplars[1].role, equals('assistant'));
      // Exemplars demonstrate first-person spoken voice with no analysis.
      expect(exemplars[1].text, contains('I'));
      expect(exemplars[1].text, isNot(contains('=')));
    });
  });

  group('PromptAssembler with roleplay frame', () {
    const counter = WhitespaceTokenCounter();
    const template = PlainChatTemplate();
    const assembler = PromptAssembler(
      tokenCounter: counter,
      chatTemplate: template,
      roleplayFrame: PatientRoleplayFrame(),
    );

    test('emits the roleplay instruction and exemplars within budget', () {
      final prompt = assembler.assemble(
        rulesetVersion: 'poc-1.0.0',
        manifest: manifest,
        state: state,
        conversationWindow: const [
          ConversationTurn(role: 'user', text: 'Hello.'),
        ],
        inputBudget: 4096,
        outputReserve: 256,
      );

      // Pin block is retained for reproducibility + injection isolation.
      expect(prompt, contains('ruleset_version=poc-1.0.0'));
      // Roleplay instruction is present.
      expect(prompt, contains('in the first person'));
      // Exemplar turns are present.
      expect(prompt, contains("I can't sit still"));
      // Real conversation window is present.
      expect(prompt, contains('Hello.'));
      // Budget is honoured.
      expect(counter.count(prompt), lessThanOrEqualTo(4096));
    });

    test('turn-0 prompt carries no history digest tokens', () {
      final prompt = assembler.assemble(
        rulesetVersion: 'poc-1.0.0',
        manifest: manifest,
        state: state,
        conversationWindow: const [],
        inputBudget: 4096,
        outputReserve: 256,
      );

      expect(prompt, isNot(contains('HISTORY_DIGEST')));
      expect(prompt, isNot(contains('agitation=')));
    });
  });
}
