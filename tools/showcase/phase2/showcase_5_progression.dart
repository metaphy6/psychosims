import 'package:psychemas/psychemas.dart';
import 'package:psycore/psycore.dart';

import '../report.dart';

/// Showcase 5 — Progression, multi-currency economy & attraction (2.5).
///
/// Demonstrates: the difficulty→XP curve with grind penalty, event-sourced
/// recency-weighted reputation with a credential floor, the append-only
/// idempotent multi-currency ledger with conservation + compaction, the study
/// unlock path, the attraction vector, and the onboarding track.
void main() {
  final r = MarkdownReport(
    'Showcase 5 — Progression, Economy & Attraction (2.5)',
    subtitle: 'difficulty→XP · reputation decay · idempotent ledger · study '
        'unlocks · attraction vector · onboarding',
  );

  // 1. Difficulty → XP curve.
  r.h2('1. Difficulty→XP curve — harder is worth proportionally more');
  const xp = XpCurve(XpCurveConfig());
  r.table(
    ['difficulty tier', 'XP (first play)'],
    [
      for (var t = 1; t <= 5; t++)
        ['$t', '${xp.reward(difficultyTier: t, sessionCount: 0)}']
    ],
  );
  r.h3('Trivial-grind diminishing returns (tier 1, repeated)');
  r.table(
    ['prior plays at tier', 'XP'],
    [
      for (var n = 0; n <= 8; n += 2)
        ['$n', '${xp.reward(difficultyTier: 1, sessionCount: n)}']
    ],
  );

  // 2. Reputation decay.
  r.h2('2. Event-sourced, recency-weighted reputation with a credential floor');
  const rep = ReputationDecay(ReputationDecayConfig());
  const day = 24 * 60 * 60;
  final events = [
    const ReputationEvent(amountMillis: 400000, timestampSeconds: 0),
    ReputationEvent(amountMillis: 300000, timestampSeconds: 14 * day),
    ReputationEvent(amountMillis: 200000, timestampSeconds: 27 * day),
  ];
  r.table(
    ['evaluated at', 'unlocked fields', 'reputation (millis)'],
    [
      for (final now in [0, 7 * day, 14 * day, 28 * day])
        [
          'day ${now ~/ day}',
          '3',
          '${rep.reputationAt(events: events, unlockedFieldCount: 3, nowSeconds: now)}',
        ],
    ],
  );
  r.callout(
      'Recency uses the injected clock (not the device clock); decay is an '
      'integer table (no float `exp`) so reputation replays byte-identically.');

  // 3. Multi-currency ledger.
  r.h2('3. Append-only, idempotent multi-currency ledger');
  var ledger = Ledger();
  final fee = LedgerEvent(
    kind: 'session_fee',
    idempotencyKey: 'fee-1',
    timestampSeconds: 0,
    currency: CurrencyType.cash,
    amountMicros: 1500000,
    reasonKey: 'ledger.session.fee',
  );
  final study = LedgerEvent(
    kind: 'study_earn',
    idempotencyKey: 'study-1',
    timestampSeconds: 0,
    currency: CurrencyType.study,
    amountMicros: 250000,
    reasonKey: 'ledger.study.earn',
  );
  ledger = ledger.apply(fee).apply(study);
  final cashAfterOne = ledger.balance(CurrencyType.cash);
  // Re-apply the same fee event: idempotency key dedupes it.
  ledger = ledger.apply(fee);
  final cashAfterReplay = ledger.balance(CurrencyType.cash);
  r.table(
    ['currency', 'balance (micros)'],
    [
      for (final e in ledger.balances().entries) [e.key.toJson(), '${e.value}']
    ],
  );
  r.bullet(
      '${MarkdownReport.ok(cashAfterOne == cashAfterReplay)} re-applying an '
      'event with the same idempotency key is a no-op (exactly-once)');
  final snapshot = ledger.compact();
  r.bullet(
      '${MarkdownReport.ok(snapshot.events.isEmpty)} `compact()` checkpoints '
      'balances and truncates the event tail (bounded save over a long career)');
  r.endBullets();

  // 4. Study unlock path.
  r.h2('4. Study → target-card acquisition path');
  final catalog = StudyCatalog([
    const StudyUnlockEntry(
        cardId: 'bulls_eye',
        studyCost: 300,
        subspecialtyCost: 0,
        fieldKey: 'field.brumosis'),
  ]);
  const spend = StudySpend();
  final poor = spend.unlock(
      catalog: catalog,
      cardId: 'bulls_eye',
      studyPoints: 100,
      subspecialtyPoints: 0,
      unlockedCardIds: {});
  final rich = spend.unlock(
      catalog: catalog,
      cardId: 'bulls_eye',
      studyPoints: 500,
      subspecialtyPoints: 0,
      unlockedCardIds: {});
  r.table(
    ['attempt', 'study points', 'status', 'remaining study'],
    [
      ['under-funded', '100', poor.status.name, '${poor.remainingStudy}'],
      ['funded', '500', rich.status.name, '${rich.remainingStudy}'],
    ],
  );

  // 5. Attraction vector.
  r.h2('5. Patient-attraction vector (UI readout, not the router)');
  const attraction = AttractionVector(AttractionVectorConfig());
  r.table(
    ['reputation', 'unlocked/total fields', 'attraction (0–1000 millis)'],
    [
      for (final rep in [200, 500, 850])
        [
          '$rep',
          '6/20',
          '${attraction.score(reputation: rep, maxPrice: 300, unlockedFields: 6, totalFields: 20)}',
        ],
    ],
  );

  // 6. Onboarding track.
  r.h2('6. New Clinician onboarding track');
  const onboarding = OnboardingTrack(OnboardingConfig());
  r.bullet('can play tier 1 while onboarding: '
      '${MarkdownReport.ok(onboarding.canPlayTier(1))}');
  r.bullet('softened penalty (raw 100 → ${onboarding.softenedPenalty(100)}) — '
      'teach-don\'t-punish early failure');
  r.bullet('graduates after 3 completed cases: '
      '${MarkdownReport.ok(onboarding.shouldGraduate(3))}');
  r.endBullets();

  r.writeTo('$showcaseOutputDir/phase2/05-progression.md');
}
