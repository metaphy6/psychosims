/// Numeric balance constants for the card taxonomy.
///
/// These values are authored in [C-4](BALANCE-SPEC.md) and supplied to the core
/// through the config→core seam. The core never holds card-number literals.
class CardBalance {
  /// Turn count for the Postponing freeze effect.
  final int postponingFreezeTurns;

  /// Trust floor for Manipulative success.
  final int manipulativeSuccessTrust;

  /// Trust floor for Manipulative partial (below this is derangement).
  final int manipulativePartialTrust;

  /// Trauma + agitation threshold that triggers Transference Spike.
  final int transferenceSpikeTrauma;
  final int transferenceSpikeAgitation;

  /// Context-fit cut-points (illustrative; tuned in 2.8).
  final int fitBreakerResistance;
  final int fitBufferTrust;
  final int fitBufferAgitation;
  final int fitFreezeAgitation;
  final int fitGambitTrust;

  const CardBalance({
    this.postponingFreezeTurns = 2,
    this.manipulativeSuccessTrust = 70,
    this.manipulativePartialTrust = 40,
    this.transferenceSpikeTrauma = 70,
    this.transferenceSpikeAgitation = 70,
    this.fitBreakerResistance = 55,
    this.fitBufferTrust = 45,
    this.fitBufferAgitation = 55,
    this.fitFreezeAgitation = 60,
    this.fitGambitTrust = 60,
  });
}
