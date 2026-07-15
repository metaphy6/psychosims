import 'canonical_json.dart';
import 'medication_state.dart';
import 'structured_delta.dart';

/// A bounded, enumerated mutation from the derangement catalogue (§16).
///
/// Never free text; stored as a typed token so it remains injection-safe and
/// bound-checkable by the receipt validator.
enum DerangementMutation {
  /// Somatic fixation: agitation baseline raised.
  somaticFixation,

  /// Trust collapse: starting trust reduced across sessions.
  trustCollapse,

  /// Resistance crystallisation: defense starts higher.
  resistanceCrystallisation,
}

extension DerangementMutationJson on DerangementMutation {
  String toJson() => name;
  static DerangementMutation fromJson(String value) =>
      DerangementMutation.values.byName(value);
}

/// Persistent state carried across sessions for a [MemoryClass.persistent] case.
///
/// Contains only bounded, enumerated, typed deltas — no transcripts, no free
/// text — so the multi-session digest stays injection-safe and budget-bound.
class CaseHistoryEnvelope {
  /// Deltas from prior sessions that modify the starting state.
  final List<StructuredDelta> carryOverDeltas;

  /// Accumulated medication history (drug, tolerance, dependency).
  final MedicationState inheritedMedication;

  /// Bounded derangement catalogue entries applied to this case.
  final List<DerangementMutation> derangements;

  /// Collected clue tokens from prior sessions.
  final List<String> collectedClues;

  /// Count of completed prior sessions.
  final int priorSessionCount;

  /// Accumulated baseline agitation climb from repeated Postponing plays (§16).
  ///
  /// Added to the patient's starting agitation in subsequent sessions; bounded
  /// so the carry-over stays budget-safe. Zero for cases that never postponed.
  final int postponingDecay;

  const CaseHistoryEnvelope({
    this.carryOverDeltas = const [],
    this.inheritedMedication = const MedicationState.empty(),
    this.derangements = const [],
    this.collectedClues = const [],
    this.priorSessionCount = 0,
    this.postponingDecay = 0,
  });

  /// The canonical empty envelope used by stateless cases.
  static const empty = CaseHistoryEnvelope();

  CaseHistoryEnvelope copyWith({
    List<StructuredDelta>? carryOverDeltas,
    MedicationState? inheritedMedication,
    List<DerangementMutation>? derangements,
    List<String>? collectedClues,
    int? priorSessionCount,
    int? postponingDecay,
  }) {
    return CaseHistoryEnvelope(
      carryOverDeltas: carryOverDeltas ?? this.carryOverDeltas,
      inheritedMedication: inheritedMedication ?? this.inheritedMedication,
      derangements: derangements ?? this.derangements,
      collectedClues: collectedClues ?? this.collectedClues,
      priorSessionCount: priorSessionCount ?? this.priorSessionCount,
      postponingDecay: postponingDecay ?? this.postponingDecay,
    );
  }

  /// Adds a collected clue if not already present.
  CaseHistoryEnvelope withClue(String clue) {
    if (collectedClues.contains(clue)) return this;
    return copyWith(
      collectedClues: [...collectedClues, clue],
    );
  }

  /// Adds a derangement mutation if not already present.
  CaseHistoryEnvelope withDerangement(DerangementMutation mutation) {
    if (derangements.contains(mutation)) return this;
    return copyWith(
      derangements: [...derangements, mutation],
    );
  }

  Map<String, Object?> toJson() => {
        'carry_over_deltas': carryOverDeltas.map((d) => d.toJson()).toList(),
        'inherited_medication': inheritedMedication.toJson(),
        'derangements': derangements.map((d) => d.toJson()).toList(),
        'collected_clues': collectedClues.toList(),
        'prior_session_count': priorSessionCount,
        'postponing_decay': postponingDecay,
      };

  factory CaseHistoryEnvelope.fromJson(Map<String, Object?> json) {
    return CaseHistoryEnvelope(
      carryOverDeltas: (json['carry_over_deltas']! as List<dynamic>)
          .cast<Map<String, Object?>>()
          .map(StructuredDelta.fromJson)
          .toList(),
      inheritedMedication: MedicationState.fromJson(
          json['inherited_medication']! as Map<String, Object?>),
      derangements: (json['derangements']! as List<dynamic>)
          .cast<String>()
          .map(DerangementMutationJson.fromJson)
          .toList(),
      collectedClues:
          (json['collected_clues']! as List<dynamic>).cast<String>().toList(),
      priorSessionCount: json['prior_session_count']! as int,
      // Wire-compat: envelopes serialized before this field default to zero.
      postponingDecay: (json['postponing_decay'] as int?) ?? 0,
    );
  }

  List<int> toCanonicalBytes() => CanonicalJson.encode(toJson());

  @override
  bool operator ==(Object other) =>
      other is CaseHistoryEnvelope &&
      _listEq(other.carryOverDeltas, carryOverDeltas) &&
      other.inheritedMedication == inheritedMedication &&
      _listEq(other.derangements, derangements) &&
      _listEq(other.collectedClues, collectedClues) &&
      other.priorSessionCount == priorSessionCount &&
      other.postponingDecay == postponingDecay;

  @override
  int get hashCode => Object.hash(
        Object.hashAll(carryOverDeltas),
        inheritedMedication,
        Object.hashAll(derangements),
        Object.hashAll(collectedClues),
        priorSessionCount,
        postponingDecay,
      );

  static bool _listEq<T>(List<T> a, List<T> b) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }
}
