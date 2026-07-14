import 'package:psychemas/psychemas.dart';

/// A readable tactical-gap report for a manifest + loadout pair.
///
/// Surfaces which card signatures the case expects and whether the active
/// loadout covers them. This feeds the §13 strategic-exit choices in 2.7.
class LoadoutGapReport {
  final List<CardSignature> requiredSignatures;
  final List<CardSignature> presentSignatures;
  final List<CardSignature> missingSignatures;

  const LoadoutGapReport({
    required this.requiredSignatures,
    required this.presentSignatures,
    required this.missingSignatures,
  });

  bool get hasGap => missingSignatures.isNotEmpty;

  Map<String, Object?> toJson() => {
        'required_signatures': requiredSignatures.map((s) => s.name).toList(),
        'present_signatures': presentSignatures.map((s) => s.name).toList(),
        'missing_signatures': missingSignatures.map((s) => s.name).toList(),
      };
}

/// Pure analyzer that compares a case's card-signature needs to the active
/// loadout. Deterministic and testable; no randomness, no wall-clock.
class LoadoutAnalyzer {
  const LoadoutAnalyzer();

  /// Analyzes which signatures are required by [manifest] and missing from
  /// [loadout].
  LoadoutGapReport analyze(PatientManifest manifest, Loadout loadout) {
    final resolved = manifest.resolvedCards;
    final requiredSignatures =
        resolved.map((c) => c.signature).toSet().toList();

    final presentCards = resolved.where((c) => loadout.contains(c.id)).toList();
    final presentSignatures =
        presentCards.map((c) => c.signature).toSet().toList();

    final missingSignatures = requiredSignatures
        .where((s) => !presentSignatures.contains(s))
        .toList();

    return LoadoutGapReport(
      requiredSignatures: requiredSignatures,
      presentSignatures: presentSignatures,
      missingSignatures: missingSignatures,
    );
  }
}
