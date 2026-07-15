import 'package:psychemas/psychemas.dart';

import 'sim_state.dart';
import 'turn_output.dart';

/// Applies and updates multi-session carry-over state for persistent cases.
///
/// All rules are deterministic and operate on bounded, enumerated data only.
class MultiSessionResolver {
  const MultiSessionResolver();

  /// Returns the envelope a case should begin with.
  ///
  /// Stateless / social-chronic cases carry no history envelope and never
  /// accumulate carry-over (1.2 memory_class discipline, §17 ledger rule).
  CaseHistoryEnvelope envelopeForCase(MemoryClass memoryClass) {
    return memoryClass == MemoryClass.persistent
        ? const CaseHistoryEnvelope()
        : CaseHistoryEnvelope.empty;
  }

  /// Builds the starting [SimState] for a new session of a persistent case.
  ///
  /// Applies derangement mutations, inherited medication, and carry-over deltas
  /// from the history envelope onto the manifest's initial state.
  SimState startingState({
    required Map<String, int> initialState,
    required int rootSeed,
    required CaseHistoryEnvelope envelope,
  }) {
    var state = SimState.fromInitialState(rootSeed, initialState);

    // Apply derangement baseline shifts.
    for (final mutation in envelope.derangements) {
      state = _applyDerangement(state, mutation);
    }

    // Apply inherited medication.
    state = state.copyWith(
      medication: envelope.inheritedMedication,
    );

    // Apply carry-over deltas (bounded integers only).
    for (final delta in envelope.carryOverDeltas) {
      state = _applyDelta(state, delta);
    }

    // Apply accumulated Postponing decay to the starting agitation baseline
    // (§16): repeated Postponing across sessions makes the patient increasingly
    // impatient at daily check-ups.
    if (envelope.postponingDecay != 0) {
      state = state.copyWith(
        agitationLevel:
            (state.agitationLevel + envelope.postponingDecay).clamp(0, 100),
      );
    }

    return state;
  }

  /// Collects clues produced by a session's turn outputs.
  Set<String> collectClues(
    List<TurnOutput> outputs,
    List<String> manifestClueTokens,
  ) {
    final collected = <String>{};
    for (final output in outputs) {
      for (final clue in output.requiredClueTokens) {
        if (manifestClueTokens.contains(clue)) {
          collected.add(clue);
        }
      }
    }
    return collected;
  }

  /// Builds the history envelope for the next session.
  ///
  /// Persists medication state, collected clues, bounded carry-over deltas, and
  /// derangement mutations. Only deltas that are intended to persist across
  /// sessions are included; transient turn-to-turn deltas are filtered out.
  ///
  /// Stateless cases always return [CaseHistoryEnvelope.empty] regardless of
  /// inputs, preserving the memory_class discipline.
  CaseHistoryEnvelope buildNextEnvelope({
    required MemoryClass memoryClass,
    required CaseHistoryEnvelope previous,
    required List<TurnOutput> sessionOutputs,
    required List<String> manifestClueTokens,
    int manipulativePartialTrust = 40,
    int postponingDecayPerSession = 3,
    int maxPostponingDecay = 40,
  }) {
    if (memoryClass == MemoryClass.stateless) {
      return CaseHistoryEnvelope.empty;
    }

    final nextSessionCount = previous.priorSessionCount + 1;

    // Collect clues discovered this session.
    var envelope = previous;
    final newClues = collectClues(sessionOutputs, manifestClueTokens);
    for (final clue in newClues) {
      envelope = envelope.withClue(clue);
    }

    // Persist terminal medication state if any medication was prescribed.
    if (sessionOutputs.isNotEmpty) {
      final terminal = sessionOutputs.last.nextState;
      if (terminal.medication.drug != null) {
        envelope = envelope.copyWith(
          inheritedMedication: terminal.medication,
        );
      }
    }

    // Collect persistent deltas: medication tolerance/dependency and trauma.
    final persistentDeltas = <StructuredDelta>[];
    for (final output in sessionOutputs) {
      for (final delta in output.deltas) {
        if (delta.axis == StateAxis.medicationTolerance ||
            delta.axis == StateAxis.medicationDependency ||
            delta.axis == StateAxis.trauma) {
          persistentDeltas.add(delta);
        }
      }
    }

    if (persistentDeltas.isNotEmpty) {
      envelope = envelope.copyWith(
        carryOverDeltas: [...envelope.carryOverDeltas, ...persistentDeltas],
      );
    }

    // Detect derangement triggers: low-trust mismatched Manipulative plays that
    // caused trauma. These become bounded, enumerated mutations for the next
    // session (2.1/2.4 injection-safe carry-over).
    for (final output in sessionOutputs) {
      final hasTrauma = output.deltas.any((d) => d.axis == StateAxis.trauma);
      final isLowTrustManipulative = output.deltas.any(
        (d) =>
            d.cardType == CardType.manipulative &&
            d.contextFit == ContextFit.mismatched,
      );
      if (hasTrauma && isLowTrustManipulative) {
        envelope = envelope.withDerangement(DerangementMutation.trustCollapse);
      }
    }

    // Accrue Postponing multi-session decay (§16): each Postponing play this
    // session raises the patient's baseline starting agitation for subsequent
    // sessions, bounded by [maxPostponingDecay] so cases stay winnable.
    final postponingPlays = sessionOutputs
        .where((o) => o.deltas.any((d) => d.cardType == CardType.postponing))
        .length;
    if (postponingPlays > 0) {
      final accrued = (envelope.postponingDecay +
              postponingPlays * postponingDecayPerSession)
          .clamp(0, maxPostponingDecay);
      envelope = envelope.copyWith(postponingDecay: accrued);
    }

    return envelope.copyWith(
      priorSessionCount: nextSessionCount,
    );
  }

  SimState _applyDerangement(SimState state, DerangementMutation mutation) {
    return switch (mutation) {
      DerangementMutation.somaticFixation => state.copyWith(
          agitationLevel: (state.agitationLevel + 15).clamp(0, 100),
        ),
      DerangementMutation.trustCollapse => state.copyWith(
          trustScore: (state.trustScore - 15).clamp(0, 100),
        ),
      DerangementMutation.resistanceCrystallisation => state.copyWith(
          activeDefense: _hardenDefense(state.activeDefense),
        ),
    };
  }

  DefenseState _hardenDefense(DefenseState defense) {
    return switch (defense) {
      DefenseState.none => DefenseState.guarded,
      DefenseState.guarded => DefenseState.rigid,
      DefenseState.rigid => DefenseState.rigid,
    };
  }

  SimState _applyDelta(SimState state, StructuredDelta delta) {
    // Carry-over deltas store whole state units (the resolver emits whole-unit
    // deltas); the `deltaMillis` name is historical, not a fixed-point scale.
    final value = delta.deltaMillis;
    return switch (delta.axis) {
      StateAxis.trust => state.copyWith(
          trustScore: (state.trustScore + value).clamp(0, 100),
        ),
      StateAxis.agitation => state.copyWith(
          agitationLevel: (state.agitationLevel + value).clamp(0, 100),
        ),
      StateAxis.trauma => state.copyWith(
          trauma: (state.trauma + value).clamp(0, 100),
        ),
      StateAxis.sessionProgress => state.copyWith(
          sessionProgress: (state.sessionProgress + value).clamp(0, 100),
        ),
      _ => state,
    };
  }
}
