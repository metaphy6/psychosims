/// Canonical patient manifest schema.
class PatientManifest {
  final String id;
  final String schemaVersion;
  final String rulesetVersion;
  final String nameKey;
  final String presentationKey;

  static const String currentSchemaVersion = '0.1.0';

  const PatientManifest({
    required this.id,
    this.schemaVersion = currentSchemaVersion,
    required this.rulesetVersion,
    required this.nameKey,
    required this.presentationKey,
  });

  Map<String, Object?> toJson() => {
        'id': id,
        'schemaVersion': schemaVersion,
        'rulesetVersion': rulesetVersion,
        'nameKey': nameKey,
        'presentationKey': presentationKey,
      };

  factory PatientManifest.fromJson(Map<String, Object?> json) {
    return PatientManifest(
      id: json['id']! as String,
      schemaVersion: json['schemaVersion']! as String,
      rulesetVersion: json['rulesetVersion']! as String,
      nameKey: json['nameKey']! as String,
      presentationKey: json['presentationKey']! as String,
    );
  }

  @override
  bool operator ==(Object other) =>
      other is PatientManifest &&
      other.id == id &&
      other.schemaVersion == schemaVersion &&
      other.rulesetVersion == rulesetVersion &&
      other.nameKey == nameKey &&
      other.presentationKey == presentationKey;

  @override
  int get hashCode =>
      Object.hash(id, schemaVersion, rulesetVersion, nameKey, presentationKey);
}
