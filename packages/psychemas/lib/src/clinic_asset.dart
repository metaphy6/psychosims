import 'canonical_json.dart';

/// An owned clinic office asset (§22, Phase 6.3 hiring gate).
class ClinicAsset {
  final String officeId;

  /// 1 = smallest/practice office; higher tiers unlock hiring slots.
  final int tier;

  /// Whether the office is owned outright or rented.
  final bool isOwned;

  /// Monthly rent in cash micros; zero if owned.
  final int monthlyRentMicros;

  const ClinicAsset({
    required this.officeId,
    required this.tier,
    this.isOwned = false,
    this.monthlyRentMicros = 0,
  });

  ClinicAsset copyWith({
    String? officeId,
    int? tier,
    bool? isOwned,
    int? monthlyRentMicros,
  }) {
    return ClinicAsset(
      officeId: officeId ?? this.officeId,
      tier: tier ?? this.tier,
      isOwned: isOwned ?? this.isOwned,
      monthlyRentMicros: monthlyRentMicros ?? this.monthlyRentMicros,
    );
  }

  Map<String, Object?> toJson() => {
        'office_id': officeId,
        'tier': tier,
        'is_owned': isOwned,
        'monthly_rent_micros': monthlyRentMicros,
      };

  factory ClinicAsset.fromJson(Map<String, Object?> json) {
    return ClinicAsset(
      officeId: json['office_id']! as String,
      tier: json['tier']! as int,
      isOwned: json['is_owned']! as bool,
      monthlyRentMicros: json['monthly_rent_micros']! as int,
    );
  }

  List<int> toCanonicalBytes() => CanonicalJson.encode(toJson());

  @override
  bool operator ==(Object other) =>
      other is ClinicAsset &&
      other.officeId == officeId &&
      other.tier == tier &&
      other.isOwned == isOwned &&
      other.monthlyRentMicros == monthlyRentMicros;

  @override
  int get hashCode => Object.hash(officeId, tier, isOwned, monthlyRentMicros);
}
