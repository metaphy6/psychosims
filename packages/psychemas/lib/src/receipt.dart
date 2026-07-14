import 'canonical_json.dart';
import 'interaction_pattern.dart';
import 'structured_delta.dart';

/// Server-validated session receipt schema.
class SessionReceipt {
  final String id;
  final String schemaVersion;
  final String rulesetVersion;
  final String patientId;
  final String idempotencyKey;
  final String correlationId;
  final int turnCount;
  final Map<String, Object?> startState;
  final List<InteractionPattern> actions;
  final List<StructuredDelta> deltas;

  static const String currentSchemaVersion = '0.3.0';

  const SessionReceipt({
    required this.id,
    this.schemaVersion = currentSchemaVersion,
    required this.rulesetVersion,
    required this.patientId,
    required this.idempotencyKey,
    required this.correlationId,
    required this.turnCount,
    required this.startState,
    required this.actions,
    required this.deltas,
  });

  Map<String, Object?> toJson() => {
        'id': id,
        'schema_version': schemaVersion,
        'ruleset_version': rulesetVersion,
        'patient_id': patientId,
        'idempotency_key': idempotencyKey,
        'correlation_id': correlationId,
        'turn_count': turnCount,
        'start_state': startState,
        'actions': actions.map((a) => a.toJson()).toList(),
        'deltas': deltas.map((d) => d.toJson()).toList(),
      };

  factory SessionReceipt.fromJson(Map<String, Object?> json) {
    return SessionReceipt(
      id: json['id']! as String,
      schemaVersion:
          (json['schema_version'] ?? json['schemaVersion'])! as String,
      rulesetVersion:
          (json['ruleset_version'] ?? json['rulesetVersion'])! as String,
      patientId: (json['patient_id'] ?? json['patientId'])! as String,
      idempotencyKey:
          (json['idempotency_key'] ?? json['idempotencyKey'])! as String,
      correlationId:
          (json['correlation_id'] ?? json['correlationId'])! as String,
      turnCount: (json['turn_count'] ?? json['turnCount'])! as int,
      startState:
          (json['start_state'] ?? json['startState'])! as Map<String, Object?>,
      actions: ((json['actions'] ?? json['orderedActions'])! as List<dynamic>)
          .cast<String>()
          .map(InteractionPatternJson.fromJson)
          .toList(),
      deltas: (json['deltas']! as List<dynamic>)
          .cast<Map<String, Object?>>()
          .map(StructuredDelta.fromJson)
          .toList(),
    );
  }

  /// Encodes this receipt to canonical UTF-8 bytes.
  List<int> toCanonicalBytes() => CanonicalJson.encode(toJson());

  @override
  bool operator ==(Object other) =>
      other is SessionReceipt &&
      other.id == id &&
      other.schemaVersion == schemaVersion &&
      other.rulesetVersion == rulesetVersion &&
      other.patientId == patientId &&
      other.idempotencyKey == idempotencyKey &&
      other.correlationId == correlationId &&
      other.turnCount == turnCount &&
      _mapEq(other.startState, startState) &&
      _listEq(other.actions, actions) &&
      _listEq(other.deltas, deltas);

  @override
  int get hashCode => Object.hash(
        id,
        schemaVersion,
        rulesetVersion,
        patientId,
        idempotencyKey,
        correlationId,
        turnCount,
        Object.hashAll(startState.entries),
        Object.hashAll(actions),
        Object.hashAll(deltas),
      );

  static bool _mapEq(Map<String, Object?> a, Map<String, Object?> b) {
    if (a.length != b.length) return false;
    for (final entry in a.entries) {
      if (b[entry.key] != entry.value) return false;
    }
    return true;
  }

  static bool _listEq<T>(List<T> a, List<T> b) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }
}
