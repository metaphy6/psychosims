import 'dart:collection';

import 'package:psychemas/psychemas.dart';

import 'card_balance.dart';
import 'clock.dart';
import 'sim_state.dart';
import 'turn_input.dart';
import 'turn_resolver.dart';

enum SolvabilityStatus {
  solved,
  noSolutionWithinBounds,
  budgetExceeded,
  invalid
}

/// A successful result contains actions that replay through the actual core.
/// Unsuccessful bounded search is not a claim of universal impossibility.
class SolvabilityResult {
  final SolvabilityStatus status;
  final List<InteractionPattern> actions;
  final SimState? finalState;
  final int exploredTransitions;

  SolvabilityResult._(this.status, this.exploredTransitions,
      [List<InteractionPattern> actions = const [], this.finalState])
      : actions = List.unmodifiable(actions);

  bool get solved => status == SolvabilityStatus.solved;
}

/// Bounded deterministic gameplay search for one manifest, seed and loadout.
/// Uses the production resolver with injected time; never an inference model.
class SolvabilityOracle {
  final CardBalance balance;
  final int maxTurns;
  final int maxTransitions;

  const SolvabilityOracle({
    this.balance = const CardBalance(),
    this.maxTurns = 120,
    this.maxTransitions = 20000,
  });

  /// Fail closed unless a complete winning path has actually been found.
  bool isSolvable(PatientManifest manifest) => analyze(manifest).solved;

  SolvabilityResult analyze(
    PatientManifest manifest, {
    int rootSeed = 42,
    Loadout? loadout,
    CardLibrary? library,
    SimState? startState,
    TherapyControllerSettings controllers = const TherapyControllerSettings(),
  }) {
    if (maxTurns <= 0 || maxTransitions <= 0) {
      throw ArgumentError('Solvability search budgets must be positive');
    }
    final cards = manifest.resolvedCards.map((card) => card.id).toSet();
    final equipped = loadout ??
        Loadout(
            cardIds: cards.toList()..sort(), slotCap: balance.activeCardSlots);
    final owned = library ?? CardLibrary(ownedCardIds: cards);
    if (!equipped.isValidForLibrary(owned.ownedCardIds) ||
        equipped.cardIds.length > balance.activeCardSlots) {
      return SolvabilityResult._(SolvabilityStatus.invalid, 0);
    }
    final legal = manifest.interactionPatterns
        .where((action) =>
            equipped.contains(cardFromInteractionPattern(action).id))
        .toSet()
        .toList()
      ..sort((a, b) => a.name.compareTo(b.name));
    if (legal.isEmpty) {
      return SolvabilityResult._(SolvabilityStatus.invalid, 0);
    }
    final resolver =
        TurnResolver(const InjectedClock.replay(0), balance: balance);
    final initial = startState ??
        SimState.fromInitialState(rootSeed, manifest.initialState);
    final root = _SearchNode(initial, null, null, 0);
    var explored = 0;

    // Cheap deterministic policies often produce a witness without expanding
    // a search tree. Every attempted transition still consumes the budget.
    for (final action in legal) {
      var node = root;
      for (var turn = 0; turn < maxTurns; turn++) {
        if (explored >= maxTransitions) {
          return SolvabilityResult._(
              SolvabilityStatus.budgetExceeded, explored);
        }
        final output = resolver.resolve(TurnInput(
          rulesetVersion: manifest.rulesetVersion,
          manifest: manifest,
          state: node.state,
          action: action,
          loadout: equipped,
          library: owned,
          controllers: controllers,
        ));
        explored++;
        node = _SearchNode(output.nextState, node, action, node.depth + 1);
        if (output.outcome == SessionOutcome.succeed) {
          return SolvabilityResult._(
              SolvabilityStatus.solved, explored, node.actions(), node.state);
        }
        if (output.isTerminal) break;
      }
    }

    final queue = ListQueue<_SearchNode>()..add(root);
    final seen = <SimState>{initial};
    while (queue.isNotEmpty) {
      final node = queue.removeFirst();
      if (node.depth >= maxTurns) continue;
      for (final action in legal) {
        if (explored >= maxTransitions) {
          return SolvabilityResult._(
              SolvabilityStatus.budgetExceeded, explored);
        }
        final output = resolver.resolve(TurnInput(
          rulesetVersion: manifest.rulesetVersion,
          manifest: manifest,
          state: node.state,
          action: action,
          loadout: equipped,
          library: owned,
          controllers: controllers,
        ));
        explored++;
        final next =
            _SearchNode(output.nextState, node, action, node.depth + 1);
        if (output.outcome == SessionOutcome.succeed) {
          return SolvabilityResult._(
              SolvabilityStatus.solved, explored, next.actions(), next.state);
        }
        if (!output.isTerminal && seen.add(next.state)) queue.add(next);
      }
    }
    return SolvabilityResult._(
        SolvabilityStatus.noSolutionWithinBounds, explored);
  }

  /// Verifies the manifest passes content-integrity lint: no real labels and
  /// only fictional-taxonomy terms. This oracle only checks structural tokens;
  /// the CI lint enforces the string-level rules.
  bool isContentCompliant(PatientManifest manifest) {
    return manifest.clueTokens.every((token) => !_containsRealLabel(token));
  }

  static bool _containsRealLabel(String token) {
    // Structural guard; CI runs the authoritative regex list on raw files.
    final forbidden = RegExp(
      r'\b(depression|schizophrenia|bipolar|ptsd|ocd|adhd|autism|dementia|alzheimer|parkinson|anxiety disorder|personality disorder|prozac|zoloft|xanax|lexapro|abilify|adderall|ritalin|valium|klonopin|paxil|celexa|cymbalta|effexor|wellbutrin|dsm[- ]?5|dsm[- ]?v|icd[- ]?10|icd[- ]?11)\b',
      caseSensitive: false,
    );
    return forbidden.hasMatch(token);
  }
}

class _SearchNode {
  final SimState state;
  final _SearchNode? parent;
  final InteractionPattern? action;
  final int depth;

  const _SearchNode(this.state, this.parent, this.action, this.depth);

  List<InteractionPattern> actions() {
    final reversed = <InteractionPattern>[];
    for (_SearchNode? node = this; node?.action != null; node = node.parent) {
      reversed.add(node!.action!);
    }
    return reversed.reversed.toList();
  }
}
