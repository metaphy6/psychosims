import 'canonical_json.dart';

/// A prescribed fictional drug token from the invented formulary.
///
/// Drug names are drawn from the 0.12 fictional-taxonomy registry; no real
/// DSM/ICD label or drug brand appears here.
enum FictionalDrug {
  ferveAxine,
  torpidol,
  quiescetine,
  vexanil,
  dormisal,
}

extension FictionalDrugJson on FictionalDrug {
  String toJson() => name;
  static FictionalDrug fromJson(String value) =>
      FictionalDrug.values.byName(value);
}

/// Typed medication state carried on [SimState].
///
/// Tracks prescribed fictional drug, dosage, accrued tolerance, and chemical
/// dependency. All values are bounded integers or fixed-point so replay stays
/// byte-identical.
class MedicationState {
  final FictionalDrug? drug;
  final int dosage; // 0–100 scale, arbitrary units
  final int tolerance; // accrued tolerance, 0–100
  final int dependency; // chemical dependency, 0–100

  const MedicationState({
    this.drug,
    this.dosage = 0,
    this.tolerance = 0,
    this.dependency = 0,
  });

  const MedicationState.empty() : this();

  MedicationState copyWith({
    FictionalDrug? drug,
    int? dosage,
    int? tolerance,
    int? dependency,
  }) {
    return MedicationState(
      drug: drug ?? this.drug,
      dosage: dosage ?? this.dosage,
      tolerance: tolerance ?? this.tolerance,
      dependency: dependency ?? this.dependency,
    );
  }

  Map<String, Object?> toJson() => {
        'drug': drug?.toJson(),
        'dosage': dosage,
        'tolerance': tolerance,
        'dependency': dependency,
      };

  factory MedicationState.fromJson(Map<String, Object?> json) {
    final drugJson = json['drug'] as String?;
    return MedicationState(
      drug: drugJson == null ? null : FictionalDrugJson.fromJson(drugJson),
      dosage: json['dosage']! as int,
      tolerance: json['tolerance']! as int,
      dependency: json['dependency']! as int,
    );
  }

  List<int> toCanonicalBytes() => CanonicalJson.encode(toJson());

  @override
  bool operator ==(Object other) =>
      other is MedicationState &&
      other.drug == drug &&
      other.dosage == dosage &&
      other.tolerance == tolerance &&
      other.dependency == dependency;

  @override
  int get hashCode => Object.hash(drug, dosage, tolerance, dependency);
}
