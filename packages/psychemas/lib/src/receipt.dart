/// Server-validated session receipt schema.
class SessionReceipt {
  final String id;
  final String schemaVersion;
  final String rulesetVersion;
  final String patientId;
  final int turnCount;
  final List<Map<String, Object?>> deltas;

  static const String currentSchemaVersion = '0.1.0';

  const SessionReceipt({
    required this.id,
    this.schemaVersion = currentSchemaVersion,
    required this.rulesetVersion,
    required this.patientId,
    required this.turnCount,
    required this.deltas,
  });

  Map<String, Object?> toJson() => {
        'id': id,
        'schemaVersion': schemaVersion,
        'rulesetVersion': rulesetVersion,
        'patientId': patientId,
        'turnCount': turnCount,
        'deltas': deltas,
      };

  factory SessionReceipt.fromJson(Map<String, Object?> json) {
    return SessionReceipt(
      id: json['id']! as String,
      schemaVersion: json['schemaVersion']! as String,
      rulesetVersion: json['rulesetVersion']! as String,
      patientId: json['patientId']! as String,
      turnCount: json['turnCount']! as int,
      deltas: (json['deltas']! as List<dynamic>)
          .cast<Map<String, Object?>>()
          .toList(),
    );
  }
}
