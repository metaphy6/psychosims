import 'dart:io';

import 'package:psychemas/psychemas.dart';
import 'package:psycore/psycore.dart';
import 'package:test/test.dart';

void main() {
  const oracle = SolvabilityOracle();

  test('siege manifest is solvable and content-compliant', () {
    final bytes =
        File('../../content/manifests/siege_brumosis.json').readAsBytesSync();
    final manifest = ManifestLoader().load(bytes);
    expect(oracle.isSolvable(manifest), isTrue);
    expect(oracle.isContentCompliant(manifest), isTrue);
    expect(manifest.memoryClass, MemoryClass.persistent);
  });

  test('manifest without interaction patterns is not solvable', () {
    final manifest = PatientManifest(
      rulesetVersion: '0.1.0',
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
    expect(oracle.isSolvable(manifest), isFalse);
  });

  test('winning witness is immutable, deterministic, and replays in the core',
      () {
    final manifest = ManifestLoader().load(
        File('../../content/manifests/siege_brumosis.json').readAsBytesSync());
    final result = oracle.analyze(manifest, rootSeed: 1729);
    final repeated = oracle.analyze(manifest, rootSeed: 1729);
    expect(result.status, SolvabilityStatus.solved);
    expect(result.actions, repeated.actions);
    expect(result.exploredTransitions, repeated.exploredTransitions);
    expect(result.finalState, repeated.finalState);
    expect(() => result.actions.clear(), throwsUnsupportedError);
    final cards = manifest.resolvedCards.map((card) => card.id).toSet();
    final loadout = Loadout(cardIds: cards.toList(), slotCap: 6);
    final library = CardLibrary(ownedCardIds: cards);
    const resolver = TurnResolver(InjectedClock.replay(0));
    var state = SimState.fromInitialState(1729, manifest.initialState);
    TurnOutput? last;
    for (final action in result.actions) {
      expect(last?.isTerminal ?? false, isFalse);
      last = resolver.resolve(TurnInput(
          rulesetVersion: manifest.rulesetVersion,
          manifest: manifest,
          state: state,
          action: action,
          loadout: loadout,
          library: library));
      state = last.nextState;
    }
    expect(last?.outcome, SessionOutcome.succeed);
    expect(state, result.finalState);
  });

  test('exhausted budget is unproven and never a winning verdict', () {
    final manifest = ManifestLoader().load(
        File('../../content/manifests/siege_brumosis.json').readAsBytesSync());
    final result = const SolvabilityOracle(maxTransitions: 1).analyze(manifest);
    expect(result.status, SolvabilityStatus.budgetExceeded);
    expect(result.solved, isFalse);
    expect(result.actions, isEmpty);
    expect(result.finalState, isNull);
    expect(result.exploredTransitions, 1);
  });

  test('a short horizon reports bounded absence, not universal impossibility',
      () {
    final manifest = ManifestLoader().load(
        File('../../content/manifests/siege_brumosis.json').readAsBytesSync());
    expect(const SolvabilityOracle(maxTurns: 1).analyze(manifest).status,
        SolvabilityStatus.noSolutionWithinBounds);
  });

  test('solver never uses cards outside equipped and owned inventory', () {
    final manifest = ManifestLoader().load(
        File('../../content/manifests/siege_brumosis.json').readAsBytesSync());
    const equipped = Loadout(cardIds: ['validate'], slotCap: 6);
    final invalid = oracle.analyze(manifest,
        loadout: equipped, library: const CardLibrary(ownedCardIds: {}));
    expect(invalid.status, SolvabilityStatus.invalid);
    expect(invalid.exploredTransitions, 0);
    final valid = oracle.analyze(manifest,
        loadout: equipped,
        library: const CardLibrary(ownedCardIds: {'validate'}));
    expect(valid.status, SolvabilityStatus.solved);
    expect(valid.actions, everyElement(InteractionPattern.validate));
  });

  test('nonpositive budgets are rejected', () {
    final manifest = ManifestLoader().load(
        File('../../content/manifests/siege_brumosis.json').readAsBytesSync());
    expect(() => const SolvabilityOracle(maxTurns: 0).analyze(manifest),
        throwsArgumentError);
    expect(() => const SolvabilityOracle(maxTransitions: 0).analyze(manifest),
        throwsArgumentError);
  });

  test('known action names do not make a mechanically impossible case solvable',
      () {
    final manifest = PatientManifest(
      rulesetVersion: '0.1.0',
      id: 'impossible.walkout',
      contentChecksum: 'sha256:ignored',
      nameKey: 'case.impossible.title',
      displayNameKey: 'case.impossible.display',
      styleArchetype: StyleArchetype.vexa,
      initialState: const {'agitation': 100},
      interactionPatterns: const [InteractionPattern.openQuestion],
      clueTokens: const [],
      maxHistoryTurns: 1,
      modelFacingTemplate: 'fictional',
    );
    expect(oracle.isSolvable(manifest), isFalse);
  });

  test('real diagnostic labels fail content compliance', () {
    final manifest = PatientManifest(
      rulesetVersion: '0.1.0',
      id: 'bad.case',
      contentChecksum: 'sha256:ignored',
      nameKey: 'case.bad.title',
      displayNameKey: 'case.bad.display',
      styleArchetype: StyleArchetype.vexa,
      initialState: const {},
      interactionPatterns: const [InteractionPattern.openQuestion],
      clueTokens: const ['depression-marker'],
      maxHistoryTurns: 1,
      modelFacingTemplate: 'bad',
    );
    expect(oracle.isContentCompliant(manifest), isFalse);
  });
}
