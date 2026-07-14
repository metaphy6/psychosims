import 'package:psychemas/psychemas.dart';

/// Result of attempting to unlock a field-training node.
enum FieldTrainingStatus {
  success,
  insufficientStudy,
  insufficientSubspecialty,
  missingPrerequisite,
  alreadyUnlocked,
  unknownField,
}

class FieldTrainingResult {
  final FieldTrainingStatus status;
  final String fieldKey;
  final int remainingStudy;
  final int remainingSubspecialty;

  const FieldTrainingResult({
    required this.status,
    required this.fieldKey,
    required this.remainingStudy,
    required this.remainingSubspecialty,
  });
}

/// Spend study/subspecialty points to unlock fields in the training tree.
class FieldTrainingSpend {
  const FieldTrainingSpend();

  FieldTrainingResult unlock({
    required FieldTrainingTree tree,
    required String fieldKey,
    required int studyPoints,
    required int subspecialtyPoints,
    required Set<String> unlockedFields,
  }) {
    final node = tree.lookup(fieldKey);
    if (node == null) {
      return FieldTrainingResult(
        status: FieldTrainingStatus.unknownField,
        fieldKey: fieldKey,
        remainingStudy: studyPoints,
        remainingSubspecialty: subspecialtyPoints,
      );
    }
    if (unlockedFields.contains(fieldKey)) {
      return FieldTrainingResult(
        status: FieldTrainingStatus.alreadyUnlocked,
        fieldKey: fieldKey,
        remainingStudy: studyPoints,
        remainingSubspecialty: subspecialtyPoints,
      );
    }
    if (node.parentFieldKey.isNotEmpty &&
        !unlockedFields.contains(node.parentFieldKey)) {
      return FieldTrainingResult(
        status: FieldTrainingStatus.missingPrerequisite,
        fieldKey: fieldKey,
        remainingStudy: studyPoints,
        remainingSubspecialty: subspecialtyPoints,
      );
    }
    if (studyPoints < node.studyCost) {
      return FieldTrainingResult(
        status: FieldTrainingStatus.insufficientStudy,
        fieldKey: fieldKey,
        remainingStudy: studyPoints,
        remainingSubspecialty: subspecialtyPoints,
      );
    }
    if (subspecialtyPoints < node.subspecialtyCost) {
      return FieldTrainingResult(
        status: FieldTrainingStatus.insufficientSubspecialty,
        fieldKey: fieldKey,
        remainingStudy: studyPoints,
        remainingSubspecialty: subspecialtyPoints,
      );
    }
    return FieldTrainingResult(
      status: FieldTrainingStatus.success,
      fieldKey: fieldKey,
      remainingStudy: studyPoints - node.studyCost,
      remainingSubspecialty: subspecialtyPoints - node.subspecialtyCost,
    );
  }
}
