import 'conversation_turn.dart';

/// Formats a list of conversation turns into the model's expected chat frame.
///
/// Each candidate model (Qwen2.5, Phi-3.5-mini, SmolLM2) expects a different
/// roleplay frame, so the assembler resolves the active template through config
/// rather than hard-coding one.
abstract class ChatTemplate {
  const ChatTemplate();

  /// Renders the complete prompt including the system frame and all turns.
  String render(
      {required String systemFrame, required List<ConversationTurn> turns});
}

/// Simple, deterministic chat template used for tests and as a fallback.
class PlainChatTemplate implements ChatTemplate {
  const PlainChatTemplate();

  @override
  String render(
      {required String systemFrame, required List<ConversationTurn> turns}) {
    final buffer = StringBuffer();
    buffer.writeln('### System');
    buffer.writeln(systemFrame);
    for (final turn in turns) {
      buffer.writeln('### ${turn.role.toUpperCase()}');
      buffer.writeln(turn.text);
    }
    buffer.write('### Assistant\n');
    return buffer.toString();
  }
}
