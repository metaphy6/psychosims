/// Configuration weights for the patient-attraction vector.
class AttractionVectorConfig {
  final int reputationWeight;
  final int priceAccessibilityWeight;
  final int studyFieldCoverageWeight;

  const AttractionVectorConfig({
    this.reputationWeight = 1,
    this.priceAccessibilityWeight = 1,
    this.studyFieldCoverageWeight = 1,
  });
}

/// Patient-attraction vector (§10): reputation + price accessibility + study
/// field coverage. The three-factor score is a UI readout, not the routing
/// algorithm.
class AttractionVector {
  final AttractionVectorConfig config;

  const AttractionVector(this.config);

  /// Returns a fixed-point score in millis (0..1000 mapped from input factors).
  ///
  /// [reputation] is current reputation (unbounded integer).
  /// [maxPrice] is the clinic's maximum affordable fee (higher = less accessible).
  /// [unlockedFields] count of training-tree fields unlocked.
  /// [totalFields] count of fields available in the tree.
  int score({
    required int reputation,
    required int maxPrice,
    required int unlockedFields,
    required int totalFields,
  }) {
    if (totalFields <= 0) return 0;

    final reputationComponent = _normalize(reputation);
    final priceComponent = maxPrice <= 0 ? 1000 : (1000 * 100) ~/ maxPrice;
    final fieldComponent = (1000 * unlockedFields) ~/ totalFields;

    final totalWeight = config.reputationWeight +
        config.priceAccessibilityWeight +
        config.studyFieldCoverageWeight;
    if (totalWeight <= 0) return 0;

    var weighted = reputationComponent * config.reputationWeight +
        priceComponent.clamp(0, 1000) * config.priceAccessibilityWeight +
        fieldComponent * config.studyFieldCoverageWeight;
    return (weighted ~/ totalWeight).clamp(0, 1000);
  }

  static int _normalize(int value) {
    if (value <= 0) return 0;
    if (value >= 1000) return 1000;
    return value;
  }
}
