/// Core-facing interaction pattern available for a case.
///
/// These are whitelisted actions the deterministic core can resolve. The
/// player-facing names are localization keys; this enum is never shown raw.
enum InteractionPattern {
  /// Ask an open-ended question.
  openQuestion,

  /// Validate the patient's experience.
  validate,

  /// Reframe a statement.
  reframe,

  /// Set a gentle boundary.
  setBoundary,

  /// Offer a reflection.
  reflect,

  /// Disclose a clinical parallel (clue-bearing).
  discloseParallel,
}

extension InteractionPatternJson on InteractionPattern {
  String toJson() => _toSnakeCase(name);

  static InteractionPattern fromJson(String value) {
    final camel = value.replaceAllMapped(
      RegExp(r'_([a-z])'),
      (m) => m.group(1)!.toUpperCase(),
    );
    return InteractionPattern.values.byName(camel);
  }

  static String _toSnakeCase(String camel) {
    return camel
        .replaceAllMapped(
          RegExp(r'([a-z])([A-Z])'),
          (m) => '${m.group(1)}_${m.group(2)!.toLowerCase()}',
        )
        .toLowerCase();
  }
}
