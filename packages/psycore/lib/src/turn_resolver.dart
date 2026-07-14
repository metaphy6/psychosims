import 'package:psychemas/psychemas.dart';

import 'card_balance.dart';
import 'clock.dart';
import 'prng.dart';
import 'ruleset_profile.dart';
import 'seed_derivation.dart';
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
    final defaultCard = cardFromInteractionPattern(input.action);
    final card = input.manifest.resolvedCards.firstWhere(
      (c) => c.id == defaultCard.id,
      orElse: () => defaultCard,
    );
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

    final effectiveCard = _resolveEffectiveCard(card, input.state.axes);
    final fit = _computeContextFit(effectiveCard.signature, input.state.axes);

    final nextAxes = Map<String, int>.of(input.state.axes);
    final deltas = <StructuredDelta>[];

    // Ensure every axis we mutate exists; missing axes default to 0.
    final touchedAxes = _resolveEffect(prng, effectiveCard, fit, nextAxes);
    for (final axis in touchedAxes.keys.toList()..sort()) {
      final delta = touchedAxes[axis]!;
      final current = nextAxes.putIfAbsent(axis, () => 0);
      nextAxes[axis] = (current + delta).clamp(0, 100);
      deltas.add(StructuredDelta(
        rulesetVersion: input.rulesetVersion,
        axis: axis,
        deltaMillis: delta,
        reasonKey: 'deltas.${effectiveCard.id}.$axis',
        cardType: effectiveCard.type,
        cardSignature: effectiveCard.signature,
        contextFit: fit,
      ));
    }

    // Decrement any active freeze counter.
    if (nextAxes.containsKey('freeze_turns') && nextAxes['freeze_turns']! > 0) {
      nextAxes['freeze_turns'] = nextAxes['freeze_turns']! - 1;
    }

    final nextState = input.state.copyWith(
      turn: input.state.turn + 1,
      axes: nextAxes,
    );

    return TurnOutput(
      nextState: nextState,
      deltas: deltas,
      requiredClueTokens: input.manifest.clueTokens,
    );
  }

  /// Applies the Transference Spike reclassification (§16): in a high-trauma
  /// state, Relatable plays resolve as Manipulative failures.
  Card _resolveEffectiveCard(Card card, Map<String, int> axes) {
    final trauma = axes['trauma'] ?? 0;
    final agitation = axes['agitation'] ?? 0;
    if (card.type == CardType.relatable &&
        trauma >= balance.transferenceSpikeTrauma &&
        agitation >= balance.transferenceSpikeAgitation) {
      return card.copyWith(
        type: CardType.manipulative,
        signature: CardSignature.gambit,
      );
    }
    return card;
  }

  /// Computes context-fit from signature + current state.
  ///
  /// Cut-points are illustrative placeholders; final values live in C-4.
  ContextFit _computeContextFit(
      CardSignature signature, Map<String, int> axes) {
    final trust = axes['trust'] ?? 0;
    final agitation = axes['agitation'] ?? 0;
    final resistance = axes['resistance'] ?? 0;

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
    return ContextFit.values[score];
  }

  /// Resolves the deterministic effect vector for a card.
  ///
  /// Uses integer draws only. Band width and centre shift with [fit].
  Map<String, int> _resolveEffect(
    SeededPrng prng,
    Card card,
    ContextFit fit,
    Map<String, int> axes,
  ) {
    // Band parameters: width shrinks and centre shifts favourably when aligned.
    // Values are placeholder shapes; exact numbers are C-4 tuned in 2.8.
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
      CardType.manipulative => _manipulativeBand(prng, axes, fit),
    };

    final roll = width == 0 ? 0 : prng.nextInt(width) - (width ~/ 2);

    return switch (card.type) {
      CardType.disclosing => {
          'resistance': centre + roll,
          'trust': -(centre ~/ 2) + (roll ~/ 2),
        },
      CardType.relatable => {
          'trust': centre + roll,
        },
      CardType.postponing => {
          'agitation': centre + roll,
          'freeze_turns': balance.postponingFreezeTurns,
        },
      CardType.manipulative => _manipulativeDeltas(prng, axes, fit),
    };
  }

  (int width, int centre) _manipulativeBand(
    SeededPrng prng,
    Map<String, int> axes,
    ContextFit fit,
  ) {
    final trust = axes['trust'] ?? 0;
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

  Map<String, int> _manipulativeDeltas(
    SeededPrng prng,
    Map<String, int> axes,
    ContextFit fit,
  ) {
    final trust = axes['trust'] ?? 0;
    final (width, centre) = _manipulativeBand(prng, axes, fit);
    final roll = width == 0 ? 0 : prng.nextInt(width) - (width ~/ 2);

    if (trust >= balance.manipulativeSuccessTrust) {
      // Success: shatter defense, unlock insight.
      return {
        'resistance': centre + roll,
        'trust': 2 + (roll ~/ 3),
      };
    } else if (trust >= balance.manipulativePartialTrust) {
      // Partial: expose vulnerability, patient more unstable.
      return {
        'resistance': (centre ~/ 2) + roll,
        'agitation': 3 + (roll ~/ 2),
      };
    } else {
      // Derangement: enumerated secondary-pathology state.
      return {
        'agitation': centre + roll,
        'trauma': 2 + (roll ~/ 2),
      };
    }
  }
}
