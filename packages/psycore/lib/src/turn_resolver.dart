import 'package:psychemas/psychemas.dart';

import 'card_balance.dart';
import 'clock.dart';
import 'prng.dart';
import 'ruleset_profile.dart';
import 'seed_derivation.dart';
import 'sim_state.dart';
import 'turn_input.dart';
import 'turn_output.dart';

/// Pure deterministic turn resolver.
///
/// Given a [TurnInput], produces a [TurnOutput]. No wall-clock, no ambient
/// randomness: the seeded PRNG plus the fixed input fully determine the
/// outcome (0.8 determinism contract).
class TurnResolver {
  final Clock clock;
  final CardBalance balance;

  const TurnResolver(this.clock, {this.balance = const CardBalance()});

  TurnOutput resolve(TurnInput input) {
    if (input.loadout.cardIds.length > input.loadout.slotCap) {
      throw ArgumentError(
        'Loadout exceeds its slot cap: ${input.loadout.cardIds.length} > ${input.loadout.slotCap}',
      );
    }
    if (input.loadout.cardIds.length > balance.activeCardSlots) {
      throw ArgumentError(
        'Loadout exceeds active slot cap: ${input.loadout.cardIds.length} > ${balance.activeCardSlots}',
      );
    }
    final defaultCard = cardFromInteractionPattern(input.action);
    final card = input.manifest.resolvedCards.firstWhere(
      (c) => c.id == defaultCard.id,
      orElse: () => defaultCard,
    );
    if (!input.loadout.contains(card.id)) {
      throw ArgumentError(
        'Card ${card.id} is not in the active loadout',
      );
    }
    if (!input.library.owns(card.id)) {
      throw ArgumentError(
        'Card ${card.id} is not owned by the player',
      );
    }
    if (!input.manifest.interactionPatterns.contains(input.action)) {
      throw ArgumentError(
        'Action ${input.action.name} is not available for case ${input.manifest.id}',
      );
    }

    final seed = deriveTurnSeed(
      caseId: input.manifest.id,
      turnIndex: input.state.turn,
      actionName: input.action.name,
      rootSeed: input.state.seed,
      profile: RulesetProfile.forVersion(input.rulesetVersion),
    );
    final prng = SeededPrng.forRuleset(seed, input.rulesetVersion);

    final effectiveCard = _resolveEffectiveCard(card, input.state);
    final fit = _computeContextFit(
      effectiveCard.signature,
      input.state,
      input.controllers,
    );

    var next = input.state;
    final deltas = <StructuredDelta>[];

    // Frozen turns are decremented first; if the patient is fully frozen the
    // card still resolves but is muffled by the existing freeze. This keeps the
    // deterministic draw in the stream even when it has reduced effect.
    if (next.freezeTurns > 0) {
      next = next.copyWith(freezeTurns: next.freezeTurns - 1);
      deltas.add(StructuredDelta(
        rulesetVersion: input.rulesetVersion,
        axis: StateAxis.freezeTurns,
        deltaMillis: -1,
        reasonKey: 'deltas.freeze.decrement',
        cardType: effectiveCard.type,
        cardSignature: effectiveCard.signature,
        contextFit: fit,
      ));
    }

    final effect = _resolveEffect(prng, effectiveCard, fit, next);
    next = _applyEffect(
        next, effect, effectiveCard, fit, input.rulesetVersion, deltas.add);

    next = _applyMedication(
        next, effectiveCard, fit, input.rulesetVersion, deltas.add);

    // Baseline session progress: each turn advances the session by one step.
    next = next.copyWith(
      turn: next.turn + 1,
      sessionProgress: _clamp(next.sessionProgress + 1),
    );
    deltas.add(StructuredDelta(
      rulesetVersion: input.rulesetVersion,
      axis: StateAxis.sessionProgress,
      deltaMillis: 1,
      reasonKey: 'deltas.session.progress',
      cardType: effectiveCard.type,
      cardSignature: effectiveCard.signature,
      contextFit: fit,
    ));

    final outcome = _classifyOutcome(next);
    final lifecycle = _nextLifecycle(
      input.state.turn == 0 ? CaseLifecycle.open : CaseLifecycle.inTreatment,
      outcome,
    );
    final isTerminal =
        outcome == SessionOutcome.succeed || outcome == SessionOutcome.fail;

    return TurnOutput(
      nextState: next,
      deltas: deltas,
      requiredClueTokens: input.manifest.clueTokens,
      outcome: outcome,
      isTerminal: isTerminal,
      lifecycle: lifecycle,
    );
  }

  /// Applies the Transference Spike reclassification (§16): in a high-trauma
  /// state, Relatable plays resolve as Manipulative failures.
  Card _resolveEffectiveCard(Card card, SimState state) {
    if (card.type == CardType.relatable &&
        state.trauma >= balance.transferenceSpikeTrauma &&
        state.agitationLevel >= balance.transferenceSpikeAgitation) {
      return card.copyWith(
        type: CardType.manipulative,
        signature: CardSignature.gambit,
      );
    }
    return card;
  }

  /// Computes context-fit from signature + current state + controllers.
  ContextFit _computeContextFit(
    CardSignature signature,
    SimState state,
    TherapyControllerSettings controllers,
  ) {
    final trust = state.trustScore;
    final agitation = state.agitationLevel;
    final resistance = state.resistance;

    final int score;
    switch (signature) {
      case CardSignature.breaker:
        score = resistance >= balance.fitBreakerResistance
            ? 0
            : resistance >= balance.fitBreakerResistance - 25
                ? 1
                : 2;
      case CardSignature.buffer:
        score = trust >= balance.fitBufferTrust &&
                agitation < balance.fitBufferAgitation
            ? 0
            : trust >= balance.fitBufferTrust - 20
                ? 1
                : 2;
      case CardSignature.freeze:
        score = agitation >= balance.fitFreezeAgitation
            ? 0
            : agitation >= balance.fitFreezeAgitation - 25
                ? 1
                : 2;
      case CardSignature.gambit:
        score = trust >= balance.fitGambitTrust
            ? 0
            : trust >= balance.fitGambitTrust - 25
                ? 1
                : 2;
    }
    final modifier = _controllerModifier(signature, controllers);
    return ContextFit.values[(score - modifier).clamp(0, 2)];
  }

  /// Small deterministic modifier from the §11 sliders. Balanced settings give
  /// 0; aligned settings improve fit by 1; mismatched settings worsen fit by 1.
  int _controllerModifier(
    CardSignature signature,
    TherapyControllerSettings controllers,
  ) {
    return switch (signature) {
      CardSignature.breaker => switch (controllers.focus) {
          FocusAxis.workspace => 1,
          FocusAxis.childhood => -1,
          FocusAxis.balanced => 0,
        },
      CardSignature.buffer => switch (controllers.emotionalDelivery) {
          EmotionalDelivery.warm => 1,
          EmotionalDelivery.objective => -1,
          EmotionalDelivery.balanced => 0,
        },
      CardSignature.freeze => switch (controllers.emotionalDelivery) {
          EmotionalDelivery.objective => 1,
          EmotionalDelivery.warm => -1,
          EmotionalDelivery.balanced => 0,
        },
      CardSignature.gambit => switch (controllers.focus) {
          FocusAxis.childhood => 1,
          FocusAxis.workspace => -1,
          FocusAxis.balanced => 0,
        },
    };
  }

  /// Resolves the deterministic effect vector for a card.
  ///
  /// Uses integer draws only. Band width and centre shift with [fit].
  _EffectVector _resolveEffect(
    SeededPrng prng,
    Card card,
    ContextFit fit,
    SimState state,
  ) {
    final (width, centre) = switch (card.type) {
      CardType.disclosing => switch (fit) {
          ContextFit.aligned => (3, -4),
          ContextFit.partial => (5, -2),
          ContextFit.mismatched => (7, 0),
        },
      CardType.relatable => switch (fit) {
          ContextFit.aligned => (3, 3),
          ContextFit.partial => (5, 1),
          ContextFit.mismatched => (7, -1),
        },
      CardType.postponing => switch (fit) {
          ContextFit.aligned => (2, -3),
          ContextFit.partial => (4, -1),
          ContextFit.mismatched => (6, 1),
        },
      CardType.manipulative => _manipulativeBand(state, fit),
    };

    final roll = width == 0 ? 0 : prng.nextInt(width) - (width ~/ 2);

    return switch (card.type) {
      CardType.disclosing => _EffectVector(
          resistanceDelta: centre + roll,
          trustDelta: -(centre ~/ 2) + (roll ~/ 2),
        ),
      CardType.relatable => _EffectVector(
          trustDelta: centre + roll,
        ),
      CardType.postponing => _EffectVector(
          agitationDelta: centre + roll,
          freezeTurnsSet: balance.postponingFreezeTurns,
        ),
      CardType.manipulative => _manipulativeVector(prng, state, fit),
    };
  }

  (int width, int centre) _manipulativeBand(SimState state, ContextFit fit) {
    final trust = state.trustScore;
    if (trust >= balance.manipulativeSuccessTrust) {
      return switch (fit) {
        ContextFit.aligned => (3, -5),
        ContextFit.partial => (5, -3),
        ContextFit.mismatched => (7, -1),
      };
    } else if (trust >= balance.manipulativePartialTrust) {
      return switch (fit) {
        ContextFit.aligned => (5, -2),
        ContextFit.partial => (5, 0),
        ContextFit.mismatched => (7, 2),
      };
    } else {
      return switch (fit) {
        ContextFit.aligned => (5, 2),
        ContextFit.partial => (7, 4),
        ContextFit.mismatched => (9, 6),
      };
    }
  }

  _EffectVector _manipulativeVector(
    SeededPrng prng,
    SimState state,
    ContextFit fit,
  ) {
    final trust = state.trustScore;
    final (width, centre) = _manipulativeBand(state, fit);
    final roll = width == 0 ? 0 : prng.nextInt(width) - (width ~/ 2);

    if (trust >= balance.manipulativeSuccessTrust) {
      return _EffectVector(
        resistanceDelta: centre + roll,
        trustDelta: 2 + (roll ~/ 3),
      );
    } else if (trust >= balance.manipulativePartialTrust) {
      return _EffectVector(
        resistanceDelta: (centre ~/ 2) + roll,
        agitationDelta: 3 + (roll ~/ 2),
      );
    } else {
      return _EffectVector(
        agitationDelta: centre + roll,
        traumaDelta: 2 + (roll ~/ 2),
      );
    }
  }

  SimState _applyEffect(
    SimState state,
    _EffectVector effect,
    Card effectiveCard,
    ContextFit fit,
    String rulesetVersion,
    void Function(StructuredDelta delta) emit,
  ) {
    var next = state;

    // Trust.
    if (effect.trustDelta != 0) {
      final nextTrust = _clamp(next.trustScore + effect.trustDelta);
      final delta = nextTrust - next.trustScore;
      next = next.copyWith(trustScore: nextTrust);
      emit(StructuredDelta(
        rulesetVersion: rulesetVersion,
        axis: StateAxis.trust,
        deltaMillis: delta,
        reasonKey: 'deltas.${effectiveCard.id}.trust',
        cardType: effectiveCard.type,
        cardSignature: effectiveCard.signature,
        contextFit: fit,
      ));
    }

    // Agitation.
    if (effect.agitationDelta != 0) {
      final nextAgitation = _clamp(next.agitationLevel + effect.agitationDelta);
      final delta = nextAgitation - next.agitationLevel;
      next = next.copyWith(agitationLevel: nextAgitation);
      emit(StructuredDelta(
        rulesetVersion: rulesetVersion,
        axis: StateAxis.agitation,
        deltaMillis: delta,
        reasonKey: 'deltas.${effectiveCard.id}.agitation',
        cardType: effectiveCard.type,
        cardSignature: effectiveCard.signature,
        contextFit: fit,
      ));
    }

    // Resistance / active defense.
    if (effect.resistanceDelta != 0) {
      final newResistance = _clamp(next.resistance + effect.resistanceDelta);
      final newDefense = _defenseFromResistance(newResistance);
      final delta = newDefense.index - next.activeDefense.index;
      next = next.copyWith(activeDefense: newDefense);
      if (delta != 0) {
        emit(StructuredDelta(
          rulesetVersion: rulesetVersion,
          axis: StateAxis.activeDefense,
          deltaMillis: delta,
          reasonKey: 'deltas.${effectiveCard.id}.defense',
          cardType: effectiveCard.type,
          cardSignature: effectiveCard.signature,
          contextFit: fit,
        ));
      }
    }

    // Trauma.
    if (effect.traumaDelta != 0) {
      final nextTrauma = _clamp(next.trauma + effect.traumaDelta);
      final delta = nextTrauma - next.trauma;
      next = next.copyWith(trauma: nextTrauma);
      emit(StructuredDelta(
        rulesetVersion: rulesetVersion,
        axis: StateAxis.trauma,
        deltaMillis: delta,
        reasonKey: 'deltas.${effectiveCard.id}.trauma',
        cardType: effectiveCard.type,
        cardSignature: effectiveCard.signature,
        contextFit: fit,
      ));
    }

    // Freeze turns (Postponing sets, never increments).
    if (effect.freezeTurnsSet != null && effect.freezeTurnsSet! > 0) {
      final nextFreeze = effect.freezeTurnsSet!;
      final delta = nextFreeze - next.freezeTurns;
      next = next.copyWith(freezeTurns: nextFreeze);
      emit(StructuredDelta(
        rulesetVersion: rulesetVersion,
        axis: StateAxis.freezeTurns,
        deltaMillis: delta,
        reasonKey: 'deltas.${effectiveCard.id}.freeze',
        cardType: effectiveCard.type,
        cardSignature: effectiveCard.signature,
        contextFit: fit,
      ));
    }

    return next;
  }

  SimState _applyMedication(
    SimState state,
    Card effectiveCard,
    ContextFit fit,
    String rulesetVersion,
    void Function(StructuredDelta delta) emit,
  ) {
    final medication = state.medication;
    if (medication.drug == null || medication.dosage <= 0) {
      return state;
    }

    // Side-effect: medication raises case pressure (agitation) by a bounded,
    // deterministic amount. The *voice* filter is prompt-only; this is the
    // mechanical pressure/pacing shift documented in C-11 §7.
    final nextAgitation = _clamp(
      state.agitationLevel +
          balance.medicationAgitationShift +
          (medication.tolerance ~/ 10),
    );
    var next = state.copyWith(agitationLevel: nextAgitation);

    // Tolerance and dependency accrue per dose.
    final nextTolerance =
        _clamp(medication.tolerance + balance.tolerancePerDose);
    final nextDependency =
        _clamp(medication.dependency + balance.dependencyPerDose);
    next = next.copyWith(
      medication: medication.copyWith(
        tolerance: nextTolerance,
        dependency: nextDependency,
      ),
    );

    emit(StructuredDelta(
      rulesetVersion: rulesetVersion,
      axis: StateAxis.agitation,
      deltaMillis: nextAgitation - state.agitationLevel,
      reasonKey: 'deltas.medication.${medication.drug!.name}.pressure',
      cardType: effectiveCard.type,
      cardSignature: effectiveCard.signature,
      contextFit: fit,
    ));
    emit(StructuredDelta(
      rulesetVersion: rulesetVersion,
      axis: StateAxis.medicationTolerance,
      deltaMillis: nextTolerance - medication.tolerance,
      reasonKey: 'deltas.medication.${medication.drug!.name}.tolerance',
      cardType: effectiveCard.type,
      cardSignature: effectiveCard.signature,
      contextFit: fit,
    ));
    emit(StructuredDelta(
      rulesetVersion: rulesetVersion,
      axis: StateAxis.medicationDependency,
      deltaMillis: nextDependency - medication.dependency,
      reasonKey: 'deltas.medication.${medication.drug!.name}.dependency',
      cardType: effectiveCard.type,
      cardSignature: effectiveCard.signature,
      contextFit: fit,
    ));

    return next;
  }

  SessionOutcome _classifyOutcome(SimState state) {
    if (state.agitationLevel >= balance.walkoutThreshold) {
      return SessionOutcome.fail;
    }
    if (state.agitationLevel >= balance.crisisThreshold) {
      return SessionOutcome.crisis;
    }
    if (state.sessionProgress >= balance.successProgressThreshold) {
      return SessionOutcome.succeed;
    }
    if (state.agitationLevel <= balance.calmThreshold &&
        state.trustScore >= balance.stableTrustFloor) {
      return SessionOutcome.stabilize;
    }
    return SessionOutcome.ongoing;
  }

  CaseLifecycle _nextLifecycle(CaseLifecycle previous, SessionOutcome outcome) {
    switch (outcome) {
      case SessionOutcome.succeed:
        return CaseLifecycle.cured;
      case SessionOutcome.fail:
        return CaseLifecycle.hardFailed;
      case SessionOutcome.crisis:
        return CaseLifecycle.crisis;
      case SessionOutcome.stabilize:
      case SessionOutcome.ongoing:
        if (previous == CaseLifecycle.open) return CaseLifecycle.inTreatment;
        if (previous == CaseLifecycle.crisis) return CaseLifecycle.inTreatment;
        return previous;
    }
  }

  static int _clamp(int value, {int min = 0, int max = 100}) =>
      value.clamp(min, max);

  static DefenseState _defenseFromResistance(int resistance) {
    if (resistance >= 70) return DefenseState.rigid;
    if (resistance >= 35) return DefenseState.guarded;
    return DefenseState.none;
  }
}

/// Mutable, internal effect accumulator for a single card play.
class _EffectVector {
  final int trustDelta;
  final int agitationDelta;
  final int resistanceDelta;
  final int traumaDelta;
  final int? freezeTurnsSet;

  const _EffectVector({
    this.trustDelta = 0,
    this.agitationDelta = 0,
    this.resistanceDelta = 0,
    this.traumaDelta = 0,
    this.freezeTurnsSet,
  });
}
