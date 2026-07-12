/// A single structured, deterministic state change.
///
/// Carries the [rulesetVersion] that produced it so an outcome remains
/// replayable against the exact rules that created it (local precursor to the
/// Phase 3.3 receipt shape).
class StructuredDelta {
  final String rulesetVersion;
  final String axis;
  final int deltaMillis;
  final String reasonKey;

  const StructuredDelta({
    required this.rulesetVersion,
    required this.axis,
    required this.deltaMillis,
    required this.reasonKey,
  });

  Map<String, Object?> toJson() => {
        'ruleset_version': rulesetVersion,
        'axis': axis,
        'deltaMillis': deltaMillis,
        'reasonKey': reasonKey,
      };

  factory StructuredDelta.fromJson(Map<String, Object?> json) {
    return StructuredDelta(
      rulesetVersion: json['ruleset_version']! as String,
      axis: json['axis']! as String,
      deltaMillis: json['deltaMillis']! as int,
      reasonKey: json['reasonKey']! as String,
    );
  }

  @override
  bool operator ==(Object other) =>
      other is StructuredDelta &&
      other.rulesetVersion == rulesetVersion &&
      other.axis == axis &&
      other.deltaMillis == deltaMillis &&
      other.reasonKey == reasonKey;

  @override
  int get hashCode => Object.hash(rulesetVersion, axis, deltaMillis, reasonKey);
}
