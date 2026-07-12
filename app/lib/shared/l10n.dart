import 'package:psychemas/psychemas.dart';

/// Localization helpers.
///
/// This is a stub until ARB files are added. It centralizes the string-lookup
/// seam so that features never hard-code user-facing copy.
class L10n implements StringCatalog {
  const L10n();

  static const String appTitle = 'Psychosims';

  static const _catalog = <String, String>{
    'manifests.poc_vexa_001.name': 'The Restless Hour',
    'manifests.poc_vexa_001.display_name': 'Restless Hour',
    'session.actions_label': 'Choose an approach',
    'session.cancel_button': 'Stop',
    'session.loading': 'Loading case...',
    'session.empty_turns': 'Select an action to begin.',
    'errors.model_load_failed': 'The model could not be loaded.',
    'errors.model_corrupt': 'The model file appears to be corrupt.',
    'errors.out_of_memory':
        'Not enough memory. Try a smaller model in settings.',
    'errors.generation_cancelled': 'Generation was cancelled.',
    'errors.generation_failed': 'The response could not be generated.',
    'errors.offline': 'You are offline.',
  };

  /// Resolve an error code to a user-facing message.
  /// Real implementation will look up the config-selected locale.
  String errorMessage(String code) => _catalog[code] ?? '[$code]';

  /// Resolve a manifest name key.
  String manifestName(String key) => _catalog[key] ?? key;

  /// Resolve a manifest presentation key.
  String manifestPresentation(String key) => _catalog[key] ?? key;

  /// Returns true if [key] is present in the catalog.
  @override
  bool containsKey(String key) => _catalog.containsKey(key);
}
