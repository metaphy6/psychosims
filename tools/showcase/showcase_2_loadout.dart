import 'dart:io';

import 'package:psychemas/psychemas.dart';
import 'package:psycore/psycore.dart';

import 'report.dart';

/// Showcase 2 — Therapy deck & loadout system (Phase 2.2).
///
/// Demonstrates: hard slot-cap + ownership enforcement, the deterministic
/// loadout-gap analyzer (a mismatched loadout leaves a readable gap), and the
/// focus / emotional-delivery controllers feeding core resolution.
void main() {
  final r = MarkdownReport(
    'Showcase 2 — Therapy Deck & Loadout System (2.2)',
    subtitle:
        'Slot cap + ownership · loadout-gap analysis · therapy controllers',
  );

  final manifest = const ManifestLoader()
      .load(File('content/manifests/poc_sample.json').readAsBytesSync());
  final ownedIds = manifest.resolvedCards.map((c) => c.id).toSet();

  // 1. Cap + ownership enforcement.
  r.h2('1. Hard slot-cap and card-ownership enforcement');
  final full = Loadout(cardIds: ownedIds.toList(), slotCap: 6);
  final overCap = Loadout(cardIds: ownedIds.toList(), slotCap: 2);
  final withUnowned =
      Loadout(cardIds: [...ownedIds, 'not_a_real_card'], slotCap: 8);
  r.table(
    ['loadout', 'cards', 'slot cap', 'within cap?', 'valid for library?'],
    [
      [
        'full owned set',
        '${full.cardIds.length}',
        '${full.slotCap}',
        MarkdownReport.ok(full.isWithinCap),
        MarkdownReport.ok(full.isValidForLibrary(ownedIds)),
      ],
      [
        'over cap',
        '${overCap.cardIds.length}',
        '${overCap.slotCap}',
        MarkdownReport.ok(overCap.isWithinCap),
        MarkdownReport.ok(overCap.isValidForLibrary(ownedIds)),
      ],
      [
        'contains unowned card',
        '${withUnowned.cardIds.length}',
        '${withUnowned.slotCap}',
        MarkdownReport.ok(withUnowned.isWithinCap),
        MarkdownReport.ok(withUnowned.isValidForLibrary(ownedIds)),
      ],
    ],
  );
  r.callout('The cap and ownership are enforced in the deterministic core, not '
      'only the UI — a receipt that references an un-equipped card is rejectable.');

  // 2. Loadout-gap analysis.
  r.h2('2. Loadout-gap analyzer — a mismatched loadout leaves a readable gap');
  const analyzer = LoadoutAnalyzer();
  final fullReport = analyzer.analyze(manifest, full);
  // Deficient loadout: keep only the first card.
  final deficient = Loadout(cardIds: [ownedIds.first], slotCap: 6);
  final deficientReport = analyzer.analyze(manifest, deficient);
  r.table(
    ['loadout', 'required signatures', 'present', 'missing', 'has gap?'],
    [
      [
        'full owned set',
        _sigs(fullReport.requiredSignatures),
        _sigs(fullReport.presentSignatures),
        _sigs(fullReport.missingSignatures),
        MarkdownReport.ok(fullReport.hasGap),
      ],
      [
        'only `${ownedIds.first}`',
        _sigs(deficientReport.requiredSignatures),
        _sigs(deficientReport.presentSignatures),
        _sigs(deficientReport.missingSignatures),
        MarkdownReport.ok(deficientReport.hasGap),
      ],
    ],
  );
  r.bullet('${MarkdownReport.ok(!fullReport.hasGap)} the full owned set covers '
      'the case with no gap');
  r.bullet('${MarkdownReport.ok(deficientReport.hasGap)} a one-card loadout '
      'leaves a measurable, readable tactical gap');
  r.endBullets();

  // 3. Controllers feed core resolution.
  r.h2('3. Focus & emotional-delivery controllers change resolution inputs');
  const resolver = TurnResolver(InjectedClock.replay(0));
  final library = CardLibrary(ownedCardIds: ownedIds);
  const state = SimState(
    seed: 20260715,
    trustScore: 45,
    agitationLevel: 55,
    activeDefense: DefenseState.guarded,
  );
  final action = manifest.interactionPatterns.first;
  final controllerSettings = <(String, TherapyControllerSettings)>[
    (
      'warm + childhood',
      const TherapyControllerSettings(
          focus: FocusAxis.childhood, emotionalDelivery: EmotionalDelivery.warm)
    ),
    ('balanced', const TherapyControllerSettings()),
    (
      'objective + workspace',
      const TherapyControllerSettings(
          focus: FocusAxis.workspace,
          emotionalDelivery: EmotionalDelivery.objective)
    ),
  ];
  r.p('Resolving `${action.toJson()}` from an identical state under different '
      'controller settings:');
  r.table(
    ['controllers', 'Δ trust', 'Δ agitation', 'context fit'],
    [
      for (final cs in controllerSettings)
        () {
          final out = resolver.resolve(TurnInput(
            rulesetVersion: '0.1.0',
            manifest: manifest,
            state: state,
            action: action,
            loadout: full,
            library: library,
            controllers: cs.$2,
          ));
          return [
            cs.$1,
            _fmt(_axisDelta(out, StateAxis.trust)),
            _fmt(_axisDelta(out, StateAxis.agitation)),
            out.deltas.isEmpty ? 'n/a' : out.deltas.first.contextFit.toJson(),
          ];
        }(),
    ],
  );
  r.callout('Controllers are typed core inputs — never free text — so the '
      'direct prompt-injection channel stays closed (0.12).');

  r.writeTo('$showcaseOutputDir/02-loadout.md');
}

String _sigs(List<CardSignature> s) =>
    s.isEmpty ? '—' : s.map((e) => e.toJson()).join(', ');

int _axisDelta(TurnOutput out, StateAxis axis) => out.deltas
    .where((d) => d.axis == axis)
    .fold(0, (s, d) => s + d.deltaMillis);

String _fmt(int delta) {
  final sign = delta > 0 ? '+' : '';
  return '$sign$delta';
}
