import 'dart:io';

import 'package:psychemas/psychemas.dart';
import 'package:psycore/psycore.dart';

import 'report.dart';

/// Showcase 3 — Session resolution, state model & pharmacology (Phase 2.3).
///
/// Demonstrates: the typed SimState trajectory over a scripted case, the
/// outcome engine (succeed/fail/stabilize/crisis/ongoing), lifecycle
/// transitions, byte-identical determinism of a full run, and the typed
/// fictional-pharmacology state (tolerance/dependency accrual).
void main() {
  final r = MarkdownReport(
    'Showcase 3 — Session Resolution, State Model & Pharmacology (2.3)',
    subtitle: 'Typed SimState trajectory · outcome engine · lifecycle · '
        'deterministic replay · fictional pharmacology',
  );

  final manifest = const ManifestLoader()
      .load(File('content/manifests/poc_sample.json').readAsBytesSync());
  final library = CardLibrary(
      ownedCardIds: manifest.resolvedCards.map((c) => c.id).toSet());
  final loadout = Loadout(
      cardIds: manifest.resolvedCards.map((c) => c.id).toList(), slotCap: 6);
  final actions = _cycle(manifest.interactionPatterns, 8);

  // 1. State trajectory.
  r.h2('1. Typed session-state trajectory over a scripted case');
  final outputs = const CoreRunPath().resolveScripted(
    rulesetVersion: '0.1.0',
    manifest: manifest,
    actions: actions,
    rootSeed: 20260715,
    clock: const InjectedClock.replay(1_700_000_000_000),
    loadout: loadout,
    library: library,
  );
  final rows = <List<String>>[];
  for (var i = 0; i < outputs.length; i++) {
    final s = outputs[i].nextState;
    rows.add([
      '${i + 1}',
      actions[i].toJson(),
      '${s.trustScore}',
      '${s.agitationLevel}',
      s.activeDefense.toJson(),
      '${s.freezeTurns}',
      '${s.sessionProgress}',
      outputs[i].outcome.toJson(),
      outputs[i].lifecycle.toJson(),
    ]);
  }
  r.table([
    'turn',
    'action',
    'trust',
    'agitation',
    'defense',
    'freeze',
    'progress',
    'outcome',
    'lifecycle'
  ], rows);

  // 2. Outcome + lifecycle coverage.
  r.h2('2. Outcome engine & lifecycle states reached');
  final outcomes = outputs.map((o) => o.outcome.toJson()).toSet().toList()
    ..sort();
  final lifecycles = outputs.map((o) => o.lifecycle.toJson()).toSet().toList()
    ..sort();
  r.bullet('outcomes observed: `${outcomes.join('`, `')}`');
  r.bullet('lifecycle states observed: `${lifecycles.join('`, `')}`');
  r.endBullets();

  // 3. Deterministic replay.
  r.h2('3. Full-run determinism');
  List<TurnOutput> run() => const CoreRunPath().resolveScripted(
        rulesetVersion: '0.1.0',
        manifest: manifest,
        actions: actions,
        rootSeed: 20260715,
        clock: const InjectedClock.replay(1_700_000_000_000),
        loadout: loadout,
        library: library,
      );
  final a = run();
  final b = run();
  var identical = a.length == b.length;
  for (var i = 0; i < a.length && identical; i++) {
    identical = _eq(
        a[i].nextState.toCanonicalBytes(), b[i].nextState.toCanonicalBytes());
  }
  r.bullet('${MarkdownReport.ok(identical)} two runs of the same '
      '(manifest, actions, seed) produce byte-identical state at every turn');
  r.endBullets();

  // 4. Fictional pharmacology (typed state).
  r.h2('4. Fictional pharmacology — typed tolerance / dependency accrual');
  r.p('The medication state is a typed part of `SimState`. Names are drawn from '
      'the fictional-taxonomy registry (0.12) and pass the no-real-label lint. '
      'Simulating repeated doses of `${FictionalDrug.values.first.toJson()}`:');
  var med = MedicationState(drug: FictionalDrug.values.first, dosage: 20);
  final medRows = <List<String>>[];
  for (var dose = 1; dose <= 5; dose++) {
    med = med.copyWith(
      tolerance: (med.tolerance + 2).clamp(0, 100),
      dependency: (med.dependency + 1).clamp(0, 100),
    );
    medRows.add([
      '$dose',
      med.drug!.toJson(),
      '${med.dosage}',
      '${med.tolerance}',
      '${med.dependency}',
    ]);
  }
  r.table(['dose #', 'drug', 'dosage', 'tolerance', 'dependency'], medRows);
  r.callout(
      'Medication shifts **dialogue delivery via the style filter — never '
      'the mechanical outcome** (§4). A persistent-memory case can inherit '
      'chemical dependency from its signed history (§17).');

  r.writeTo('$showcaseOutputDir/03-session.md');
}

List<InteractionPattern> _cycle(List<InteractionPattern> src, int n) =>
    [for (var i = 0; i < n; i++) src[i % src.length]];

bool _eq(List<int> a, List<int> b) {
  if (a.length != b.length) return false;
  for (var i = 0; i < a.length; i++) {
    if (a[i] != b[i]) return false;
  }
  return true;
}
