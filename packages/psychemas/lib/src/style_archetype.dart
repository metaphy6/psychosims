/// Core-facing style archetype for a patient case.
///
/// These are whitelisted tokens consumed by the deterministic core and the
/// prompt assembler. They never appear as player-facing copy.
enum StyleArchetype {
  /// Restless, easily aroused, needs containment.
  vexa,

  /// Withdrawn, low energy, needs gentle activation.
  torpida,

  /// Guarded, suspicious, needs trust-building.
  vulnax,

  /// Intellectually avoidant, rationalizes, needs reframing.
  dormios,

  /// Overly agreeable, masks distress, needs authenticity.
  quiesa,
}

extension StyleArchetypeJson on StyleArchetype {
  String toJson() => name;

  static StyleArchetype fromJson(String value) {
    return StyleArchetype.values.byName(value);
  }
}
