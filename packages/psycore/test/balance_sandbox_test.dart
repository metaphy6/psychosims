import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:psychemas/psychemas.dart';
import 'package:psycore/psycore.dart';
import 'package:test/test.dart';

int _median(List<int> values) {
  if (values.isEmpty) return 0;
  final sorted = List<int>.of(values)..sort();
  final mid = sorted.length ~/ 2;
  return sorted.length.isOdd
      ? sorted[mid]
      : ((sorted[mid - 1] + sorted[mid]) / 2).round();
}

void main() {
  const rulesetVersion = '0.1.0';
  final manifest = ManifestLoader().load(
    File('../../content/manifests/siege_brumosis.json').readAsBytesSync(),
  );
  final library = CardLibrary(
    ownedCardIds: manifest.resolvedCards.map((c) => c.id).toSet(),
  );
  final loadout = Loadout(
    cardIds: manifest.resolvedCards.map((c) => c.id).toList(),
    slotCap: 6,
  );
  const runner = ScenarioRunner(
    rulesetVersion: rulesetVersion,
    clock: InjectedClock.replay(0),
  );

  // A lenient balance used only to unit-test the sandbox machinery: it lets
  // bots reach the success threshold in a reasonable number of turns.
  const testBalance = CardBalance(
    successProgressThreshold: 15,
    crisisThreshold: 80,
    walkoutThreshold: 95,
  );
  const testRunner = ScenarioRunner(
    rulesetVersion: rulesetVersion,
    clock: InjectedClock.replay(0),
    maxTurns: 40,
    balance: testBalance,
  );

  group('BotPlayer', () {
    test('expert solves faster than novice on siege manifest', () {
      const expert = BotPlayer(id: 'expert', skill: BotSkill.expert);
      const novice = BotPlayer(id: 'novice', skill: BotSkill.novice);

      final expertTurns = <int>[];
      final noviceTurns = <int>[];
      var expertWins = 0;
      var noviceWins = 0;
      for (var seed = 1; seed <= 20; seed++) {
        final expertResult = testRunner.run(
          manifest: manifest,
          bot: expert,
          loadout: loadout,
          library: library,
          rootSeed: seed,
        );
        final noviceResult = testRunner.run(
          manifest: manifest,
          bot: novice,
          loadout: loadout,
          library: library,
          rootSeed: seed,
        );
        if (expertResult.won) {
          expertWins++;
          expertTurns.add(expertResult.turnCount);
        }
        if (noviceResult.won) {
          noviceWins++;
          noviceTurns.add(noviceResult.turnCount);
        }
      }

      expect(expertWins, greaterThan(0), reason: 'expert should win sometimes');
      expect(noviceWins, greaterThan(0), reason: 'novice should win sometimes');
      final expertMedian = _median(expertTurns);
      final noviceMedian = _median(noviceTurns);
      expect(expertMedian, lessThanOrEqualTo(noviceMedian),
          reason: 'expert should solve at least as fast as novice');
    });

    test('scenario replay is byte-identical for fixed seed', () {
      const bot = BotPlayer(id: 'expert', skill: BotSkill.expert);
      ScenarioResult runOnce() => runner.run(
            manifest: manifest,
            bot: bot,
            loadout: loadout,
            library: library,
            rootSeed: 42,
          );

      final a = runOnce();
      final b = runOnce();
      expect(a.finalState.toCanonicalBytes(), b.finalState.toCanonicalBytes());
      expect(a.turnCount, b.turnCount);
      expect(a.won, b.won);
    });
  });

  group('ScenarioDistribution', () {
    test('computes median and p95', () {
      final results = [
        for (var i = 0; i < 10; i++)
          ScenarioResult(
            manifestId: 'm',
            botId: 'b',
            skill: BotSkill.expert,
            rootSeed: i,
            won: i < 7,
            turnCount: i + 5,
            outcome: SessionOutcome.succeed,
            finalState: SimState.fromInitialState(i, {}),
            turns: const [],
            durationMillis: 0,
          ),
      ];
      final dist = ScenarioDistribution.fromResults(results);
      expect(dist.count, 10);
      expect(dist.winRateBasisPoints, 7000);
      expect(dist.medianTurns, 10);
    });
  });

  group('BalanceSandbox', () {
    test('sandbox sweep reports distributions and detects dead currencies', () {
      final configs = [
        for (final skill in BotSkill.values)
          for (var seed = 1; seed <= 5; seed++)
            SandboxScenarioConfig(
              manifest: manifest,
              bot: BotPlayer(id: skill.toJson(), skill: skill),
              loadout: loadout,
              library: library,
              rootSeed: seed,
            ),
      ];
      const sandbox = BalanceSandbox(
        runner: runner,
        scenarios: [], // replaced below
      );
      // Construct via reflection of public fields is not possible; create a
      // new sandbox with the populated configs.
      final activeSandbox = BalanceSandbox(
        runner: runner,
        scenarios: configs,
      );
      final report = activeSandbox.runSweep();

      expect(report.totalRuns, configs.length);
      expect(report.bySkill.length, BotSkill.values.length);
      expect(report.byManifest.containsKey(manifest.id), isTrue);
      // Subspecialty and prestige have no sources in the sandbox economy, so
      // they are flagged as dead currencies.
      final deadCurrencies =
          report.deadCurrencyFlags.map((f) => f.currency).toSet();
      expect(deadCurrencies.contains(CurrencyType.subspecialty), isTrue);
      expect(deadCurrencies.contains(CurrencyType.prestige), isTrue);
    });

    test('deliberately unsolvable manifest is flagged by oracle', () {
      const oracle = SolvabilityOracle();
      final empty = PatientManifest(
        rulesetVersion: rulesetVersion,
        id: 'empty.case',
        contentChecksum: 'sha256:ignored',
        nameKey: 'case.empty.title',
        displayNameKey: 'case.empty.display',
        styleArchetype: StyleArchetype.vexa,
        initialState: const {},
        interactionPatterns: const [],
        clueTokens: const [],
        maxHistoryTurns: 1,
        modelFacingTemplate: 'empty',
      );
      expect(oracle.isSolvable(empty), isFalse);
    });

    test('regression corpus reproduces byte-identical outcomes', () {
      const runner = ScenarioRunner(
        rulesetVersion: rulesetVersion,
        clock: InjectedClock.replay(0),
      );
      final fixture = jsonDecode(
        File('../../test_fixtures/regression_scenarios.json')
            .readAsStringSync(),
      ) as Map<String, dynamic>;
      final scenarios =
          (fixture['scenarios'] as List<dynamic>).cast<Map<String, dynamic>>();

      for (final expected in scenarios) {
        final skill = BotSkillJson.fromJson(expected['skill'] as String);
        final seed = expected['seed'] as int;
        final bot = BotPlayer(id: skill.toJson(), skill: skill);
        final result = runner.run(
          manifest: manifest,
          bot: bot,
          loadout: loadout,
          library: library,
          rootSeed: seed,
        );
        expect(result.won, expected['won'], reason: 'skill=$skill seed=$seed');
        expect(result.turnCount, expected['turn_count'],
            reason: 'skill=$skill seed=$seed');
        expect(result.outcome.toJson(), expected['outcome'],
            reason: 'skill=$skill seed=$seed');
        final hash =
            sha256.convert(result.finalState.toCanonicalBytes()).toString();
        expect(hash, expected['final_state_sha256'],
            reason: 'skill=$skill seed=$seed final state');
      }
    });
  });
}
