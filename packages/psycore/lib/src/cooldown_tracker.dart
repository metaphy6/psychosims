/// Tracks a monotonic cooldown that cannot be skipped by winding the device
/// clock forward (§23, 0.8 injected-clock seam).
class CooldownTracker {
  /// Timestamp (seconds) when the cooldown became available.
  final int readyAtSeconds;

  const CooldownTracker({this.readyAtSeconds = 0});

  /// True if the cooldown is usable at [nowSeconds].
  bool isReady(int nowSeconds) => nowSeconds >= readyAtSeconds;

  /// Starts a cooldown of [durationSeconds] from [nowSeconds].
  CooldownTracker start({
    required int nowSeconds,
    required int durationSeconds,
  }) {
    return CooldownTracker(readyAtSeconds: nowSeconds + durationSeconds);
  }

  /// Remaining seconds until ready (zero if already ready).
  int remainingSeconds(int nowSeconds) {
    final remaining = readyAtSeconds - nowSeconds;
    return remaining > 0 ? remaining : 0;
  }
}
