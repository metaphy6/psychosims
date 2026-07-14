import 'package:psychemas/psychemas.dart';

/// Immutable, typed patient simulation state.
///
/// The deterministic core owns this state. It carries only bounded integers,
/// typed enums, and the medication record so outcomes replay byte-identically
/// across platforms (0.8 determinism contract). No floats, no wall-clock, no
/// ambient randomness here.
class SimState {
  final int seed;
  final int turn;

  /// Therapeutic alliance / rapport, 0–100.
  final int trustScore;

  /// Current agitation / pressure, 0–100.
  final int agitationLevel;

  /// Active defense posture.
  final DefenseState activeDefense;

  /// Accrued trauma, 0–100.
  final int trauma;

  /// Turns remaining where the patient is frozen (Postponing effect), ≥0.
  final int freezeTurns;

  /// Progress toward session resolution, 0–100.
  final int sessionProgress;

  /// Fictional pharmacology state.
  final MedicationState medication;

  const SimState({
    required this.seed,
    this.turn = 0,
    this.trustScore = 0,
    this.agitationLevel = 0,
    this.activeDefense = DefenseState.none,
    this.trauma = 0,
    this.freezeTurns = 0,
    this.sessionProgress = 0,
    this.medication = const MedicationState.empty(),
  });

  /// Builds a typed state from the manifest's legacy `Map<String,int> initialState`.
  ///
  /// This preserves 0.8 wire compatibility with PoC content while the core
  /// moves to typed fields. Unknown keys are ignored; missing keys default to 0.
  factory SimState.fromInitialState(int seed, Map<String, int> initialState) {
    return SimState(
      seed: seed,
      trustScore: initialState['trust'] ?? 0,
      agitationLevel: initialState['agitation'] ?? 0,
      activeDefense: _defenseFromResistance(initialState['resistance'] ?? 0),
      trauma: initialState['trauma'] ?? 0,
      freezeTurns: initialState['freeze_turns'] ?? 0,
      sessionProgress: initialState['session_progress'] ?? 0,
    );
  }

  static DefenseState _defenseFromResistance(int resistance) {
    if (resistance >= 70) return DefenseState.rigid;
    if (resistance >= 35) return DefenseState.guarded;
    return DefenseState.none;
  }

  SimState copyWith({
    int? turn,
    int? trustScore,
    int? agitationLevel,
    DefenseState? activeDefense,
    int? trauma,
    int? freezeTurns,
    int? sessionProgress,
    MedicationState? medication,
  }) {
    return SimState(
      seed: seed,
      turn: turn ?? this.turn,
      trustScore: trustScore ?? this.trustScore,
      agitationLevel: agitationLevel ?? this.agitationLevel,
      activeDefense: activeDefense ?? this.activeDefense,
      trauma: trauma ?? this.trauma,
      freezeTurns: freezeTurns ?? this.freezeTurns,
      sessionProgress: sessionProgress ?? this.sessionProgress,
      medication: medication ?? this.medication,
    );
  }

  /// Derived resistance value from the typed defense posture (0 = none,
  /// 35 = guarded, 70 = rigid) so the old PoC `resistance` axis still has a
  /// deterministic meaning during the 2.3 migration.
  int get resistance => activeDefense.index * 35;

  /// Backward-compatible axis read for the PoC map shape.
  ///
  /// Used during the 2.3 migration so existing content and tests that speak
  /// the old axis vocabulary still compile while the core moves to typed
  /// fields.
  int axis(String name) {
    return switch (name) {
      'trust' => trustScore,
      'agitation' => agitationLevel,
      'resistance' => activeDefense.index * 35,
      'trauma' => trauma,
      'freeze_turns' => freezeTurns,
      'session_progress' => sessionProgress,
      _ => 0,
    };
  }

  /// Returns a deterministic snapshot suitable for serialization/receipts.
  Map<String, Object?> toJson() => {
        'seed': seed,
        'turn': turn,
        'trust_score': trustScore,
        'agitation_level': agitationLevel,
        'active_defense': activeDefense.toJson(),
        'trauma': trauma,
        'freeze_turns': freezeTurns,
        'session_progress': sessionProgress,
        'medication': medication.toJson(),
      };

  factory SimState.fromJson(Map<String, Object?> json) {
    return SimState(
      seed: json['seed']! as int,
      turn: json['turn']! as int,
      trustScore: (json['trust_score'] ?? json['trust'] ?? 0) as int,
      agitationLevel:
          (json['agitation_level'] ?? json['agitation'] ?? 0) as int,
      activeDefense: json['active_defense'] == null
          ? DefenseState.none
          : DefenseStateJson.fromJson(json['active_defense']! as String),
      trauma: (json['trauma'] ?? 0) as int,
      freezeTurns: (json['freeze_turns'] ?? 0) as int,
      sessionProgress: (json['session_progress'] ?? 0) as int,
      medication: json['medication'] == null
          ? const MedicationState.empty()
          : MedicationState.fromJson(
              json['medication']! as Map<String, Object?>),
    );
  }

  /// Encodes this state to canonical UTF-8 bytes.
  List<int> toCanonicalBytes() => CanonicalJson.encode(toJson());

  @override
  bool operator ==(Object other) =>
      other is SimState &&
      other.seed == seed &&
      other.turn == turn &&
      other.trustScore == trustScore &&
      other.agitationLevel == agitationLevel &&
      other.activeDefense == activeDefense &&
      other.trauma == trauma &&
      other.freezeTurns == freezeTurns &&
      other.sessionProgress == sessionProgress &&
      other.medication == medication;

  @override
  int get hashCode => Object.hash(
        seed,
        turn,
        trustScore,
        agitationLevel,
        activeDefense,
        trauma,
        freezeTurns,
        sessionProgress,
        medication,
      );
}
