import 'package:psyconfig/psyconfig.dart';

/// Numeric balance constants for the card taxonomy.
///
/// These values are authored in [C-4](BALANCE-SPEC.md) and supplied to the core
/// through the config→core seam. The core never holds card-number literals.
class CardBalance {
  /// Builds a [CardBalance] from the central config authority's [BalanceConfig].
  ///
  /// Only matching units map across this boundary. Per-card trust increments
  /// are not the patient trust threshold used to classify a context fit.
  factory CardBalance.fromConfig(BalanceConfig cfg) {
    return CardBalance(
      activeCardSlots: cfg.activeCardSlots,
      postponingFreezeTurns: cfg.postponingFreezeTurns,
    );
  }

  /// Active loadout slot cap (C-4: 5–6).
  final int activeCardSlots;

  /// Turn count for the Postponing freeze effect.
  final int postponingFreezeTurns;

  /// Baseline agitation added per Postponing play, accrued across sessions (§16).
  final int postponingDecayPerSession;

  /// Cap on accumulated Postponing decay so the carry-over stays bounded.
  final int postponingDecayMax;

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
    this.postponingDecayPerSession = 3,
    this.postponingDecayMax = 40,
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

  /// Exact effective rules bound into trusted core-generated evidence.
  Map<String, int> toJson() => {
        'active_card_slots': activeCardSlots,
        'postponing_freeze_turns': postponingFreezeTurns,
        'postponing_decay_per_session': postponingDecayPerSession,
        'postponing_decay_max': postponingDecayMax,
        'manipulative_success_trust': manipulativeSuccessTrust,
        'manipulative_partial_trust': manipulativePartialTrust,
        'transference_spike_trauma': transferenceSpikeTrauma,
        'transference_spike_agitation': transferenceSpikeAgitation,
        'fit_breaker_resistance': fitBreakerResistance,
        'fit_buffer_trust': fitBufferTrust,
        'fit_buffer_agitation': fitBufferAgitation,
        'fit_freeze_agitation': fitFreezeAgitation,
        'fit_gambit_trust': fitGambitTrust,
        'crisis_threshold': crisisThreshold,
        'walkout_threshold': walkoutThreshold,
        'calm_threshold': calmThreshold,
        'stable_trust_floor': stableTrustFloor,
        'success_progress_threshold': successProgressThreshold,
        'tolerance_per_dose': tolerancePerDose,
        'dependency_per_dose': dependencyPerDose,
        'medication_agitation_shift': medicationAgitationShift,
      };
}
