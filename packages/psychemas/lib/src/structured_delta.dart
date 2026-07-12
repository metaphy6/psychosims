/// A single structured, deterministic state change.
class StructuredDelta {
  final String axis;
  final int deltaMillis;
  final String reasonKey;

  const StructuredDelta({
    required this.axis,
    required this.deltaMillis,
    required this.reasonKey,
  });

  Map<String, Object?> toJson() => {
        'axis': axis,
        'deltaMillis': deltaMillis,
        'reasonKey': reasonKey,
      };

  factory StructuredDelta.fromJson(Map<String, Object?> json) {
    return StructuredDelta(
      axis: json['axis']! as String,
      deltaMillis: json['deltaMillis']! as int,
      reasonKey: json['reasonKey']! as String,
    );
  }
}
