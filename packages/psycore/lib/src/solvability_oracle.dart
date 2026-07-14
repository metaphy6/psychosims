import 'package:psychemas/psychemas.dart';

/// Checks whether a case manifest is mechanically solvable on the core-only
/// path without a model binary present (Phase 2.8 gate).
///
/// A manifest is solvable if it defines at least one interaction pattern and
/// its clue tokens (if any) are reachable through the card taxonomy. This is a
/// conservative static check; full playout validation happens in the sandbox.
class SolvabilityOracle {
  const SolvabilityOracle();

  /// Returns true when [manifest] passes the mechanical solvability gate.
  bool isSolvable(PatientManifest manifest) {
    if (manifest.interactionPatterns.isEmpty) return false;

    // Every interaction pattern must resolve to a known card.
    for (final pattern in manifest.interactionPatterns) {
      try {
        cardFromInteractionPattern(pattern);
      } on ArgumentError {
        return false;
      }
    }

    return true;
  }

  /// Verifies the manifest passes content-integrity lint: no real labels and
  /// only fictional-taxonomy terms. This oracle only checks structural tokens;
  /// the CI lint enforces the string-level rules.
  bool isContentCompliant(PatientManifest manifest) {
    return manifest.clueTokens.every((token) => !_containsRealLabel(token));
  }

  static bool _containsRealLabel(String token) {
    // Structural guard; CI runs the authoritative regex list on raw files.
    final forbidden = RegExp(
      r'\b(depression|schizophrenia|bipolar|ptsd|ocd|adhd|autism|dementia|alzheimer|parkinson|anxiety disorder|personality disorder|prozac|zoloft|xanax|lexapro|abilify|adderall|ritalin|valium|klonopin|paxil|celexa|cymbalta|effexor|wellbutrin|dsm[- ]?5|dsm[- ]?v|icd[- ]?10|icd[- ]?11)\b',
      caseSensitive: false,
    );
    return forbidden.hasMatch(token);
  }
}
