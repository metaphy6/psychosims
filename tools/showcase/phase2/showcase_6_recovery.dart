import 'package:psychemas/psychemas.dart';
import 'package:psycore/psycore.dart';

import '../report.dart';

/// Showcase 6 — Financial stabilizers, operational pressure & recovery (2.6).
///
/// Demonstrates: the two anti-bankruptcy recovery paths, the visible
/// operational-pressure model (healthy/strained/at-risk), and the cooldown
/// tracker gated on the monotonic source (device-clock-tamper resistant).
void main() {
  final r = MarkdownReport(
    'Showcase 6 — Financial Stabilizers, Pressure & Recovery (2.6)',
    subtitle:
        'Discount Practice · Academic Sabbatical · operational pressure · '
        'tamper-resistant cooldowns',
  );

  const controller = RecoveryController(RecoveryControllerConfig());

  // 1. Recovery paths.
  r.h2('1. Two designed recovery paths restore a playable state');
  final lowRep = 15; // below the discount-practice threshold
  final canDiscount = controller.canEnterDiscountPractice(
      reputation: lowRep, currentMode: RecoveryMode.normal);
  final afterDiscount = controller.enterMode(
      target: RecoveryMode.discountPractice,
      currentMode: RecoveryMode.normal,
      reputation: lowRep);
  final canSabbatical =
      controller.canEnterSabbatical(currentMode: RecoveryMode.normal);
  final afterSabbatical = controller.enterMode(
      target: RecoveryMode.academicSabbatical,
      currentMode: RecoveryMode.normal,
      reputation: lowRep);
  r.table(
    ['path', 'entry allowed?', 'resulting mode', 'effect'],
    [
      [
        'Discount Practice',
        MarkdownReport.ok(canDiscount),
        afterDiscount.toJson(),
        'XP 100 → ${controller.discountedXp(100)} (reduced), floods casual cases',
      ],
      [
        'Academic Sabbatical',
        MarkdownReport.ok(canSabbatical),
        afterSabbatical.toJson(),
        'reputation floor for 8 fields → ${controller.sabbaticalReputationFloor(8)}',
      ],
    ],
  );
  r.callout(
      'Neither path is a pay-to-win shortcut — Discount Practice trades XP '
      'rate for volume; Academic Sabbatical trades earnings-downtime for a '
      'credential-based reputation floor.');

  // 2. Operational pressure.
  r.h2('2. Visible operational pressure — healthy / strained / at-risk');
  const pressureCalc = PressureCalculator(PressureCalculatorConfig());
  const day = 24 * 60 * 60;
  var pressure = const OperationalPressure();
  final rows = <List<String>>[];
  for (var session = 1; session <= 6; session++) {
    pressure = pressureCalc.afterSession(
      current: pressure,
      caseTier: session.isEven ? 4 : 1,
      nowSeconds: session * 3600,
    );
    rows.add([
      '$session',
      session.isEven ? '4 (high)' : '1',
      '${pressure.valueMillis}',
      pressure.category.name,
    ]);
  }
  r.table(['session', 'case tier', 'pressure (millis)', 'category'], rows);
  final decayed =
      pressureCalc.decay(current: pressure, nowSeconds: 6 * 3600 + 3 * day);
  r.bullet('after 3 days of rest, pressure decays '
      '${pressure.valueMillis} → ${decayed.valueMillis} millis '
      '(${decayed.category.name})');
  r.endBullets();
  r.callout(
      'Operational pressure is computed from the same accepted-delta inputs '
      'the Phase 5.5 server derivation will use — no hidden well-being stat (§23).');

  // 3. Tamper-resistant cooldown.
  r.h2('3. Recovery-window cooldown on the monotonic source');
  const cooldownSeconds = 24 * 60 * 60;
  final cooldown = const CooldownTracker()
      .start(nowSeconds: 0, durationSeconds: cooldownSeconds);
  r.table(
    ['elapsed (monotonic secs)', 'ready?', 'remaining (secs)'],
    [
      [
        '0',
        MarkdownReport.ok(cooldown.isReady(0)),
        '${cooldown.remainingSeconds(0)}'
      ],
      [
        '${cooldownSeconds ~/ 2}',
        MarkdownReport.ok(cooldown.isReady(cooldownSeconds ~/ 2)),
        '${cooldown.remainingSeconds(cooldownSeconds ~/ 2)}'
      ],
      [
        '$cooldownSeconds',
        MarkdownReport.ok(cooldown.isReady(cooldownSeconds)),
        '${cooldown.remainingSeconds(cooldownSeconds)}'
      ],
    ],
  );
  r.callout(
      'The cooldown advances only with genuine elapsed (monotonic) time — '
      'winding the untrusted device clock forward cannot skip it (0.8 '
      'authoritative-time seam).');

  r.writeTo('$showcaseOutputDir/phase2/06-recovery.md');
}
