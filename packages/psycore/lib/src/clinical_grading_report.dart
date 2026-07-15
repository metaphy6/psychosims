import 'package:psychemas/psychemas.dart';

/// A single scored dimension in the Attending Physician grading report.
class GradingDimension {
  final String name;

  /// 0–100 score.
  final int score;

  final String reasonKey;

  const GradingDimension({
    required this.name,
    required this.score,
    required this.reasonKey,
  });

  Map<String, Object?> toJson() => {
        'name': name,
        'score': score,
        'reason_key': reasonKey,
      };
}

/// Deterministic clinical grading report (§15).
///
/// Scores the locally-tracked card sequence on three dimensions. The report is
/// a pure function of the receipt's ordered actions and deltas, so it is
/// unit-testable and replay-stable.
class ClinicalGradingReport {
  final GradingDimension alliance;
  final GradingDimension pathEfficiency;
  final GradingDimension pharmacologicalSafety;

  const ClinicalGradingReport({
    required this.alliance,
    required this.pathEfficiency,
    required this.pharmacologicalSafety,
  });

  Map<String, Object?> toJson() => {
        'alliance': alliance.toJson(),
        'path_efficiency': pathEfficiency.toJson(),
        'pharmacological_safety': pharmacologicalSafety.toJson(),
      };
}

/// Calculates the Attending Physician report from a session receipt.
class ClinicalGradingCalculator {
  const ClinicalGradingCalculator();

  ClinicalGradingReport calculate(SessionReceipt receipt) {
    return ClinicalGradingReport(
      alliance: _alliance(receipt),
      pathEfficiency: _pathEfficiency(receipt),
      pharmacologicalSafety: _pharmacologicalSafety(receipt),
    );
  }

  GradingDimension _alliance(SessionReceipt receipt) {
    final deltas = receipt.deltas;
    if (deltas.isEmpty) {
      return const GradingDimension(
        name: 'Therapeutic Alliance Maintenance',
        score: 0,
        reasonKey: 'grading.alliance.no_actions',
      );
    }

    var trustSum = 0;
    var relatableCount = 0;
    var manipulativeFailureCount = 0;

    for (final delta in deltas) {
      if (delta.axis == StateAxis.trust) {
        // Deltas store whole state units (the resolver emits whole-unit deltas);
        // the `deltaMillis` name is historical, not a fixed-point scale.
        trustSum += delta.deltaMillis;
      }
      if (delta.cardType == CardType.relatable) {
        relatableCount++;
      }
      if (delta.cardType == CardType.manipulative &&
          delta.contextFit == ContextFit.mismatched) {
        manipulativeFailureCount++;
      }
    }

    // Base score from net trust change, bonus for rapport plays, penalty for
    // manipulative failures.
    var score = 50 + trustSum;
    score += relatableCount * 5;
    score -= manipulativeFailureCount * 15;
    score = score.clamp(0, 100);

    return GradingDimension(
      name: 'Therapeutic Alliance Maintenance',
      score: score,
      reasonKey: score >= 70
          ? 'grading.alliance.strong'
          : score >= 40
              ? 'grading.alliance.mixed'
              : 'grading.alliance.weak',
    );
  }

  GradingDimension _pathEfficiency(SessionReceipt receipt) {
    final deltas = receipt.deltas;
    if (deltas.isEmpty) {
      return const GradingDimension(
        name: 'Diagnostic Path Efficiency',
        score: 0,
        reasonKey: 'grading.path.no_actions',
      );
    }

    final actionTypes = deltas.map((d) => d.cardType).toList();
    final uniqueTypes = actionTypes.toSet().length;
    final total = actionTypes.length;

    // Reward using multiple card types (versatility) and Disclosing for
    // breakthroughs; penalise stalling with repeated Postponing.
    final postponingCount =
        actionTypes.where((t) => t == CardType.postponing).length;
    final disclosingCount =
        actionTypes.where((t) => t == CardType.disclosing).length;

    var score = 40;
    score += (uniqueTypes / total * 30).round();
    score += disclosingCount * 5;
    score -= postponingCount * 4;
    score = score.clamp(0, 100);

    return GradingDimension(
      name: 'Diagnostic Path Efficiency',
      score: score,
      reasonKey: score >= 70
          ? 'grading.path.efficient'
          : score >= 40
              ? 'grading.path.mixed'
              : 'grading.path.inefficient',
    );
  }

  GradingDimension _pharmacologicalSafety(SessionReceipt receipt) {
    final deltas = receipt.deltas;
    if (deltas.isEmpty) {
      return const GradingDimension(
        name: 'Pharmacological Safety',
        score: 100,
        reasonKey: 'grading.pharma.no_medication',
      );
    }

    final medicationDeltas = deltas
        .where((d) =>
            d.axis == StateAxis.medicationTolerance ||
            d.axis == StateAxis.medicationDependency)
        .toList();

    if (medicationDeltas.isEmpty) {
      return const GradingDimension(
        name: 'Pharmacological Safety',
        score: 100,
        reasonKey: 'grading.pharma.no_medication',
      );
    }

    final dependencyTotal = medicationDeltas
        .where((d) => d.axis == StateAxis.medicationDependency)
        .fold<int>(0, (sum, d) => sum + d.deltaMillis);
    final toleranceTotal = medicationDeltas
        .where((d) => d.axis == StateAxis.medicationTolerance)
        .fold<int>(0, (sum, d) => sum + d.deltaMillis);

    // Higher dependency/tolerance lowers the safety score.
    var score = 100 - dependencyTotal * 10 - toleranceTotal * 3;
    score = score.clamp(0, 100);

    return GradingDimension(
      name: 'Pharmacological Safety',
      score: score,
      reasonKey: score >= 80
          ? 'grading.pharma.safe'
          : score >= 50
              ? 'grading.pharma.elevated_risk'
              : 'grading.pharma.unsafe',
    );
  }
}
