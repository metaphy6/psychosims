import 'dart:io';

import 'package:psychemas/psychemas.dart';
import 'package:psycore/psycore.dart';

import '../report.dart';

/// Showcase 8 — Balance sandbox, solvability oracle & bot simulation (2.8).
///
/// Demonstrates: mechanical solvability + content compliance for every case in
/// the corpus, and a headless bot sweep across skill levels emitting win-rate
/// distributions, currency flow, dead-currency / inflation flags, and
/// throughput — all with no LLM and no model binary present.
void main() {
  final r = MarkdownReport(
    'Showcase 8 — Balance Sandbox, Solvability & Bot Simulation (2.8)',
    subtitle: 'per-manifest solvability · bot sweep · win-rate distributions · '
        'economy flags · throughput',
  );

  const oracle = SolvabilityOracle();
  const loader = ManifestLoader();
  final manifests = <PatientManifest>[];

  r.h2('1. Corpus solvability & content compliance (no model binary)');
  final compRows = <List<String>>[];
  for (final entity in Directory('content/manifests').listSync()) {
    if (entity is! File || !entity.path.endsWith('.json')) continue;
    final manifest = loader.load(entity.readAsBytesSync());
    manifests.add(manifest);
    final proof = oracle.analyze(manifest);
    compRows.add([
      manifest.id,
      manifest.memoryClass.toJson(),
      proof.status.name,
      '${proof.actions.length}',
      '${proof.exploredTransitions}',
      MarkdownReport.ok(oracle.isContentCompliant(manifest)),
    ]);
  }
  r.table([
    'case id',
    'memory_class',
    'search result',
    'winning turns',
    'transitions searched',
    'content-compliant?'
  ], compRows);
  r.callout(
      'A solved result has a replayable winning action sequence for seed 42. '
      'Search uses at most 120 turns and 20,000 transitions; other results are '
      'unproven within those bounds, not a claim of universal impossibility.');

  // 2. Bot sweep.
  r.h2('2. Bot sweep across skill levels');
  final scenarios = <SandboxScenarioConfig>[];
  for (final manifest in manifests) {
    final library = CardLibrary(
        ownedCardIds: manifest.resolvedCards.map((c) => c.id).toSet());
    final loadout = Loadout(
        cardIds: manifest.resolvedCards.map((c) => c.id).toList(), slotCap: 6);
    for (final skill in BotSkill.values) {
      for (var seed = 1; seed <= 12; seed++) {
        scenarios.add(SandboxScenarioConfig(
          manifest: manifest,
          bot: BotPlayer(id: '${manifest.id}:${skill.toJson()}', skill: skill),
          loadout: loadout,
          library: library,
          rootSeed: seed,
        ));
      }
    }
  }
  final sandbox = BalanceSandbox(
    runner: const ScenarioRunner(
        rulesetVersion: '0.1.0', clock: InjectedClock.replay(0)),
    scenarios: scenarios,
  );
  final sw = Stopwatch()..start();
  final report = sandbox.runSweep();
  sw.stop();
  final secs = sw.elapsedMilliseconds / 1000;
  final sps = secs > 0 ? (report.totalRuns / secs) : double.infinity;

  r.bullet(
      'total runs: ${report.totalRuns} · total turns: ${report.totalTurns}');
  r.bullet('overall win rate: ${_bp(report.overallWinRateBasisPoints)}');
  r.bullet('throughput: ${sps.toStringAsFixed(0)} sessions/sec '
      '(${(secs * 1000).toStringAsFixed(0)} ms)');
  r.endBullets();

  r.h3('Win-rate distribution by bot skill');
  r.table(
    [
      'skill',
      'runs',
      'win rate',
      'median turns',
      'p95 turns',
      'median progress'
    ],
    [
      for (final e in report.bySkill.entries)
        [
          e.key.toJson(),
          '${e.value.count}',
          _bp(e.value.winRateBasisPoints),
          '${e.value.medianTurns}',
          '${e.value.p95Turns}',
          '${e.value.medianProgress}',
        ],
    ],
  );

  r.h3('By case');
  r.table(
    ['case id', 'runs', 'win rate', 'median turns', 'p95 turns'],
    [
      for (final e in report.byManifest.entries)
        [
          e.key,
          '${e.value.count}',
          _bp(e.value.winRateBasisPoints),
          '${e.value.medianTurns}',
          '${e.value.p95Turns}',
        ],
    ],
  );

  r.h2('3. Economy health checks');
  r.table(
    ['currency', 'net flow (micros)'],
    [
      for (final e in report.netCurrencyFlowMicros.entries)
        [e.key.toJson(), '${e.value}'],
    ],
  );
  r.bullet('${MarkdownReport.ok(report.inflationFlag == null)} no runaway '
      'inflation flag${report.inflationFlag == null ? '' : ' (${report.inflationFlag})'}');
  r.bullet('${MarkdownReport.ok(report.deadCurrencyFlags.isEmpty)} '
      'dead-currency flags: ${report.deadCurrencyFlags.length}');
  r.endBullets();
  r.callout(
      'This is the same pure core the app ships, driven with no inference, '
      'no Flutter, and no model binary — the reusable solvability check Phase 4.3 '
      'runs per generated manifest.');

  r.writeTo('$showcaseOutputDir/phase2/08-sandbox.md');
}

String _bp(int basisPoints) => '${(basisPoints / 100).toStringAsFixed(1)}%';
