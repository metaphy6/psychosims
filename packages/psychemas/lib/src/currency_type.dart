/// Offline career currencies (§9, C-4).
///
/// Kept as an enum so the ledger and every UI readout use a single canonical
/// token; values serialize to stable snake_case strings.
enum CurrencyType {
  /// Clinic operating currency (cash).
  cash,

  /// Study points earned through play and spent on field training.
  study,

  /// Subspecialty points for advanced cross-disciplinary fields.
  subspecialty,

  /// Experience points for role / tier unlocks.
  xp,

  /// Event-sourced, recency-weighted reputation.
  reputation,

  /// Endgame status/legacy currency.
  prestige,
}

extension CurrencyTypeJson on CurrencyType {
  String toJson() => name;

  static CurrencyType fromJson(String value) =>
      CurrencyType.values.byName(value);
}
