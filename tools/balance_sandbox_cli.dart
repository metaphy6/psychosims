import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:psychemas/psychemas.dart';
import 'package:psycore/psycore.dart';

/// Headless balance sandbox CLI (Phase 2.8).
///
/// Runs the deterministic core without inference, Flutter, or `dart:io` model
/// access. It proves mechanical solvability, emits structured diagnostics, and
/// measures throughput against the 0.7 metrics contract budget.
///
/// Usage:
///   dart tools/balance_sandbox_cli.dart content/manifests
///
/// Exits non-zero if any manifest is unsolvable or an inflation flag fires.
void main(List<String> args) async {
  final manifestDir = args.isNotEmpty ? args.first : 'content/manifests';
  final dir = Directory(manifestDir);
  if (!dir.existsSync()) {
    stderr.writeln('Directory not found: $manifestDir');
    exit(2);
  }

  final oracle = const SolvabilityOracle();
  final loader = ManifestLoader();
  final manifests = <PatientManifest>[];

  for (final entity in dir.listSync(recursive: false)) {
    if (entity is! File) continue;
    if (!entity.path.endsWith('.json')) continue;
    final manifest = loader.load(entity.readAsBytesSync());
    if (!oracle.isSolvable(manifest)) {
      stderr.writeln('❌ ${manifest.id} is not mechanically solvable');
      exit(3);
    }
    if (!oracle.isContentCompliant(manifest)) {
      stderr.writeln('❌ ${manifest.id} fails content compliance');
      exit(4);
    }
    manifests.add(manifest);
  }

  if (manifests.isEmpty) {
    stderr.writeln('No manifests found in $manifestDir');
    exit(5);
  }

  final scenarios = <SandboxScenarioConfig>[];
  for (final manifest in manifests) {
    final library = CardLibrary(
      ownedCardIds: manifest.resolvedCards.map((c) => c.id).toSet(),
    );
    final loadout = Loadout(
      cardIds: manifest.resolvedCards.map((c) => c.id).toList(),
      slotCap: 6,
    );
    for (final skill in BotSkill.values) {
      for (var seed = 1; seed <= 10; seed++) {
        scenarios.add(SandboxScenarioConfig(
          manifest: manifest,
          bot: BotPlayer(id: '${manifest.id}_${skill.toJson()}', skill: skill),
          loadout: loadout,
          library: library,
          rootSeed: seed,
        ));
      }
    }
  }

  const runner = ScenarioRunner(
    rulesetVersion: '0.1.0',
    clock: InjectedClock.replay(0),
  );
  const sandbox = BalanceSandbox(
    runner: runner,
    scenarios: [], // replaced below
  );
  final activeSandbox = BalanceSandbox(
    runner: runner,
    scenarios: scenarios,
  );

  final stopwatch = Stopwatch()..start();
  final report = activeSandbox.runSweep();
  stopwatch.stop();

  final elapsedSeconds = stopwatch.elapsedMilliseconds / 1000;
  final sessionsPerSecond =
      elapsedSeconds > 0 ? report.totalRuns / elapsedSeconds : 0.0;

  final output = {
    'manifests_checked': manifests.length,
    'total_runs': report.totalRuns,
    'total_turns': report.totalTurns,
    'elapsed_seconds': elapsedSeconds,
    'sessions_per_second': sessionsPerSecond,
    'overall_win_rate_basis_points': report.overallWinRateBasisPoints,
    'by_skill': {
      for (final e in report.bySkill.entries) e.key.toJson(): e.value.toJson(),
    },
    'by_manifest': {
      for (final e in report.byManifest.entries) e.key: e.value.toJson(),
    },
    'dead_currency_flags':
        report.deadCurrencyFlags.map((f) => f.toJson()).toList(),
    'inflation_flag': report.inflationFlag?.toJson(),
  };

  stdout.writeln(const JsonEncoder.withIndent('  ').convert(output));

  if (report.inflationFlag != null) {
    stderr
        .writeln('❌ Inflation detected for ${report.inflationFlag!.currency}');
    exit(6);
  }

  const minSessionsPerSecond = 100.0; // 0.7 throughput budget placeholder
  if (sessionsPerSecond < minSessionsPerSecond) {
    stderr.writeln(
        '⚠️ Throughput $sessionsPerSecond < budget $minSessionsPerSecond');
    exit(7);
  }

  stdout.writeln('✅ Balance sandbox passed');
}
