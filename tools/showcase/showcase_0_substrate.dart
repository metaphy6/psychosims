import 'dart:convert';
import 'dart:io';

import 'package:psychemas/psychemas.dart';
import 'package:psycore/psycore.dart';

import 'report.dart';

/// Showcase 0 — Deterministic core substrate (Phase 2.0).
///
/// Demonstrates: portable seeded PRNG determinism, pure per-turn seed
/// derivation, fixed-point money (ratio / percentage / conservation), one
/// canonical serializer with byte-identical output, the fully-injected clock
/// seam, and byte-identical golden replay through the pure core-only path.
void main() {
  final r = MarkdownReport(
    'Showcase 0 — Deterministic Core Substrate (2.0)',
    subtitle: 'Portable PRNG · seed derivation · fixed-point money · canonical '
        'serialization · injected clock · golden replay',
  );

  // 1. Portable PRNG determinism.
  r.h2('1. Portable integer PRNG is byte-identical for a fixed seed');
  final a = SeededPrng.forRuleset(42, '0.1.0');
  final b = SeededPrng.forRuleset(42, '0.1.0');
  final c = SeededPrng.forRuleset(43, '0.1.0');
  final rowsA = <List<String>>[];
  var sameAsB = true;
  var diffFromC = false;
  for (var i = 0; i < 8; i++) {
    final da = a.nextInt(1000);
    final db = b.nextInt(1000);
    final dc = c.nextInt(1000);
    if (da != db) sameAsB = false;
    if (da != dc) diffFromC = true;
    rowsA.add(['$i', '$da', '$db', '$dc']);
  }
  r.table(['draw #', 'seed 42', 'seed 42 (replay)', 'seed 43'], rowsA);
  r.bullet('${MarkdownReport.ok(sameAsB)} same seed → identical stream');
  r.bullet('${MarkdownReport.ok(diffFromC)} different seed → different stream');
  r.endBullets();

  // 2. Pure seed derivation over stable inputs only.
  r.h2('2. Per-turn seed derivation depends only on stable inputs');
  const profile = RulesetProfile.v0_1_0;
  int derive(String caseId, int turn, String action, int root) =>
      deriveTurnSeed(
        caseId: caseId,
        turnIndex: turn,
        actionName: action,
        rootSeed: root,
        profile: profile,
      );
  final s1 = derive('case-1', 3, 'open_question', 42);
  final s1b = derive('case-1', 3, 'open_question', 42);
  final s2 = derive('case-1', 4, 'open_question', 42);
  final s3 = derive('case-1', 3, 'validate', 42);
  r.table([
    'case id',
    'turn',
    'action',
    'root seed',
    'derived seed'
  ], [
    ['case-1', '3', 'open_question', '42', '$s1'],
    ['case-1', '3', 'open_question', '42', '$s1b (replay)'],
    ['case-1', '4', 'open_question', '42', '$s2'],
    ['case-1', '3', 'validate', '42', '$s3'],
  ]);
  r.bullet('${MarkdownReport.ok(s1 == s1b)} identical inputs → identical seed '
      '(no clock, no per-isolate hashCode)');
  r.bullet('${MarkdownReport.ok(s1 != s2 && s1 != s3)} turn index or action '
      'change → different seed');
  r.endBullets();

  // 3. Fixed-point money: ratio / percentage / conservation.
  r.h2('3. Fixed-point money — ratio, percentage, and conservation');
  final hundred = FixedPoint.fromWhole(100);
  final half = hundred.applyPercentage(5000); // 50%
  final third = hundred.applyPercentage(3333); // 33.33%
  final twoThirds = hundred.applyPercentage(6667); // 66.67%
  final remainder = hundred - third - twoThirds;
  r.table([
    'operation',
    'result'
  ], [
    ['FixedPoint.fromWhole(100)', hundred.toDouble().toStringAsFixed(4)],
    ['× 50% (5000 bp)', half.toDouble().toStringAsFixed(4)],
    ['× 33.33% (3333 bp)', third.toDouble().toStringAsFixed(4)],
    ['× 66.67% (6667 bp)', twoThirds.toDouble().toStringAsFixed(4)],
    ['100 − 33.33% − 66.67% (residue)', remainder.raw.toString() + ' raw'],
    [
      '÷ 3 (round-half-to-even)',
      hundred.divideBy(3).toDouble().toStringAsFixed(4)
    ],
  ]);
  final conserves = remainder.raw.abs() <= FixedPoint.scale;
  r.bullet('${MarkdownReport.ok(conserves)} splitting a value and recombining '
      'never mints or destroys more than one scale unit (ledger conservation)');
  r.endBullets();

  // 4. Canonical serialization — byte-identical, sorted snake_case.
  r.h2('4. One canonical serializer — byte-identical output');
  const state = SimState(
    seed: 7,
    turn: 2,
    trustScore: 55,
    agitationLevel: 40,
    activeDefense: DefenseState.guarded,
    trauma: 10,
  );
  final bytes1 = state.toCanonicalBytes();
  final bytes2 = state.toCanonicalBytes();
  final identical = _listEquals(bytes1, bytes2);
  r.bullet(
      '${MarkdownReport.ok(identical)} two encodings of the same state are '
      'byte-identical (${bytes1.length} bytes)');
  r.endBullets();
  r.p('Canonical JSON (sorted keys, single `snake_case` convention):');
  r.code(const JsonEncoder.withIndent('  ').convert(state.toJson()),
      lang: 'json');

  // 5. Injected clock seam.
  r.h2('5. Fully-injected clock — no wall-clock, advancing monotonic');
  const clock = InjectedClock(1_700_000_000_000, 1000);
  final advanced = advanceMonotonic(clock, 5000);
  const replay = InjectedClock.replay(1_700_000_000_000);
  r.table([
    'clock',
    'nowMillis()',
    'monotonicMillis()'
  ], [
    [
      'InjectedClock(epoch, 1000)',
      '${clock.nowMillis()}',
      '${clock.monotonicMillis()}'
    ],
    [
      'advanceMonotonic(+5000)',
      '${advanced.nowMillis()}',
      '${advanced.monotonicMillis()}'
    ],
    [
      'InjectedClock.replay(epoch)',
      '${replay.nowMillis()}',
      '${replay.monotonicMillis()}'
    ],
  ]);
  r.bullet('${MarkdownReport.ok(advanced.nowMillis() == clock.nowMillis())} '
      'advancing the monotonic source leaves authoritative time untouched');
  r.bullet('${MarkdownReport.ok(replay.monotonicMillis() == 0)} replay clock '
      'starts monotonic at 0 (time-independent replay)');
  r.endBullets();

  // 6. Golden replay through the pure core-only path.
  r.h2('6. Byte-identical golden replay (pure core-only path)');
  final manifest = _loadManifest('content/manifests/poc_sample.json');
  final actions = _cycle(manifest.interactionPatterns, 5);
  final library = CardLibrary(
      ownedCardIds: manifest.resolvedCards.map((c) => c.id).toSet());
  final loadout = Loadout(
      cardIds: manifest.resolvedCards.map((c) => c.id).toList(), slotCap: 6);
  List<TurnOutput> run() => const CoreRunPath().resolveScripted(
        rulesetVersion: '0.1.0',
        manifest: manifest,
        actions: actions,
        rootSeed: 20260715,
        clock: const InjectedClock.replay(1_700_000_000_000),
        loadout: loadout,
        library: library,
      );
  final runA = run();
  final runB = run();
  var allIdentical = runA.length == runB.length;
  for (var i = 0; i < runA.length && allIdentical; i++) {
    allIdentical =
        _listEquals(runA[i].toCanonicalBytes(), runB[i].toCanonicalBytes());
  }
  r.p('Ran a ${actions.length}-turn scripted case twice on case '
      '`${manifest.id}`; compared each turn\'s canonical outcome bytes:');
  r.bullet('${MarkdownReport.ok(allIdentical)} every turn replays '
      'byte-identically across two runs');
  r.endBullets();
  r.callout('Determinism scope: the pure core is byte-identical across '
      'architectures. Model *inference* is deliberately **not** claimed '
      'byte-identical across architectures (float matmul) — that is expected, '
      'not a defect.');

  r.writeTo('$showcaseOutputDir/00-substrate.md');
}

PatientManifest _loadManifest(String path) =>
    const ManifestLoader().load(File(path).readAsBytesSync());

List<InteractionPattern> _cycle(List<InteractionPattern> src, int n) =>
    [for (var i = 0; i < n; i++) src[i % src.length]];

bool _listEquals(List<int> a, List<int> b) {
  if (a.length != b.length) return false;
  for (var i = 0; i < a.length; i++) {
    if (a[i] != b[i]) return false;
  }
  return true;
}
