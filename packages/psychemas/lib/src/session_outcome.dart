/// Result classification for a single resolved turn.
///
/// The core resolves every turn into one of four buckets. This is a *turn*
/// outcome; the case lifecycle in [CaseLifecycle] tracks the broader patient
/// state.
enum SessionOutcome {
  /// Case goal met on this turn.
  succeed,

  /// Unrecoverable failure (walkout or hard-fail threshold crossed).
  fail,

  /// Agitation reduced to a calm, stable band.
  stabilize,

  /// Agitation crossed the crisis threshold; the patient may walk out or be
  /// hospitalized unless the next play de-escalates.
  crisis,

  /// Turn resolved without crossing any terminal or stabilization threshold.
  ongoing,
}

extension SessionOutcomeJson on SessionOutcome {
  String toJson() => name;
  static SessionOutcome fromJson(String value) =>
      SessionOutcome.values.byName(value);
}
