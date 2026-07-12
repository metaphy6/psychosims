/// Localization helpers.
///
/// This is a stub until ARB files are added. It centralizes the string-lookup
/// seam so that features never hard-code user-facing copy.
class L10n {
  const L10n();

  static const String appTitle = 'Psychosims';

  /// Resolve an error code to a user-facing message.
  /// Real implementation will look up the config-selected locale.
  String errorMessage(String code) => '[$code]';

  /// Resolve a manifest name key.
  String manifestName(String key) => key;

  /// Resolve a manifest presentation key.
  String manifestPresentation(String key) => key;
}
