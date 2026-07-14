import 'package:psychemas/psychemas.dart';

import 'bot_player.dart';
import 'ledger.dart';
import 'scenario_result.dart';
import 'scenario_runner.dart';

/// Configuration for one scenario in a sandbox sweep.
class SandboxScenarioConfig {
  final PatientManifest manifest;
  final BotPlayer bot;
  final Loadout loadout;
  final CardLibrary library;
  final int rootSeed;

  const SandboxScenarioConfig({
    required this.manifest,
    required this.bot,
    required this.loadout,
    required this.library,
    required this.rootSeed,
  });
}

/// Lightweight session→economy mapping used by the sandbox to detect dead
/// currencies and runaway inflation without invoking the full career model.
class SandboxEconomyConfig {
  /// Cash earned for a successful session.
  final int winCashMicros;

  /// Cash earned for a failed session (small stipend).
  final int lossCashMicros;

  /// XP earned for a successful session.
  final int winXpMicros;

  /// XP earned for a failed session.
  final int lossXpMicros;

  /// Reputation shock for a successful session.
  final int winReputationMicros;

  /// Reputation shock for a failed session.
  final int lossReputationMicros;

  /// Study points earned for a successful session.
  final int winStudyMicros;

  /// Fixed cash sink per scenario (clinic overhead proxy) so the sandbox has
  /// both a source and a sink for cash.
  final int perRunOverheadMicros;

  const SandboxEconomyConfig({
    this.winCashMicros = 1500000,
    this.lossCashMicros = 200000,
    this.winXpMicros = 1000000,
    this.lossXpMicros = 100000,
    this.winReputationMicros = 500000,
    this.lossReputationMicros = -200000,
    this.winStudyMicros = 250000,
    this.perRunOverheadMicros = 1000000,
  });
}

/// Aggregated report from a sandbox sweep.
class SandboxReport {
  final int totalRuns;
  final int totalTurns;

  /// Overall win rate in basis points (0–10000).
  final int overallWinRateBasisPoints;
  final Map<BotSkill, ScenarioDistribution> bySkill;
  final Map<String, ScenarioDistribution> byManifest;
  final Map<CurrencyType, int> netCurrencyFlowMicros;
  final List<DeadCurrencyFlag> deadCurrencyFlags;
  final InflationFlag? inflationFlag;
  final List<ScenarioResult> results;

  const SandboxReport({
    required this.totalRuns,
    required this.totalTurns,
    required this.overallWinRateBasisPoints,
    required this.bySkill,
    required this.byManifest,
    required this.netCurrencyFlowMicros,
    required this.deadCurrencyFlags,
    this.inflationFlag,
    required this.results,
  });

  Map<String, Object?> toJson() => {
        'total_runs': totalRuns,
        'total_turns': totalTurns,
        'overall_win_rate_basis_points': overallWinRateBasisPoints,
        'by_skill': {
          for (final e in bySkill.entries) e.key.toJson(): e.value.toJson(),
        },
        'by_manifest': {
          for (final e in byManifest.entries) e.key: e.value.toJson(),
        },
        'net_currency_flow_micros': {
          for (final e in netCurrencyFlowMicros.entries)
            e.key.toJson(): e.value,
        },
        'dead_currency_flags':
            deadCurrencyFlags.map((f) => f.toJson()).toList(),
        'inflation_flag': inflationFlag?.toJson(),
      };
}

/// A currency with either no source or no sink across the sweep.
class DeadCurrencyFlag {
  final CurrencyType currency;
  final bool noSource;
  final bool noSink;

  const DeadCurrencyFlag({
    required this.currency,
    required this.noSource,
    required this.noSink,
  });

  Map<String, Object?> toJson() => {
        'currency': currency.toJson(),
        'no_source': noSource,
        'no_sink': noSink,
      };
}

/// Flag raised when a currency's net flow suggests runaway generation.
class InflationFlag {
  final CurrencyType currency;
  final int netFlowMicros;
  final int runs;

  const InflationFlag({
    required this.currency,
    required this.netFlowMicros,
    required this.runs,
  });

  Map<String, Object?> toJson() => {
        'currency': currency.toJson(),
        'net_flow_micros': netFlowMicros,
        'runs': runs,
      };
}

/// Runs many deterministic scenarios and emits structured diagnostics for
/// balance tuning.
///
/// The sandbox operates entirely on the 2.0 core-only run path: no inference,
/// no Flutter, no `dart:io`. It is parallelizable across isolates because the
/// core is pure and the runner is stateless.
class BalanceSandbox {
  final ScenarioRunner runner;
  final List<SandboxScenarioConfig> scenarios;
  final SandboxEconomyConfig economyConfig;

  const BalanceSandbox({
    required this.runner,
    required this.scenarios,
    this.economyConfig = const SandboxEconomyConfig(),
  });

  /// Runs every configured scenario once and returns a structured report.
  SandboxReport runSweep() {
    final results = <ScenarioResult>[];
    var totalTurns = 0;

    for (final scenario in scenarios) {
      final result = runner.run(
        manifest: scenario.manifest,
        bot: scenario.bot,
        loadout: scenario.loadout,
        library: scenario.library,
        rootSeed: scenario.rootSeed,
      );
      results.add(result);
      totalTurns += result.turnCount;
    }

    final bySkill = <BotSkill, List<ScenarioResult>>{};
    final byManifest = <String, List<ScenarioResult>>{};
    for (final r in results) {
      bySkill.putIfAbsent(r.skill, () => []).add(r);
      byManifest.putIfAbsent(r.manifestId, () => []).add(r);
    }

    final distributionBySkill = {
      for (final e in bySkill.entries)
        e.key: ScenarioDistribution.fromResults(e.value),
    };
    final distributionByManifest = {
      for (final e in byManifest.entries)
        e.key: ScenarioDistribution.fromResults(e.value),
    };

    final netFlow = _computeNetCurrencyFlow(results);
    final deadFlags = _detectDeadCurrencies(netFlow, results);
    final inflationFlag = _detectInflation(netFlow, results.length);

    final wins = results.where((r) => r.won).length;

    return SandboxReport(
      totalRuns: results.length,
      totalTurns: totalTurns,
      overallWinRateBasisPoints:
          results.isEmpty ? 0 : (wins * 10000) ~/ results.length,
      bySkill: distributionBySkill,
      byManifest: distributionByManifest,
      netCurrencyFlowMicros: netFlow,
      deadCurrencyFlags: deadFlags,
      inflationFlag: inflationFlag,
      results: results,
    );
  }

  Map<CurrencyType, int> _computeNetCurrencyFlow(List<ScenarioResult> results) {
    final events = _eventsFor(results);
    final ledger = events.fold<Ledger>(Ledger(), (l, e) => l.apply(e));
    return ledger.balances();
  }

  List<DeadCurrencyFlag> _detectDeadCurrencies(
    Map<CurrencyType, int> netFlow,
    List<ScenarioResult> results,
  ) {
    final events = _eventsFor(results);
    final flags = <DeadCurrencyFlag>[];
    for (final currency in CurrencyType.values) {
      var hasSource = false;
      var hasSink = false;
      for (final event in events) {
        if (event.currency != currency) continue;
        if (event.amountMicros > 0) hasSource = true;
        if (event.amountMicros < 0) hasSink = true;
      }
      if (!hasSource || !hasSink) {
        flags.add(DeadCurrencyFlag(
          currency: currency,
          noSource: !hasSource,
          noSink: !hasSink,
        ));
      }
    }
    return flags;
  }

  InflationFlag? _detectInflation(
    Map<CurrencyType, int> netFlow,
    int runCount,
  ) {
    if (runCount == 0) return null;
    const thresholdMicrosPerRun = 500000; // 0.5 currency units per run
    for (final entry in netFlow.entries) {
      final perRun = entry.value ~/ runCount;
      if (perRun > thresholdMicrosPerRun) {
        return InflationFlag(
          currency: entry.key,
          netFlowMicros: entry.value,
          runs: runCount,
        );
      }
    }
    return null;
  }

  List<LedgerEvent> _eventsFor(List<ScenarioResult> results) {
    final events = <LedgerEvent>[];
    for (final result in results) {
      final timestamp = result.turnCount; // deterministic pseudo-timestamp
      events.add(LedgerEvent(
        kind: 'sandbox_overhead',
        idempotencyKey: 'overhead:${result.manifestId}:${result.rootSeed}',
        timestampSeconds: timestamp,
        currency: CurrencyType.cash,
        amountMicros: -economyConfig.perRunOverheadMicros,
        reasonKey: 'sandbox.overhead.cash',
      ));
      if (result.won) {
        events.add(LedgerEvent(
          kind: 'session_reward',
          idempotencyKey: 'reward:${result.manifestId}:${result.rootSeed}',
          timestampSeconds: timestamp,
          currency: CurrencyType.cash,
          amountMicros: economyConfig.winCashMicros,
          reasonKey: 'sandbox.reward.win.cash',
        ));
        events.add(LedgerEvent(
          kind: 'session_reward',
          idempotencyKey: 'xp:${result.manifestId}:${result.rootSeed}',
          timestampSeconds: timestamp,
          currency: CurrencyType.xp,
          amountMicros: economyConfig.winXpMicros,
          reasonKey: 'sandbox.reward.win.xp',
        ));
        events.add(LedgerEvent(
          kind: 'session_reward',
          idempotencyKey: 'rep:${result.manifestId}:${result.rootSeed}',
          timestampSeconds: timestamp,
          currency: CurrencyType.reputation,
          amountMicros: economyConfig.winReputationMicros,
          reasonKey: 'sandbox.reward.win.reputation',
        ));
        events.add(LedgerEvent(
          kind: 'session_reward',
          idempotencyKey: 'study:${result.manifestId}:${result.rootSeed}',
          timestampSeconds: timestamp,
          currency: CurrencyType.study,
          amountMicros: economyConfig.winStudyMicros,
          reasonKey: 'sandbox.reward.win.study',
        ));
      } else {
        events.add(LedgerEvent(
          kind: 'session_stipend',
          idempotencyKey: 'stipend:${result.manifestId}:${result.rootSeed}',
          timestampSeconds: timestamp,
          currency: CurrencyType.cash,
          amountMicros: economyConfig.lossCashMicros,
          reasonKey: 'sandbox.reward.loss.cash',
        ));
        events.add(LedgerEvent(
          kind: 'session_reward',
          idempotencyKey: 'xp-loss:${result.manifestId}:${result.rootSeed}',
          timestampSeconds: timestamp,
          currency: CurrencyType.xp,
          amountMicros: economyConfig.lossXpMicros,
          reasonKey: 'sandbox.reward.loss.xp',
        ));
        events.add(LedgerEvent(
          kind: 'session_reward',
          idempotencyKey: 'rep-loss:${result.manifestId}:${result.rootSeed}',
          timestampSeconds: timestamp,
          currency: CurrencyType.reputation,
          amountMicros: economyConfig.lossReputationMicros,
          reasonKey: 'sandbox.reward.loss.reputation',
        ));
      }
    }
    return events;
  }
}
