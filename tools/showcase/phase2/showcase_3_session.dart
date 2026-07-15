import 'dart:io';

import 'package:psychemas/psychemas.dart';
import 'package:psycore/psycore.dart';

import '../report.dart';

/// Showcase 3 — Session resolution, state model & pharmacology (Phase 2.3).
///
/// Demonstrates: a full case resolved end-to-end to a terminal outcome, the
/// typed SimState trajectory (trust/agitation moving turn by turn), the outcome
/// engine reaching every band (crisis/fail/stabilize/succeed/ongoing) with
/// lifecycle transitions, byte-identical determinism of the full run, and the
/// typed fictional-pharmacology state (tolerance/dependency accrual).
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
  // A calming-biased script (validate builds trust, set_boundary lowers
  // agitation) so the case reaches its cure cleanly. Every turn advances
  // session progress by one step regardless of the card played (§15).
  final patterns = <InteractionPattern>[
    InteractionPattern.validate,
    InteractionPattern.setBoundary,
    InteractionPattern.openQuestion,
  ];
  final startState = SimState.fromInitialState(20260715, manifest.initialState);

  // 1. Full case arc — run end-to-end to a terminal outcome.
  r.h2('1. A case run end-to-end to a terminal outcome');
  r.p('Resolving the case from its initial state, turn by turn, until it '
      'reaches a terminal outcome. The case is `cured` once session progress '
      'crosses the success threshold — trust and agitation move each turn along '
      'the way. (Long trajectory truncated to the opening and closing turns.)');
  final arc = _runToTerminal(
    manifest: manifest,
    library: library,
    loadout: loadout,
    patterns: patterns,
    startState: startState,
    maxTurns: 200,
  );
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
  ], _trajectoryRows(arc, patterns));
  final last = arc.last;
  r.bullet('${MarkdownReport.ok(last.isTerminal)} the case reaches a terminal '
      'outcome after ${arc.length} turns: `${last.outcome.toJson()}` / '
      'lifecycle `${last.lifecycle.toJson()}`');
  r.endBullets();

  // 2. Outcome engine — every terminal band is reachable.
  r.h2('2. Outcome engine — all outcome bands are reachable');
  final observedOutcomes = arc.map((o) => o.outcome.toJson()).toSet().toList()
    ..sort();
  final observedLifecycles =
      arc.map((o) => o.lifecycle.toJson()).toSet().toList()..sort();
  r.bullet(
      'across the arc above — outcomes: `${observedOutcomes.join('`, `')}`');
  r.bullet('across the arc above — lifecycles: '
      '`${observedLifecycles.join('`, `')}`');
  r.endBullets();
  r.p('Each outcome band is a pure function of the resolved state. Driving a '
      'single turn from a crafted state reaches every band deterministically:');
  const engine = TurnResolver(InjectedClock.replay(0));
  TurnOutput oneShot(SimState s, InteractionPattern a) =>
      engine.resolve(TurnInput(
        rulesetVersion: '0.1.0',
        manifest: manifest,
        state: s,
        action: a,
        loadout: loadout,
        library: library,
      ));
  r.table([
    'crafted condition',
    'outcome',
    'lifecycle',
    'terminal?'
  ], [
    _outcomeRow(
      'agitation ≥ crisis threshold',
      oneShot(
        const SimState(
            seed: 1,
            trustScore: 30,
            agitationLevel: 78,
            activeDefense: DefenseState.guarded),
        InteractionPattern.reframe,
      ),
    ),
    _outcomeRow(
      'agitation ≥ walkout threshold',
      oneShot(
        const SimState(
            seed: 2,
            trustScore: 30,
            agitationLevel: 94,
            activeDefense: DefenseState.guarded),
        InteractionPattern.reframe,
      ),
    ),
    _outcomeRow(
      'calm + trust floor met',
      oneShot(
        const SimState(
            seed: 3,
            trustScore: 50,
            agitationLevel: 20,
            activeDefense: DefenseState.guarded),
        InteractionPattern.validate,
      ),
    ),
    _outcomeRow(
      'session progress ≥ success threshold',
      oneShot(
        const SimState(
            seed: 4,
            trustScore: 50,
            agitationLevel: 45,
            activeDefense: DefenseState.guarded,
            sessionProgress: 99),
        InteractionPattern.validate,
      ),
    ),
  ]);

  // 3. Deterministic replay.
  r.h2('3. Full-run determinism');
  List<TurnOutput> run() => _runToTerminal(
        manifest: manifest,
        library: library,
        loadout: loadout,
        patterns: patterns,
        startState: startState,
        maxTurns: 200,
      );
  final a = run();
  final b = run();
  var identical = a.length == b.length;
  for (var i = 0; i < a.length && identical; i++) {
    identical = _eq(
        a[i].nextState.toCanonicalBytes(), b[i].nextState.toCanonicalBytes());
  }
  r.bullet('${MarkdownReport.ok(identical)} two runs of the same '
      '(manifest, actions, seed) produce byte-identical state at every one of '
      'the ${a.length} turns');
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

  r.writeTo('$showcaseOutputDir/phase2/03-session.md');
}

List<TurnOutput> _runToTerminal({
  required PatientManifest manifest,
  required CardLibrary library,
  required Loadout loadout,
  required List<InteractionPattern> patterns,
  required SimState startState,
  required int maxTurns,
}) {
  const resolver = TurnResolver(InjectedClock.replay(1_700_000_000_000));
  final outputs = <TurnOutput>[];
  var state = startState;
  for (var i = 0; i < maxTurns; i++) {
    final out = resolver.resolve(TurnInput(
      rulesetVersion: '0.1.0',
      manifest: manifest,
      state: state,
      action: patterns[i % patterns.length],
      loadout: loadout,
      library: library,
    ));
    outputs.add(out);
    state = out.nextState;
    if (out.isTerminal) break;
  }
  return outputs;
}

/// Renders the trajectory, truncating long runs to the first and last 6 turns.
List<List<String>> _trajectoryRows(
    List<TurnOutput> arc, List<InteractionPattern> patterns) {
  List<String> rowFor(int i) {
    final s = arc[i].nextState;
    return [
      '${i + 1}',
      patterns[i % patterns.length].toJson(),
      '${s.trustScore}',
      '${s.agitationLevel}',
      s.activeDefense.toJson(),
      '${s.freezeTurns}',
      '${s.sessionProgress}',
      arc[i].outcome.toJson(),
      arc[i].lifecycle.toJson(),
    ];
  }

  if (arc.length <= 12) {
    return [for (var i = 0; i < arc.length; i++) rowFor(i)];
  }
  return [
    for (var i = 0; i < 6; i++) rowFor(i),
    List<String>.filled(9, '…'),
    for (var i = arc.length - 6; i < arc.length; i++) rowFor(i),
  ];
}

List<String> _outcomeRow(String label, TurnOutput o) => [
      label,
      o.outcome.toJson(),
      o.lifecycle.toJson(),
      MarkdownReport.ok(o.isTerminal),
    ];

bool _eq(List<int> a, List<int> b) {
  if (a.length != b.length) return false;
  for (var i = 0; i < a.length; i++) {
    if (a[i] != b[i]) return false;
  }
  return true;
}
