import 'package:psychemas/psychemas.dart';

import 'sim_state.dart';

/// Compiles a deterministic, bounded history digest for multi-session cases.
///
/// The digest is a structured summary of whitelisted enums and numbers — never
/// raw transcripts — and is designed to stay within a fixed token envelope
/// regardless of how many sessions accumulate (2.4).
class MultiSessionDigestCompiler {
  const MultiSessionDigestCompiler();

  /// Maximum prose sentences emitted so token count stays bounded.
  static const int maxSentences = 4;

  /// Builds a digest from [envelope] and the current [state].
  ///
  /// [encyclopedia] provides field-note titles for collected clues. Missing
  /// entries are omitted rather than failing, preserving robustness.
  String compile({
    required CaseHistoryEnvelope envelope,
    required SimState state,
    ClinicalEncyclopedia encyclopedia = ClinicalEncyclopedia.empty,
  }) {
    final parts = <String>[];

    if (envelope.priorSessionCount > 0) {
      parts.add(
        'This case has been worked across ${envelope.priorSessionCount} prior session${envelope.priorSessionCount == 1 ? '' : 's'}.',
      );
    }

    if (envelope.derangements.isNotEmpty) {
      final names = envelope.derangements.map(_derangementName).join(', ');
      parts.add('A lasting complication remains: $names.');
    }

    if (envelope.inheritedMedication.drug != null) {
      final drug = envelope.inheritedMedication.drug!.name;
      final dep = envelope.inheritedMedication.dependency;
      parts.add(
        'Ongoing ${drug} use has left a dependency marker of $dep.',
      );
    }

    if (envelope.collectedClues.isNotEmpty) {
      final titles = envelope.collectedClues
          .map((c) => encyclopedia.lookupByClue(c)?.titleKey)
          .whereType<String>()
          .toList();
      if (titles.isNotEmpty) {
        parts.add('Research notes unlocked: ${titles.join(', ')}.');
      }
    }

    // Current-feeling summary (always present once prior sessions exist).
    if (envelope.priorSessionCount > 0 || parts.isEmpty) {
      parts.add(
        'Right now the patient feels ${_agitationWord(state.agitationLevel)} agitated, '
        '${_trustWord(state.trustScore)} trusting, and ${_defenseWord(state.activeDefense)}.',
      );
    }

    // Enforce the bounded sentence cap.
    final bounded =
        parts.length > maxSentences ? parts.sublist(0, maxSentences) : parts;
    return bounded.join(' ');
  }

  static String _derangementName(DerangementMutation mutation) {
    return switch (mutation) {
      DerangementMutation.somaticFixation => 'somatic fixation',
      DerangementMutation.trustCollapse => 'trust collapse',
      DerangementMutation.resistanceCrystallisation =>
        'resistance crystallisation',
    };
  }

  static String _agitationWord(int value) {
    if (value <= 25) return 'only slightly';
    if (value <= 60) return 'moderately';
    return 'very';
  }

  static String _trustWord(int value) {
    if (value <= 25) return 'hardly';
    if (value <= 60) return 'somewhat';
    return 'reasonably';
  }

  static String _defenseWord(DefenseState defense) {
    return switch (defense) {
      DefenseState.none => 'undefended',
      DefenseState.guarded => 'guarded',
      DefenseState.rigid => 'rigidly defended',
    };
  }
}
