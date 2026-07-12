/// Failure modes for manifest loading, aligned with the 0.7 error taxonomy.
enum ManifestErrorKind {
  /// Malformed JSON or missing required field.
  malformed,

  /// schema_version is not supported by this build.
  unknownVersion,

  /// content_checksum does not match the payload.
  checksumMismatch,

  /// A value violates a length, size, or depth cap.
  overBudget,

  /// A player-facing localization key is missing from the catalog.
  missingLocalization,

  /// Content contains a real clinical label or forbidden pattern.
  contentIntegrity,
}

/// Exception thrown when a manifest fails validation.
class ManifestValidationError implements Exception {
  final ManifestErrorKind kind;
  final String message;

  const ManifestValidationError(this.kind, this.message);

  @override
  String toString() => 'ManifestValidationError(${kind.name}): $message';
}
