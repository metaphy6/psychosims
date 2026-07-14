import 'package:psyconfig/psyconfig.dart';

/// Numeric balance constants for the card taxonomy.
///
/// These values are authored in [C-4](BALANCE-SPEC.md) and supplied to the core
/// through the config→core seam. The core never holds card-number literals.
class CardBalance {
  /// Builds a [CardBalance] from the central config authority's [BalanceConfig].
  ///
  /// Percentage-like config values are converted to fixed-point integer ratios
  /// once at this boundary, so no `double` multiplication ever enters a
  /// deterministic rule.
  factory CardBalance.fromConfig(BalanceConfig cfg) {
    return CardBalance(
      activeCardSlots: cfg.activeCardSlots,
      postponingFreezeTurns: cfg.postponingFreezeTurns,
      // Config trust-bump range is surfaced as a fixed midpoint; the resolver
      // band function owns the exact distribution.
      fitBufferTrust:
          (cfg.relatableTrustBumpMin + cfg.relatableTrustBumpMax) ~/ 2,
    );
  }

  /// Active loadout slot cap (C-4: 5–6).
  final int activeCardSlots;

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

  /// Outcome-engine thresholds (shapes owned by C-11; numbers owned by C-4).
  final int crisisThreshold;
  final int walkoutThreshold;
  final int calmThreshold;
  final int stableTrustFloor;
  final int successProgressThreshold;

  /// Medication model rates (C-4 numbers).
  final int tolerancePerDose;
  final int dependencyPerDose;
  final int medicationAgitationShift;

  const CardBalance({
    this.activeCardSlots = 6,
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
    this.crisisThreshold = 80,
    this.walkoutThreshold = 95,
    this.calmThreshold = 25,
    this.stableTrustFloor = 40,
    this.successProgressThreshold = 100,
    this.tolerancePerDose = 2,
    this.dependencyPerDose = 1,
    this.medicationAgitationShift = 3,
  });
}
