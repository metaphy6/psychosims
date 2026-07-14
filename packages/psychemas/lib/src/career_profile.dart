import 'canonical_json.dart';
import 'ledger_event.dart';

/// Persisted offline career state (Phase 2.9 precursor).
///
/// Holds the append-only ledger event stream plus a checksum-guarded snapshot
/// so replay time stays bounded. The same event stream later feeds server-side
/// validation (Phase 5.1) without reshaping.
class CareerProfile {
  /// Player-facing career id.
  final String profileId;

  /// Current ruleset version under which this profile was last mutated.
  final String rulesetVersion;

  /// Snapshot of replayed balances at [snapshotTimestampSeconds].
  final Map<String, int> snapshotBalancesMicros;

  /// Timestamp of the last snapshot boundary.
  final int snapshotTimestampSeconds;

  /// Events after the snapshot tail.
  final List<LedgerEvent> eventTail;

  /// Fields unlocked in the training tree.
  final List<String> unlockedFields;

  /// Whether the profile is in New Clinician safe-practice mode.
  final bool isOnboarding;

  const CareerProfile({
    required this.profileId,
    required this.rulesetVersion,
    this.snapshotBalancesMicros = const {},
    this.snapshotTimestampSeconds = 0,
    this.eventTail = const [],
    this.unlockedFields = const [],
    this.isOnboarding = true,
  });

  CareerProfile copyWith({
    String? profileId,
    String? rulesetVersion,
    Map<String, int>? snapshotBalancesMicros,
    int? snapshotTimestampSeconds,
    List<LedgerEvent>? eventTail,
    List<String>? unlockedFields,
    bool? isOnboarding,
  }) {
    return CareerProfile(
      profileId: profileId ?? this.profileId,
      rulesetVersion: rulesetVersion ?? this.rulesetVersion,
      snapshotBalancesMicros:
          snapshotBalancesMicros ?? this.snapshotBalancesMicros,
      snapshotTimestampSeconds:
          snapshotTimestampSeconds ?? this.snapshotTimestampSeconds,
      eventTail: eventTail ?? this.eventTail,
      unlockedFields: unlockedFields ?? this.unlockedFields,
      isOnboarding: isOnboarding ?? this.isOnboarding,
    );
  }

  Map<String, Object?> toJson() => {
        'profile_id': profileId,
        'ruleset_version': rulesetVersion,
        'snapshot_balances_micros': snapshotBalancesMicros,
        'snapshot_timestamp_seconds': snapshotTimestampSeconds,
        'event_tail': eventTail.map((e) => e.toJson()).toList(),
        'unlocked_fields': unlockedFields.toList(),
        'is_onboarding': isOnboarding,
      };

  factory CareerProfile.fromJson(Map<String, Object?> json) {
    return CareerProfile(
      profileId: json['profile_id']! as String,
      rulesetVersion: json['ruleset_version']! as String,
      snapshotBalancesMicros:
          (json['snapshot_balances_micros']! as Map<String, dynamic>)
              .cast<String, int>(),
      snapshotTimestampSeconds: json['snapshot_timestamp_seconds']! as int,
      eventTail: (json['event_tail']! as List<dynamic>)
          .cast<Map<String, Object?>>()
          .map(LedgerEvent.fromJson)
          .toList(),
      unlockedFields:
          (json['unlocked_fields']! as List<dynamic>).cast<String>().toList(),
      isOnboarding: json['is_onboarding']! as bool,
    );
  }

  List<int> toCanonicalBytes() => CanonicalJson.encode(toJson());
}
