import 'canonical_json.dart';

/// Visible operational-pressure state (§23).
///
/// Pressure is surfaced as a legible UI category, never a hidden well-being
/// stat. Values are fixed-point integers in millis (0..1000 maps to 0%..100%).
class OperationalPressure {
  /// Current pressure level in millis.
  final int valueMillis;

  /// Timestamp (seconds) when the pressure was last updated.
  final int lastUpdatedSeconds;

  const OperationalPressure({
    this.valueMillis = 0,
    this.lastUpdatedSeconds = 0,
  });

  OperationalPressure copyWith({
    int? valueMillis,
    int? lastUpdatedSeconds,
  }) {
    return OperationalPressure(
      valueMillis: valueMillis ?? this.valueMillis,
      lastUpdatedSeconds: lastUpdatedSeconds ?? this.lastUpdatedSeconds,
    );
  }

  /// UI category for the current pressure level.
  PressureCategory get category {
    if (valueMillis < 400) return PressureCategory.healthy;
    if (valueMillis < 750) return PressureCategory.strained;
    return PressureCategory.atRisk;
  }

  Map<String, Object?> toJson() => {
        'value_millis': valueMillis,
        'last_updated_seconds': lastUpdatedSeconds,
      };

  factory OperationalPressure.fromJson(Map<String, Object?> json) {
    return OperationalPressure(
      valueMillis: json['value_millis']! as int,
      lastUpdatedSeconds: json['last_updated_seconds']! as int,
    );
  }

  List<int> toCanonicalBytes() => CanonicalJson.encode(toJson());
}

enum PressureCategory {
  healthy,
  strained,
  atRisk,
}
