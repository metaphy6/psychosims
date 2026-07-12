/// Abstract clock seam for deterministic, server-reconcilable time.
abstract class Clock {
  /// Current authoritative time in milliseconds since epoch.
  int nowMillis();

  /// Monotonic timestamp for local durations (device clock is untrusted).
  int monotonicMillis();
}

/// Clock driven by an injected value; used for tests and replay.
class InjectedClock implements Clock {
  final int _epochMillis;
  final int _startedAt;

  InjectedClock(this._epochMillis)
      : _startedAt = DateTime.now().millisecondsSinceEpoch;

  @override
  int nowMillis() => _epochMillis;

  @override
  int monotonicMillis() => _startedAt;
}
