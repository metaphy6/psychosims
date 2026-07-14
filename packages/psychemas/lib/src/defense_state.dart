/// Active defense posture of the patient in a session (§16).
///
/// Typed enum so the core resolves on tokens, not free text.
enum DefenseState {
  none,
  guarded,
  rigid,
}

extension DefenseStateJson on DefenseState {
  String toJson() => name;
  static DefenseState fromJson(String value) =>
      DefenseState.values.byName(value);
}
