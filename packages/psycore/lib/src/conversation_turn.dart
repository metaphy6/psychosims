/// A single turn in the sliding conversation window.
///
/// Kept intentionally simple: no model-facing logic, just role + text. The
/// assembler consumes this structure and never mutates it.
class ConversationTurn {
  final String role;
  final String text;

  const ConversationTurn({required this.role, required this.text});

  Map<String, Object?> toJson() => {
        'role': role,
        'text': text,
      };

  factory ConversationTurn.fromJson(Map<String, Object?> json) {
    return ConversationTurn(
      role: json['role']! as String,
      text: json['text']! as String,
    );
  }

  @override
  bool operator ==(Object other) =>
      other is ConversationTurn && other.role == role && other.text == text;

  @override
  int get hashCode => Object.hash(role, text);
}
