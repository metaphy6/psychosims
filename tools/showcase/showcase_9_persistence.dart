import 'dart:io';

import 'package:psychemas/psychemas.dart';
import 'package:psycore/psycore.dart';

import 'report.dart';

/// Showcase 9 — Offline persistence, career profile & save integrity (2.9).
///
/// Demonstrates the durable-save *schema* discipline that survives a restart:
/// the atomic-metric career profile (snapshot + compacted event tail), and
/// byte-stable round-trips of the receipt and session-start-state through the
/// one canonical serializer. (The atomic write-temp→fsync→rename itself is the
/// app-level 0.9 storage seam; here we exercise the pure, testable schema half.)
void main() {
  final r = MarkdownReport(
    'Showcase 9 — Offline Persistence & Save Integrity (2.9)',
    subtitle: 'atomic-metric career profile · canonical round-trips · '
        'ledger compaction shape',
  );

  // 1. Career profile — atomic metrics only, snapshot + event tail.
  r.h2('1. Career profile — the <0.5 KB atomic-metric precursor');
  final profile = CareerProfile(
    profileId: 'showcase',
    rulesetVersion: '0.1.0',
    snapshotBalancesMicros: const {
      'cash': 12500000,
      'study': 800000,
      'xp': 4520000,
      'reputation': 610000,
    },
    snapshotTimestampSeconds: 1_700_000_000,
    eventTail: [
      const LedgerEvent(
        kind: 'session_fee',
        idempotencyKey: 'fee-42',
        timestampSeconds: 1_700_000_500,
        currency: CurrencyType.cash,
        amountMicros: 1500000,
        reasonKey: 'ledger.session.fee',
      ),
    ],
    unlockedFields: const ['field.brumosis', 'field.torpida'],
    isOnboarding: false,
  );
  final restored = CareerProfile.fromJson(profile.toJson());
  final profileStable = CanonicalJson.encodeString(profile.toJson()) ==
      CanonicalJson.encodeString(restored.toJson());
  final sizeBytes = CanonicalJson.encode(profile.toJson()).length;
  r.bullet('${MarkdownReport.ok(profileStable)} profile survives a '
      'serialize → deserialize round-trip byte-identically');
  r.bullet('${MarkdownReport.ok(sizeBytes < 512)} canonical size = $sizeBytes '
      'bytes (< 0.5 KB primitive-payload budget)');
  r.bullet('carries a balances snapshot + a compacted event tail '
      '(${profile.eventTail.length} event) — bounded over a long career');
  r.endBullets();

  // 2. Receipt canonical byte-identity.
  r.h2('2. Session receipt — byte-identical canonical encoding');
  final manifest = const ManifestLoader()
      .load(File('content/manifests/poc_sample.json').readAsBytesSync());
  SessionReceipt buildReceipt() => SessionReceipt(
        id: 'r-1',
        rulesetVersion: '0.1.0',
        patientId: manifest.id,
        idempotencyKey: 'idem-1',
        correlationId: 'corr-1',
        turnCount: 1,
        startState:
            SimState.fromInitialState(1, manifest.initialState).toJson(),
        actions: [manifest.interactionPatterns.first],
        deltas: const [],
      );
  final identical =
      _eq(buildReceipt().toCanonicalBytes(), buildReceipt().toCanonicalBytes());
  r.bullet('${MarkdownReport.ok(identical)} two receipts built from identical '
      'inputs encode to byte-identical canonical bytes (checksum/signature-ready '
      'for Phase 3.3)');
  r.bullet('receipt carries its own idempotency key + correlation id — the '
      'exactly-once submission contract precursor (Phase 3.4)');
  r.endBullets();

  // 3. Session start-state round-trip.
  r.h2('3. Session start-state round-trip');
  final startState = SessionStartState(
    loadout: Loadout(
        cardIds: manifest.resolvedCards.map((c) => c.id).toList(), slotCap: 6),
    library: CardLibrary(
        ownedCardIds: manifest.resolvedCards.map((c) => c.id).toSet()),
    controllers: const TherapyControllerSettings(),
    initialAxes: manifest.initialState,
    rootSeed: 20260715,
  );
  final startRoundTrip = _eq(
    startState.toCanonicalBytes(),
    SessionStartState.fromJson(startState.toJson()).toCanonicalBytes(),
  );
  r.bullet('${MarkdownReport.ok(startRoundTrip)} the equipped loadout + '
      'controllers + seed round-trip byte-identically — the receipt-forgery '
      'guard (no play may reference an un-equipped card) is preserved on reload');
  r.endBullets();
  r.callout('No raw dialogue transcript is ever persisted (0.6) — the durable '
      'save is structured, checksum-guarded deltas only, even offline.');

  r.writeTo('$showcaseOutputDir/09-persistence.md');
}

bool _eq(List<int> a, List<int> b) {
  if (a.length != b.length) return false;
  for (var i = 0; i < a.length; i++) {
    if (a[i] != b[i]) return false;
  }
  return true;
}
