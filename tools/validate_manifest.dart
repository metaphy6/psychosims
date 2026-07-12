import 'dart:io';

import 'package:psychemas/psychemas.dart';

/// Headless manifest validator used by authors and CI.
///
/// Runs the exact same loader logic as the app, optionally checking forbidden
/// content patterns from the fictional-taxonomy registry.
///
/// Usage:
///   dart tools/validate_manifest.dart content/manifests/poc_sample.json
void main(List<String> args) {
  if (args.isEmpty) {
    stderr.writeln('Usage: dart tools/validate_manifest.dart <manifest.json>');
    exit(1);
  }

  final path = args.first;
  final file = File(path);
  if (!file.existsSync()) {
    stderr.writeln('File not found: $path');
    exit(2);
  }

  final loader = ManifestLoader(
    forbiddenPatterns: _defaultForbiddenPatterns(),
  );

  try {
    loader.load(file.readAsBytesSync());
    stdout.writeln('✅ Manifest valid: $path');
  } on ManifestValidationError catch (e) {
    stderr.writeln('❌ ${e.kind.name}: ${e.message}');
    exit(3);
  }
}

List<RegExp> _defaultForbiddenPatterns() {
  // Mirrors content/fictional_taxonomy.yaml forbidden_patterns.
  return [
    RegExp(
      r'\b(depression|schizophrenia|bipolar|ptsd|ocd|adhd|autism|dementia|alzheimer|parkinson|anxiety disorder|personality disorder)\b',
      caseSensitive: false,
    ),
    RegExp(
      r'\b(prozac|zoloft|xanax|lexapro|abilify|adderall|ritalin|valium|klonopin|paxil|celexa|cymbalta|effexor|wellbutrin)\b',
      caseSensitive: false,
    ),
    RegExp(
      r'\b(dsm[- ]?5|dsm[- ]?v|icd[- ]?10|icd[- ]?11)\b',
      caseSensitive: false,
    ),
  ];
}
