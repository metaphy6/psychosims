import 'canonical_json.dart';

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
  final List<Map<String, Object?>> actions;
  final List<Map<String, Object?>> deltas;

  static const String currentSchemaVersion = '0.2.0';

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
        'actions': actions,
        'deltas': deltas,
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
          .cast<Map<String, Object?>>()
          .toList(),
      deltas: (json['deltas']! as List<dynamic>)
          .cast<Map<String, Object?>>()
          .toList(),
    );
  }

  /// Encodes this receipt to canonical UTF-8 bytes.
  List<int> toCanonicalBytes() => CanonicalJson.encode(toJson());
}
