/// Configuration values consumed by [ReputationDecay].
class ReputationDecayConfig {
  /// Half-life for recency weighting, in seconds.
  final int halfLifeSeconds;

  /// Number of buckets covering one half-life each.
  final int buckets;

  /// Reputation floor per unlocked study field (fixed-point millis).
  final int competencyPerFieldMillis;

  const ReputationDecayConfig({
    this.halfLifeSeconds = 7 * 24 * 60 * 60, // 1 week
    this.buckets = 4,
    this.competencyPerFieldMillis = 100,
  });
}

/// A single reputation event for recency-weighted aggregation.
class ReputationEvent {
  final int amountMillis;
  final int timestampSeconds;

  const ReputationEvent({
    required this.amountMillis,
    required this.timestampSeconds,
  });
}

/// Event-sourced, recency-weighted reputation with fixed-point decay.
///
/// Reputation is not a lifetime ratio; older events decay in integer buckets
/// (no float `exp`) and the result is floored by credentials derived from
/// unlocked study fields.
class ReputationDecay {
  final ReputationDecayConfig config;

  const ReputationDecay(this.config);

  /// Computes the current reputation at [nowSeconds].
  ///
  /// [events] is the raw event stream (positive/negative shocks).
  /// [unlockedFieldCount] sets the credential floor.
  int reputationAt({
    required List<ReputationEvent> events,
    required int unlockedFieldCount,
    required int nowSeconds,
  }) {
    if (events.isEmpty && unlockedFieldCount == 0) return 0;

    var weightedSum = 0;
    for (final event in events) {
      final ageSeconds = nowSeconds - event.timestampSeconds;
      final weight = _decayWeight(ageSeconds);
      weightedSum += (event.amountMillis * weight) ~/ 1000;
    }

    final floor =
        (unlockedFieldCount * config.competencyPerFieldMillis) ~/ 1000;
    return (weightedSum + floor).clamp(0, 1000000000);
  }

  /// Integer decay table: each bucket halves the weight.
  ///
  /// Returns a fixed-point weight in millis (1000 = full, 500 = half, ...).
  int _decayWeight(int ageSeconds) {
    if (ageSeconds < 0) return 1000;
    final bucket = ageSeconds ~/ config.halfLifeSeconds;
    if (bucket >= config.buckets) return 0;
    return 1000 >> bucket;
  }
}
