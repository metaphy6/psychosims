/// Abstract clock seam for deterministic, server-reconcilable time.
///
/// The deterministic core receives time through this seam only. No wall-clock
/// call lives inside `packages/psycore`; [nowMillis] is the injected
/// authoritative time and [monotonicMillis] is a real, advancing monotonic
/// source supplied by the harness or app.
abstract class Clock {
  /// Current authoritative time in milliseconds since epoch.
  int nowMillis();

  /// Monotonic timestamp for local durations (device clock is untrusted).
  int monotonicMillis();
}

/// Clock driven by injected values; used for tests, replay, and sandbox runs.
///
/// Both [epochMillis] and [startedAt] must be supplied explicitly. The caller
/// (harness or app) is responsible for advancing [startedAt] when measuring
/// real elapsed local time; the core never reads [DateTime.now].
class InjectedClock implements Clock {
  final int _epochMillis;
  final int _startedAt;

  const InjectedClock(this._epochMillis, this._startedAt);

  /// Creates a clock anchored at [epochMillis] with a zero monotonic base.
  /// Useful for pure replay where elapsed local time is irrelevant.
  const InjectedClock.replay(this._epochMillis) : _startedAt = 0;

  @override
  int nowMillis() => _epochMillis;

  @override
  int monotonicMillis() => _startedAt;
}

/// Advances the monotonic source of an injected clock by [deltaMillis].
///
/// Returns a new [InjectedClock] with the same authoritative time but a later
/// monotonic base, so cooldown and elapsed-time tests can drive time forward
/// explicitly.
InjectedClock advanceMonotonic(InjectedClock clock, int deltaMillis) {
  return InjectedClock(
      clock.nowMillis(), clock.monotonicMillis() + deltaMillis);
}
