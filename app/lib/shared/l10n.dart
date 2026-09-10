import 'package:psychemas/psychemas.dart';

/// Localization helpers.
///
/// This is a stub until ARB files are added. It centralizes the string-lookup
/// seam so that features never hard-code user-facing copy.
class L10n implements StringCatalog {
  const L10n();

  static const String appTitle = 'Psychosims';
  static const String onlineTitle = 'Online practice';
  static const String onlineDescription =
      'Keep signed sessions and your server profile in sync across devices.';
  static const String onlineHeld =
      'This completed path is not covered by current verification. Rewards remain held.';
  static const String onlineCoverage =
      'Only some completion paths are covered by server verification. Rewards are not guaranteed.';
  static const String onlineConditional =
      'This session may qualify for verified rewards. Only supported completion paths are covered.';
  static const String onlineUncoveredStart =
      'This session is outside current verification coverage. Online rewards will be held.';
  static const String onlineQueued =
      'Session saved for sync. The server will confirm verification and any rewards.';
  static const String onlineNotConfigured =
      'Online sign-in is not configured for this build. Local practice is available.';
  static const String onlineGoogle = 'Continue with Google';
  static const String onlineApple = 'Continue with Apple';
  static const String onlineRecoverKey = 'Replace this device’s signing key';
  static const String onlineSignOut = 'Sign out';
  static const String onlineSync = 'Sync now';
  static const String onlineStart = 'Start online session';
  static const String onlineSignedOut = 'Sign in to start online sessions.';
  static const String onlineExpired =
      'This online session expired. Return to Online practice to start a new session.';
  static const String onlineDiscardExpired = 'Discard expired session';
  static const String onlineRejection =
      'The server could not accept this session. Its result is saved here for review.';
  static const String onlineProfileStale =
      'Showing the last saved server profile.';
  static const String onlineProfileCurrent = 'Server profile is up to date.';
  static String onlinePending(int count) => '$count sessions waiting to sync';
  static String onlineProfile(int level, int xp) => 'Level $level · $xp XP';
  static String onlineVerdict(String status,
      {String rewardStatus = 'held_unproven'}) {
    if (status != 'accepted') return 'Not accepted';
    return switch (rewardStatus) {
      'certified' => 'Synced · result verified',
      'certified_unrewarded' => 'Synced · verified without reward',
      _ => 'Synced · rewards held',
    };
  }

  static String onlineRewardDetail(ReceiptVerdict verdict) {
    if (verdict.status != 'accepted') return onlineRejection;
    if (verdict.rewardStatus == 'certified') {
      final whole = verdict.cashMicrosAwarded ~/ 1000000;
      final fraction = (verdict.cashMicrosAwarded % 1000000)
          .toString()
          .padLeft(6, '0')
          .replaceFirst(RegExp(r'0+$'), '');
      final cash = fraction.isEmpty ? '$whole' : '$whole.$fraction';
      return 'Server rewards: ${verdict.xpAwarded} XP · ${verdict.studyPointsAwarded} study points · $cash cash';
    }
    if (verdict.rewardStatus == 'certified_unrewarded') {
      return switch (verdict.rewardReason) {
        'cooldown' => 'Result verified. The reward cooldown is still active.',
        'window_budget' =>
          'Result verified. The reward limit for this time window has been reached.',
        'economy_disabled' =>
          'Result verified. Online rewards are currently disabled.',
        'balance_limit' =>
          'Result verified. Your balance has reached its limit.',
        'already_cured' =>
          'Result verified. This patient has already received completion rewards.',
        _ => 'Result verified without a reward.',
      };
    }
    return onlineHeld;
  }

  static String onlineError(String kind) {
    if (kind == 'expired_permit') return onlineExpired;
    if (kind == 'sign_in_not_configured') return onlineNotConfigured;
    if (kind == 'offline' || kind == 'timeout') {
      return 'Connection unavailable. Saved sessions will retry when you reconnect.';
    }
    if (kind == 'signed_out' ||
        kind == 'session_expired' ||
        kind == 'account_mismatch') {
      return 'Sign in again to continue with this account.';
    }
    if (kind == 'content_mismatch') {
      return 'This case changed on the server. Update the case before starting.';
    }
    return 'Online practice is unavailable. Check your connection and secure storage, then retry.';
  }

  static const String sessionSuccess = 'Session complete';
  static const String sessionFailure = 'Session ended';
  static const String sessionSaved =
      'Your practice history and progress are saved on this device.';
  static const String sessionNext = 'Next session';
  static const String sessionRetry = 'Retry';
  static const String homeStartPocSession = 'Prepare session';
  static const String careerTitle = 'Local practice career';
  static const String careerEmpty =
      'Complete a session to build your practice history.';
  static const String careerLoadError =
      'Your saved career could not be read. Retry after checking device storage.';
  static const String careerStudy = 'Study';
  static const String careerCash = 'Cash';
  static String careerSessions(int count) => '$count sessions completed';
  static String careerTurns(int count) => '$count turns';
  static String careerBalances(
          {required int xp, required int study, required int cash}) =>
      'XP: $xp · $careerStudy: $study · $careerCash: $cash';

  static const String homeFetchModel = 'Download model';
  static const String modelFetchTitle = 'Download Model';
  static const String modelFetchDescription =
      'A local model is required for private, offline dialogue. Downloads resume if interrupted.';
  static const String modelFetchStart = 'Download';
  static const String modelFetchPause = 'Pause';
  static const String modelFetchResume = 'Resume';
  static const String modelFetchMeteredLabel =
      'Defer until unmetered connection';
  static const String modelFetchComplete = 'Download complete.';

  static const String loadoutTitle = 'Prepare Session';
  static const String loadoutStyleLabel = 'Style';
  static const String loadoutInitialStateLabel = 'Initial state';
  static const String loadoutActiveCardsLabel = 'Active cards';
  static const String loadoutMissingTacticsLabel = 'Missing tactics';

  static String loadoutStyle(String archetype) =>
      '$loadoutStyleLabel: $archetype';
  static String loadoutInitialState(String state) =>
      '$loadoutInitialStateLabel: $state';
  static String loadoutActiveCards(int active, int cap) =>
      '$loadoutActiveCardsLabel: $active / $cap';
  static String loadoutMissingTactics(List<String> tactics) =>
      '$loadoutMissingTacticsLabel: ${tactics.join(', ')}';
  static const String loadoutOwnedCardsSemanticLabel =
      'Owned cards, toggle to equip or unequip';
  static const String loadoutEquipped = 'Equipped';
  static const String loadoutOwned = 'Owned';
  static const String loadoutRemoveTooltip = 'Remove from loadout';
  static const String loadoutAddTooltip = 'Add to loadout';
  static const String loadoutFocusLabel = 'Focus';
  static const String loadoutEmotionalDeliveryLabel = 'Emotional Delivery';
  static const String loadoutFocusChildhood = 'Childhood';
  static const String loadoutFocusBalanced = 'Balanced';
  static const String loadoutFocusWorkspace = 'Workspace';
  static const String loadoutDeliveryWarm = 'Warm';
  static const String loadoutDeliveryObjective = 'Objective';
  static const String loadoutDeliveryBalanced = 'Balanced';
  static const String loadoutStartSession = 'Start Session';
  static const String loadoutInvalid =
      'Equip at least one available card within the session slot limit.';

  static const _catalog = <String, String>{
    'manifests.poc_vexa_001.name': 'The Restless Hour',
    'manifests.poc_vexa_001.display_name': 'Restless Hour',
    'session.actions_label': 'Choose an approach',
    'session.cancel_button': 'Stop',
    'session.loading': 'Loading case...',
    'session.empty_turns': 'Select an action to begin.',
    'home.start_poc_session': 'Start PoC Session',
    'home.fetch_model': 'Fetch Model',
    'model_fetch.no_source': 'No model source is configured.',
    'model_fetch.metered': 'Download deferred until unmetered connection.',
    'model_fetch.disk_space': 'Not enough free space.',
    'model_fetch.checksum_error': 'Model file is corrupt; retry to re-fetch.',
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

  static String modelFetchProgress(int percent) => '$percent%';

  static String get modelFetchNoSource => _catalog['model_fetch.no_source']!;

  static String get modelFetchMetered => _catalog['model_fetch.metered']!;

  static String modelFetchDiskSpace(int required, int free) =>
      '${_catalog['model_fetch.disk_space']!} '
      'Required: $required bytes, free: $free bytes.';

  static String get modelFetchChecksumError =>
      _catalog['model_fetch.checksum_error']!;
}
