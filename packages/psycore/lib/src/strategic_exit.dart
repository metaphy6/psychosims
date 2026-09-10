/// Outcome of a strategic exit choice for an over-matched case (§13).
enum StrategicExitChoice {
  /// Reject the case; it returns to the pool with no penalty.
  reject,

  /// Ethically refer the case; small XP reward, no reputation hit.
  refer,

  /// Force the case; agitation spike / walkout / reputation hit.
  force,
}

/// Deterministic result of applying a strategic exit choice.
class StrategicExitResult {
  final int xpDelta;
  final int reputationDelta;
  final int agitationDelta;
  final bool caseLost;

  const StrategicExitResult({
    this.xpDelta = 0,
    this.reputationDelta = 0,
    this.agitationDelta = 0,
    this.caseLost = false,
  });
}

/// Resolves the §13 strategic-exit choices.
class StrategicExitResolver {
  const StrategicExitResolver();

  StrategicExitResult resolve(StrategicExitChoice choice) {
    return switch (choice) {
      StrategicExitChoice.reject => const StrategicExitResult(),
      StrategicExitChoice.refer => const StrategicExitResult(
          xpDelta: 1,
          reputationDelta: 0,
          agitationDelta: 0,
        ),
      StrategicExitChoice.force => const StrategicExitResult(
          xpDelta: 0,
          reputationDelta: -5,
          agitationDelta: 25,
          caseLost: true,
        ),
    };
  }
}
