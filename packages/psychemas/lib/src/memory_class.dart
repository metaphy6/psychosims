/// Whether a case remembers history across sessions.
enum MemoryClass {
  /// No history envelope; each session starts from the manifest's initial state.
  stateless,

  /// History (deltas, conversation window) persists across sessions.
  persistent,
}

extension MemoryClassJson on MemoryClass {
  String toJson() => name;

  static MemoryClass fromJson(String value) {
    return MemoryClass.values.byName(value);
  }
}
