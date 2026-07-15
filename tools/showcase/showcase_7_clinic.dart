import 'package:psychemas/psychemas.dart';
import 'package:psycore/psycore.dart';

import 'report.dart';

/// Showcase 7 — Clinic operations, economy & the offline case router (2.7).
///
/// Demonstrates: atomic clinic transactions on the ledger, progressive taxes
/// and deterministic audits, the resumable offline case router (same seed +
/// cursor → same stream), and the three strategic-exit choices.
void main() {
  final r = MarkdownReport(
    'Showcase 7 — Clinic Operations, Economy & Case Router (2.7)',
    subtitle: 'atomic clinic ledger · progressive tax · deterministic audit · '
        'resumable router · strategic exits',
  );

  const clinic = ClinicEconomy(ClinicEconomyConfig());

  // 1. Atomic clinic transactions.
  r.h2('1. Rent / buy / sell as keyed, idempotent ledger events');
  var ledger = Ledger();
  final rent = clinic.rentOffice(
      officeId: 'o1', idempotencyKey: 'rent-1', timestampSeconds: 0);
  final buy = clinic.buyOffice(
      officeId: 'o1', idempotencyKey: 'buy-1', timestampSeconds: day);
  final sell = clinic.sellOffice(
      officeId: 'o1', idempotencyKey: 'sell-1', timestampSeconds: 2 * day);
  ledger = ledger.apply(rent).apply(buy).apply(sell);
  r.table(
    ['event', 'currency', 'amount (micros)'],
    [
      [rent.kind, rent.currency.toJson(), '${rent.amountMicros}'],
      [buy.kind, buy.currency.toJson(), '${buy.amountMicros}'],
      [sell.kind, sell.currency.toJson(), '${sell.amountMicros}'],
    ],
  );
  final beforeReplay = ledger.balance(CurrencyType.cash);
  ledger = ledger.apply(buy); // duplicate purchase — deduped by key
  r.bullet('net cash after rent+buy+sell: ${beforeReplay} micros '
      '(resale value = ${clinic.resaleValueMicros()})');
  r.bullet(
      '${MarkdownReport.ok(beforeReplay == ledger.balance(CurrencyType.cash))} '
      'a duplicated purchase applies exactly once (interrupted-write safe)');
  r.endBullets();

  // 2. Progressive taxes + deterministic audit.
  r.h2('2. Progressive taxes and a deterministic audit roll');
  r.table(
    ['taxable income (micros)', 'tax owed (micros)'],
    [
      for (final income in [10000000, 50000000, 150000000])
        ['$income', '${clinic.taxOwedMicros(income)}'],
    ],
  );
  final auditedLow = clinic.audit(rollMillis: 10, overmedicationDeltaCount: 4);
  final auditedHigh =
      clinic.audit(rollMillis: 900, overmedicationDeltaCount: 4);
  r.table(
    ['audit roll (millis)', 'audited?', 'reputation penalty'],
    [
      ['10', MarkdownReport.ok(auditedLow.$1), '${auditedLow.$2}'],
      ['900', MarkdownReport.ok(auditedHigh.$1), '${auditedHigh.$2}'],
    ],
  );
  r.callout('Audits deterministically read the medication/outcome history — an '
      'over-medication record penalises reputation (§22).');

  // 3. Resumable offline case router.
  r.h2('3. Deterministic, resumable offline case router');
  const router = OfflineCaseRouter(OfflineCaseRouterConfig());
  const profile = CareerProfile(profileId: 'showcase', rulesetVersion: '0.1.0');
  List<CaseRouterSeed> stream() => [
        for (var cursor = 0; cursor < 6; cursor++)
          router.nextCase(
            profile: profile,
            tierBias: 2,
            playerLevel: 8,
            cursor: cursor,
            rootSeed: 20260715,
          ),
      ];
  final first = stream();
  final second = stream();
  r.table(
    ['cursor', 'tier', 'memory_class', 'misfortune?'],
    [
      for (final c in first)
        [
          '${c.cursor}',
          '${c.tier}',
          c.memoryClass.toJson(),
          MarkdownReport.ok(c.misfortune)
        ],
    ],
  );
  var resumable = first.length == second.length;
  for (var i = 0; i < first.length && resumable; i++) {
    resumable = first[i].tier == second[i].tier &&
        first[i].memoryClass == second[i].memoryClass &&
        first[i].misfortune == second[i].misfortune &&
        first[i].seed == second[i].seed;
  }
  r.bullet(
      '${MarkdownReport.ok(resumable)} a restart regenerates the identical '
      'case stream from the persisted seed + cursor (never re-rolled)');
  r.endBullets();

  // 4. Strategic exits.
  r.h2('4. Strategic-exit choices for an over-matched case');
  const exit = StrategicExitResolver();
  r.table(
    ['choice', 'Δ xp', 'Δ reputation', 'Δ agitation', 'case lost?'],
    [
      for (final choice in StrategicExitChoice.values)
        () {
          final res = exit.resolve(choice);
          return [
            choice.name,
            '${res.xpDelta}',
            '${res.reputationDelta}',
            '${res.agitationDelta}',
            MarkdownReport.ok(res.caseLost),
          ];
        }(),
    ],
  );
  r.callout(
      'Reject returns the case to the pool with no penalty; refer grants a '
      'small ethical XP reward; force risks an agitation spike and reputation '
      'hit — so a player is never trapped by the chaos roll (§13).');

  r.writeTo('$showcaseOutputDir/07-clinic.md');
}

const int day = 24 * 60 * 60;
