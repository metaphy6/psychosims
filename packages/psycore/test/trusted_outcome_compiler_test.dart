import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:crypto/crypto.dart';
import 'package:psychemas/psychemas.dart';
import 'package:psyconfig/psyconfig.dart';
import 'package:psycore/psycore.dart';
import 'package:test/test.dart';

const limits = OutcomeCompileLimits(
    maxActions: 120,
    maxDeltas: 1024,
    maxTransitions: 20000,
    maxReceiptBytes: 131072,
    maxProofBytes: 262144);
Uint8List source([String name = 'siege_brumosis']) =>
    File('../../content/manifests/$name.json').readAsBytesSync();
Uint8List rewrite(void Function(Map<String, dynamic>) edit) {
  final json = jsonDecode(utf8.decode(source())) as Map<String, dynamic>;
  edit(json);
  json['content_checksum'] = '';
  json['content_checksum'] =
      'sha256:${sha256.convert(CanonicalJson.encode(json))}';
  return Uint8List.fromList(CanonicalJson.encode(json));
}

SessionStartState start(Uint8List raw,
    {int seed = 1729,
    Map<String, int>? axes,
    List<String>? cards,
    Set<String>? owned,
    TherapyControllerSettings controllers =
        const TherapyControllerSettings()}) {
  final manifest = ManifestLoader().load(raw);
  final equipped = cards ?? manifest.resolvedCards.map((c) => c.id).toList();
  return SessionStartState(
      loadout: Loadout(cardIds: equipped, slotCap: 5),
      library: CardLibrary(ownedCardIds: owned ?? equipped.toSet()),
      controllers: controllers,
      initialAxes: axes ?? manifest.initialState,
      rootSeed: seed);
}

void main() {
  final balance =
      CardBalance.fromConfig(loadConfig(environment: 'prod').balance);
  final compiler = TrustedOutcomeCompiler(balance: balance, limits: limits);
  TrustedOutcomeProof compile(Uint8List raw, {SessionStartState? snapshot}) =>
      compiler.compile(
          rawManifest: raw,
          start: snapshot ?? start(raw),
          catalogVersion: 'catalog.v1');
  final rejected = throwsA(isA<OutcomeCompileException>());
  for (final name in ['siege_brumosis', 'poc_sample']) {
    test('$name proves the first actual terminal cure with exact typed deltas',
        () {
      final raw = source(name);
      final snapshot = start(raw);
      final proof = compile(raw, snapshot: snapshot);
      final manifest = ManifestLoader().load(raw);
      final resolver =
          TurnResolver(const InjectedClock.replay(0), balance: balance);
      var state =
          SimState.fromInitialState(snapshot.rootSeed, manifest.initialState);
      TurnOutput? last;
      final deltas = <StructuredDelta>[];
      for (final action in proof.actions) {
        expect(last?.isTerminal ?? false, isFalse);
        last = resolver.resolve(TurnInput(
            rulesetVersion: manifest.rulesetVersion,
            manifest: manifest,
            state: state,
            action: action,
            loadout: snapshot.loadout,
            library: snapshot.library,
            controllers: snapshot.controllers));
        deltas.addAll(last.deltas);
        state = last.nextState;
      }
      expect(proof.actions.length, 100);
      expect(last!.isTerminal, isTrue);
      expect(last.outcome, SessionOutcome.succeed);
      expect(last.lifecycle, CaseLifecycle.cured);
      expect(proof.deltas, deltas);
      expect(proof.finalState, state);
      expect(proof.toJson()['effective_balance'], balance.toJson());
      expect(proof.toJson()['start_state'], {
        ...snapshot.toJson(),
        'case_id': manifest.id,
        'manifest_checksum': manifest.contentChecksum
      });
      expect(proof.canonicalBytes, CanonicalJson.encode(proof.toJson()));
      expect(proof.maxIdentifierReceiptBytes, lessThanOrEqualTo(131072));
      expect(proof.maxIdentifierEnvelopeBytes,
          greaterThan(proof.maxIdentifierReceiptBytes));
      expect(utf8.decode(proof.canonicalBytes),
          isNot(contains(manifest.modelFacingTemplate)));
    });
  }
  test('proof repeats exactly, binds controllers and order, and is immutable',
      () {
    final raw = source();
    final axes = <String, int>{'trust': 40, 'agitation': 30, 'trauma': 0};
    final cards = ['validate', 'open_question'];
    const controllers =
        TherapyControllerSettings(emotionalDelivery: EmotionalDelivery.warm);
    final snapshot =
        start(raw, axes: axes, cards: cards, controllers: controllers);
    final proof = compile(raw, snapshot: snapshot);
    expect(
        compile(raw, snapshot: snapshot).canonicalBytes, proof.canonicalBytes);
    expect(compile(raw, snapshot: start(raw, cards: cards)).canonicalBytes,
        isNot(proof.canonicalBytes));
    expect(
        compile(raw,
                snapshot: start(raw,
                    cards: cards.reversed.toList(), controllers: controllers))
            .canonicalBytes,
        isNot(proof.canonicalBytes));
    final manifest = ManifestLoader().load(raw);
    final resolver =
        TurnResolver(const InjectedClock.replay(0), balance: balance);
    var state =
        SimState.fromInitialState(snapshot.rootSeed, snapshot.initialAxes);
    final replayed = <StructuredDelta>[];
    for (final action in proof.actions) {
      final turn = resolver.resolve(TurnInput(
          rulesetVersion: manifest.rulesetVersion,
          manifest: manifest,
          state: state,
          action: action,
          loadout: snapshot.loadout,
          library: snapshot.library,
          controllers: controllers));
      replayed.addAll(turn.deltas);
      state = turn.nextState;
    }
    expect(replayed, proof.deltas);
    expect(state, proof.finalState);
    final before = List<int>.of(proof.canonicalBytes);
    axes['trust'] = 99;
    cards.clear();
    expect(proof.canonicalBytes, before);
    expect(() => proof.canonicalBytes[0] = 0, throwsUnsupportedError);
    expect(() => proof.actions.clear(), throwsUnsupportedError);
    expect(() => proof.deltas.clear(), throwsUnsupportedError);
    expect(() => (proof.toJson()['start_state'] as Map).clear(),
        throwsUnsupportedError);
    expect(
        () => ((proof.toJson()['start_state'] as Map)['loadout']
                as Map)['card_ids']
            .clear(),
        throwsUnsupportedError);
  });
  test(
      'catalog, full manifest checksum, and effective balance change proof bytes',
      () {
    final raw = source();
    final original = compile(raw);
    final changed = rewrite(
        (j) => j['model_facing_template'] = 'changed fictional content');
    expect(compile(changed).canonicalBytes, isNot(original.canonicalBytes));
    expect(
        compiler
            .compile(
                rawManifest: raw,
                start: start(raw),
                catalogVersion: 'catalog.v2')
            .canonicalBytes,
        isNot(original.canonicalBytes));
    final alternate = TrustedOutcomeCompiler(
        balance: CardBalance(
            activeCardSlots: balance.activeCardSlots,
            postponingFreezeTurns: balance.postponingFreezeTurns,
            fitBufferTrust: balance.fitBufferTrust + 1),
        limits: limits);
    expect(
        alternate
            .compile(
                rawManifest: raw,
                start: start(raw),
                catalogVersion: 'catalog.v1')
            .canonicalBytes,
        isNot(original.canonicalBytes));
  });
  test('seed0 and max31bit succeed; out of range fails', () {
    final raw = source();
    for (final seed in [0, 2147483647]) {
      expect(
          (compile(raw, snapshot: start(raw, seed: seed))
              .toJson()['start_state'] as Map)['root_seed'],
          seed);
    }
    for (final seed in [-1, 2147483648]) {
      expect(() => compile(raw, snapshot: start(raw, seed: seed)), rejected);
    }
  });
  test('raw checksum is verified before use', () {
    final raw = Uint8List.fromList(utf8.encode(
        utf8.decode(source()).replaceFirst('"trust": 40', '"trust": 99')));
    expect(() => compile(raw), throwsA(isA<ManifestValidationError>()));
  });
  test('unsupported ruleset and uninterpreted initial axes fail closed', () {
    expect(() => compile(rewrite((j) => j['ruleset_version'] = 'future.99')),
        rejected);
    for (final key in [
      'medication_tolerance',
      'trust_score',
      'turn',
      'history'
    ]) {
      expect(
          () => compile(rewrite((j) => (j['initial_state'] as Map)[key] = 1)),
          rejected);
    }
  });
  test('start must exactly equal bounded manifest initial axes', () {
    final raw = source();
    for (final axes in [
      <String, int>{
        'trust': 40,
        'agitation': 30,
        'trauma': 0,
        'session_progress': 99
      },
      <String, int>{'trust': 41, 'agitation': 30, 'trauma': 0},
      <String, int>{'trust': 40, 'agitation': 30}
    ]) {
      expect(() => compile(raw, snapshot: start(raw, axes: axes)), rejected);
    }
    for (final value in [-1, 101]) {
      expect(
          () => compile(
              rewrite((j) => (j['initial_state'] as Map)['trust'] = value)),
          rejected);
    }
  });
  test('terminal and prior progress starts cannot manufacture a fresh cure',
      () {
    for (final axis in ['agitation', 'session_progress']) {
      expect(
          () =>
              compile(rewrite((j) => (j['initial_state'] as Map)[axis] = 100)),
          rejected);
    }
    expect(
        () => compile(rewrite(
            (j) => (j['initial_state'] as Map)['session_progress'] = 99)),
        rejected);
  });
  test('invalid, duplicate, unknown, unowned and oversized inventories fail',
      () {
    final raw = source();
    for (final cards in [
      <String>[],
      ['validate', 'validate'],
      ['missing'],
      ['raw dialogue text']
    ]) {
      expect(() => compile(raw, snapshot: start(raw, cards: cards)), rejected);
    }
    expect(
        () =>
            compile(raw, snapshot: start(raw, cards: ['validate'], owned: {})),
        rejected);
    expect(
        () => compile(raw,
            snapshot: start(raw,
                owned: {'validate', ...List.generate(65, (i) => 'card.$i')})),
        rejected);
  });
  test('search, action, delta, receipt, proof and hard limits fail closed', () {
    final raw = source();
    for (final bound in [
      const OutcomeCompileLimits(
          maxActions: 1,
          maxDeltas: 1024,
          maxTransitions: 20000,
          maxReceiptBytes: 131072,
          maxProofBytes: 262144),
      const OutcomeCompileLimits(
          maxActions: 120,
          maxDeltas: 1024,
          maxTransitions: 1,
          maxReceiptBytes: 131072,
          maxProofBytes: 262144),
      const OutcomeCompileLimits(
          maxActions: 120,
          maxDeltas: 1,
          maxTransitions: 20000,
          maxReceiptBytes: 131072,
          maxProofBytes: 262144),
      const OutcomeCompileLimits(
          maxActions: 120,
          maxDeltas: 1024,
          maxTransitions: 20000,
          maxReceiptBytes: 1000,
          maxProofBytes: 262144),
      const OutcomeCompileLimits(
          maxActions: 120,
          maxDeltas: 1024,
          maxTransitions: 20000,
          maxReceiptBytes: 131072,
          maxProofBytes: 1000),
      const OutcomeCompileLimits(
          maxActions: 121,
          maxDeltas: 1024,
          maxTransitions: 20000,
          maxReceiptBytes: 131072,
          maxProofBytes: 262144),
    ]) {
      expect(
          () => TrustedOutcomeCompiler(balance: balance, limits: bound).compile(
              rawManifest: raw,
              start: start(raw),
              catalogVersion: 'catalog.v1'),
          rejected);
    }
  });
}
