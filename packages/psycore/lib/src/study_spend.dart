import 'package:psychemas/psychemas.dart';

/// Result of attempting to unlock a study card.
enum StudySpendStatus {
  success,
  insufficientStudy,
  insufficientSubspecialty,
  alreadyUnlocked,
  unknownCard,
}

/// Immutable outcome of a study-point spend.
class StudySpendResult {
  final StudySpendStatus status;
  final String cardId;
  final int remainingStudy;
  final int remainingSubspecialty;

  const StudySpendResult({
    required this.status,
    required this.cardId,
    required this.remainingStudy,
    required this.remainingSubspecialty,
  });
}

/// Pure logic for spending study/subspecialty points to unlock target cards.
///
/// This is the offline §15 research → card-acquisition path. Currency balances
/// are passed in as integers; the caller (2.5 ledger / 2.9 profile) owns the
/// authoritative balances.
class StudySpend {
  const StudySpend();

  /// Attempts to unlock [cardId] from [catalog] given current balances.
  StudySpendResult unlock({
    required StudyCatalog catalog,
    required String cardId,
    required int studyPoints,
    required int subspecialtyPoints,
    required Set<String> unlockedCardIds,
  }) {
    final entry = catalog.lookup(cardId);
    if (entry == null) {
      return StudySpendResult(
        status: StudySpendStatus.unknownCard,
        cardId: cardId,
        remainingStudy: studyPoints,
        remainingSubspecialty: subspecialtyPoints,
      );
    }

    if (unlockedCardIds.contains(cardId)) {
      return StudySpendResult(
        status: StudySpendStatus.alreadyUnlocked,
        cardId: cardId,
        remainingStudy: studyPoints,
        remainingSubspecialty: subspecialtyPoints,
      );
    }

    if (studyPoints < entry.studyCost) {
      return StudySpendResult(
        status: StudySpendStatus.insufficientStudy,
        cardId: cardId,
        remainingStudy: studyPoints,
        remainingSubspecialty: subspecialtyPoints,
      );
    }

    if (subspecialtyPoints < entry.subspecialtyCost) {
      return StudySpendResult(
        status: StudySpendStatus.insufficientSubspecialty,
        cardId: cardId,
        remainingStudy: studyPoints,
        remainingSubspecialty: subspecialtyPoints,
      );
    }

    return StudySpendResult(
      status: StudySpendStatus.success,
      cardId: cardId,
      remainingStudy: studyPoints - entry.studyCost,
      remainingSubspecialty: subspecialtyPoints - entry.subspecialtyCost,
    );
  }
}
