import 'dart:convert';
import 'session_start_state.dart';
import 'canonical_json.dart';

String wireString(Map<String, Object?> json, String key, {int max = 512}) {
  final value = json[key];
  if (value is! String || value.isEmpty || value.length > max) {
    throw FormatException('Invalid $key');
  }
  return value;
}

String wireIdentifier(Map<String, Object?> json, String key) {
  final value = wireString(json, key, max: 128);
  if (!RegExp(r'^[A-Za-z0-9_.:-]+$').hasMatch(value)) {
    throw FormatException('Invalid structured $key');
  }
  return value;
}

List<String> wireIdentifiers(Map<String, Object?> json, String key,
    {required int max}) {
  final values = json[key];
  if (values is! List || values.length > max) {
    throw FormatException('Invalid $key');
  }
  return List.unmodifiable(
      values.map((value) => wireIdentifier({key: value}, key)));
}

/// A strict vocabulary shared by permits and the immutable signed outbox.
/// Exact round trips reject unrecognized fields instead of preserving dialogue.
void validateWireStartState(Map<String, Object?> start) {
  const required = {
    'loadout',
    'library',
    'controllers',
    'initial_axes',
    'root_seed'
  };
  if (!start.keys.toSet().containsAll(required) ||
      start.keys.any((key) =>
          !{...required, 'case_id', 'manifest_checksum'}.contains(key))) {
    throw const FormatException('Unrecognized structured start fields');
  }
  final parsed = SessionStartState.fromJson(start);
  final normalized = parsed.toJson();
  if (parsed.rootSeed < 0 ||
      parsed.rootSeed > 2147483647 ||
      parsed.loadout.slotCap < 1 ||
      parsed.loadout.slotCap > 6 ||
      parsed.initialAxes.length > 8) {
    throw const FormatException('Invalid structured start bounds');
  }
  wireIdentifiers(parsed.loadout.toJson(), 'card_ids', max: 6);
  wireIdentifiers(parsed.library.toJson(), 'owned_card_ids', max: 64);
  const axes = {
    'trust',
    'agitation',
    'resistance',
    'trauma',
    'session_progress',
    'freeze_turns',
    'medication_tolerance',
    'medication_dependency',
    'activeDefense',
    'sessionProgress',
    'freezeTurns',
    'medicationTolerance',
    'medicationDependency'
  };
  for (final entry in parsed.initialAxes.entries) {
    if (!axes.contains(entry.key) || entry.value < 0 || entry.value > 100) {
      throw const FormatException('Invalid structured start axis');
    }
  }
  if (start.containsKey('case_id')) {
    normalized['case_id'] = wireIdentifier(start, 'case_id');
  }
  if (start.containsKey('manifest_checksum')) {
    final checksum = wireString(start, 'manifest_checksum');
    if (!RegExp(r'^sha256:[0-9a-fA-F]{64}$').hasMatch(checksum)) {
      throw const FormatException('Invalid content checksum');
    }
    normalized['manifest_checksum'] = checksum;
  }
  if (CanonicalJson.encodeString(start) !=
      CanonicalJson.encodeString(normalized)) {
    throw const FormatException('Unrecognized structured start fields');
  }
}

/// Project unsigned authoritative profile data onto the public primitive schema.
Map<String, Object?> wireProfile(Map<String, Object?> json) {
  final result = <String, Object?>{
    'account_id': wireIdentifier(json, 'account_id')
  };
  const numbers = {
    'version',
    'level',
    'xp',
    'study_points',
    'subspecialty_points',
    'reputation',
    'prestige',
    'cash_micros',
    'clinic_tier'
  };
  if (json['version'] is! int)
    throw const FormatException('Invalid profile version');
  for (final key in numbers) {
    if (!json.containsKey(key)) continue;
    final value = json[key];
    if (value is! int || value < 0 || value > 9007199254740991) {
      throw const FormatException('Invalid profile amount');
    }
    result[key] = value;
  }
  if (json.containsKey('owned_card_ids')) {
    result['owned_card_ids'] = wireIdentifiers(json, 'owned_card_ids', max: 64);
  }
  if (json.containsKey('onboarding_done')) {
    if (json['onboarding_done'] is! bool)
      throw const FormatException('Invalid profile onboarding');
    result['onboarding_done'] = json['onboarding_done'];
  }
  if (json.containsKey('updated_at'))
    result['updated_at'] = wireTime(json, 'updated_at').toIso8601String();
  return immutableWireMap(result);
}

DateTime wireTime(Map<String, Object?> json, String key) {
  final value = wireString(json, key);
  if (!value.endsWith('Z') &&
      !RegExp(r'[+-][0-9]{2}:[0-9]{2}$').hasMatch(value)) {
    throw FormatException('Missing time zone in $key');
  }
  return DateTime.parse(value).toUtc();
}

Map<String, Object?> immutableWireMap(Map<String, Object?> map) {
  Object? freeze(Object? value) {
    if (value is Map<String, Object?>)
      return Map<String, Object?>.unmodifiable(
          value.map((k, v) => MapEntry(k, freeze(v))));
    if (value is List) return List<Object?>.unmodifiable(value.map(freeze));
    return value;
  }

  return freeze(jsonDecode(jsonEncode(map))) as Map<String, Object?>;
}

class AuthPair {
  AuthPair.fromJson(Map<String, Object?> json)
      : accountId = wireIdentifier(json, 'account_id'),
        accessToken = wireString(json, 'access_token', max: 16384),
        refreshToken = wireString(json, 'refresh_token', max: 16384),
        accessExpiresAt = wireTime(json, 'access_expires_at'),
        refreshExpiresAt = wireTime(json, 'refresh_expires_at') {
    if (json['token_type'] != 'Bearer')
      throw const FormatException('Unsupported token type');
  }
  final String accountId, accessToken, refreshToken;
  final DateTime accessExpiresAt, refreshExpiresAt;
  Map<String, Object?> toJson() => {
        'account_id': accountId,
        'access_token': accessToken,
        'refresh_token': refreshToken,
        'token_type': 'Bearer',
        'access_expires_at': accessExpiresAt.toIso8601String(),
        'refresh_expires_at': refreshExpiresAt.toIso8601String()
      };
  @override
  String toString() => 'AuthPair(redacted)';
}

String? _optionalDigest(Map<String, Object?> json, String key) {
  if (!json.containsKey(key)) return null;
  final value = wireString(json, key, max: 64);
  if (!RegExp(r'^[0-9a-f]{64}$').hasMatch(value)) {
    throw FormatException('Invalid $key');
  }
  return value;
}

int _award(Map<String, Object?> json, String key, int maximum) {
  if (!json.containsKey(key)) return 0;
  final value = json[key];
  if (value is! int || value < 0 || value > maximum) {
    throw FormatException('Invalid $key');
  }
  return value;
}

class SessionAuthorization {
  SessionAuthorization.fromJson(Map<String, Object?> json)
      : id = wireIdentifier(json, 'id'),
        patientId = wireIdentifier(json, 'patient_id'),
        rulesetVersion = wireIdentifier(json, 'ruleset_version'),
        expiresAt = wireTime(json, 'expires_at'),
        rewardStatus = wireString(json, 'reward_status'),
        certificateId = _optionalDigest(json, 'certificate_id'),
        catalogSha256 = _optionalDigest(json, 'catalog_sha256'),
        startState =
            immutableWireMap(json['start_state'] as Map<String, Object?>) {
    validateWireStartState(startState);
    if (rewardStatus == 'conditional_certified') {
      if (certificateId == null || catalogSha256 == null) {
        throw const FormatException('Missing conditional certificate binding');
      }
    } else if (rewardStatus != 'held_unproven' ||
        certificateId != null ||
        catalogSha256 != null) {
      throw const FormatException('Invalid reward eligibility');
    }
  }
  final String id, patientId, rulesetVersion, rewardStatus;
  final String? certificateId, catalogSha256;
  final Map<String, Object?> startState;
  final DateTime expiresAt;
  Map<String, Object?> toJson() => {
        'id': id,
        'patient_id': patientId,
        'ruleset_version': rulesetVersion,
        'expires_at': expiresAt.toIso8601String(),
        'reward_status': rewardStatus,
        if (certificateId != null) 'certificate_id': certificateId,
        if (catalogSha256 != null) 'catalog_sha256': catalogSha256,
        'start_state': startState
      };
}

class ReceiptVerdict {
  ReceiptVerdict(
      {required this.id,
      required this.idempotencyKey,
      required this.status,
      required this.rewardStatus,
      this.profileVersion,
      this.code,
      this.retryable = false,
      this.certificateId,
      this.rewardReason,
      this.xpAwarded = 0,
      this.studyPointsAwarded = 0,
      this.cashMicrosAwarded = 0});

  /// Protocol ceilings match the server's bounded award policy. Amounts are
  /// authoritative receipt metadata, never instructions to mutate local career.
  static const maxXpAwarded = 10000;
  static const maxStudyPointsAwarded = 1000;
  static const maxCashMicrosAwarded = 1000000000;
  static const rewardReasons = {
    'cooldown',
    'window_budget',
    'economy_disabled',
    'balance_limit',
    'already_cured'
  };

  factory ReceiptVerdict.fromJson(Map<String, Object?> json) {
    final status = wireString(json, 'status');
    final reward = json.containsKey('reward_status')
        ? wireString(json, 'reward_status')
        : 'held_unproven';
    final version = json['profile_version'];
    if (!['accepted', 'rejected', 'retryable'].contains(status) ||
        (json.containsKey('profile_version') &&
            (version is! int || version < 1 || version > 9007199254740991))) {
      throw const FormatException('Invalid receipt verdict');
    }
    final certificate = _optionalDigest(json, 'certificate_id');
    final reason = json.containsKey('reward_reason')
        ? wireString(json, 'reward_reason')
        : null;
    final xp = _award(json, 'xp_awarded', maxXpAwarded);
    final study = _award(json, 'study_points_awarded', maxStudyPointsAwarded);
    final cash = _award(json, 'cash_micros_awarded', maxCashMicrosAwarded);
    final zeroAwards = xp == 0 && study == 0 && cash == 0;
    switch (reward) {
      case 'held_unproven':
        if (certificate != null || reason != null || !zeroAwards) {
          throw const FormatException('Held verdict cannot award rewards');
        }
      case 'certified':
        if (status != 'accepted' ||
            certificate == null ||
            version == null ||
            reason != null) {
          throw const FormatException('Invalid certified verdict');
        }
      case 'certified_unrewarded':
        if (status != 'accepted' ||
            certificate == null ||
            version == null ||
            !rewardReasons.contains(reason) ||
            !zeroAwards) {
          throw const FormatException('Invalid unrewarded verdict');
        }
      default:
        throw const FormatException('Unknown reward status');
    }
    return ReceiptVerdict(
        id: wireIdentifier(json, 'id'),
        idempotencyKey: wireIdentifier(json, 'idempotency_key'),
        status: status,
        rewardStatus: reward,
        profileVersion: version as int?,
        code: json['code'] == null ? null : wireIdentifier(json, 'code'),
        retryable: json['retryable'] == true || status == 'retryable',
        certificateId: certificate,
        rewardReason: reason,
        xpAwarded: xp,
        studyPointsAwarded: study,
        cashMicrosAwarded: cash);
  }
  final String id, idempotencyKey, status, rewardStatus;
  final int? profileVersion;
  final String? code, certificateId, rewardReason;
  final bool retryable;
  final int xpAwarded, studyPointsAwarded, cashMicrosAwarded;
  Map<String, Object?> toJson() => {
        'id': id,
        'idempotency_key': idempotencyKey,
        'status': status,
        'reward_status': rewardStatus,
        if (profileVersion != null) 'profile_version': profileVersion,
        if (code != null) 'code': code,
        if (certificateId != null) 'certificate_id': certificateId,
        if (rewardReason != null) 'reward_reason': rewardReason,
        if (xpAwarded != 0) 'xp_awarded': xpAwarded,
        if (studyPointsAwarded != 0) 'study_points_awarded': studyPointsAwarded,
        if (cashMicrosAwarded != 0) 'cash_micros_awarded': cashMicrosAwarded,
        'retryable': retryable
      };
}

class ReceiptBatch {
  ReceiptBatch.fromJson(Map<String, Object?> json) {
    final raw = json['results'];
    if (raw is! List ||
        raw.length > 64 ||
        json['queue_depth_hint'] is! int ||
        (json['queue_depth_hint'] as int) < 0) {
      throw const FormatException('Invalid receipt batch');
    }
    results = List.unmodifiable(
        raw.map((r) => ReceiptVerdict.fromJson(r as Map<String, Object?>)));
    String? expected;
    for (final result in results) {
      if (result.retryable || result.status == 'retryable') break;
      expected = result.idempotencyKey;
    }
    if (json['cursor'] != expected)
      throw const FormatException('Batch cursor crossed an unresolved receipt');
    contiguousCursor = expected;
    queueDepthHint = json['queue_depth_hint'] as int;
  }
  late final List<ReceiptVerdict> results;
  late final String? contiguousCursor;
  late final int queueDepthHint;
}
