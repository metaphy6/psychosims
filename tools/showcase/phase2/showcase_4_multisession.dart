import 'dart:io';

import 'package:psychemas/psychemas.dart';
import 'package:psycore/psycore.dart';

import '../report.dart';

/// Showcase 4 — Multi-session siege, clue ownership & clinical grading (2.4).
///
/// Demonstrates: stateless vs persistent memory, the bounded history digest
/// (fixed envelope regardless of session count), clue collection, the
/// deterministic "Attending Physician" grading report, and cross-session
/// carry-over — Postponing decay (§16), trauma carry-over, and enumerated
/// derangement mutations.
void main() {
  final r = MarkdownReport(
    'Showcase 4 — Multi-Session Siege, Clues & Clinical Grading (2.4)',
    subtitle: 'memory_class discipline · bounded digest · clue collection · '
        'Attending Physician report · cross-session carry-over',
  );

  final loader = const ManifestLoader();
  final siege = loader
      .load(File('content/manifests/siege_brumosis.json').readAsBytesSync());
  final poc =
      loader.load(File('content/manifests/poc_sample.json').readAsBytesSync());
  const ms = MultiSessionResolver();

  // 1. memory_class discipline.
  r.h2('1. `memory_class` discipline — stateless carries no history');
  final statelessEnv = ms.envelopeForCase(poc.memoryClass);
  final persistentEnv = ms.envelopeForCase(siege.memoryClass);
  r.table(
    [
      'case',
      'memory_class',
      'carry-over deltas',
      'derangements',
      'prior sessions'
    ],
    [
      [
        poc.id,
        poc.memoryClass.toJson(),
        '${statelessEnv.carryOverDeltas.length}',
        '${statelessEnv.derangements.length}',
        '${statelessEnv.priorSessionCount}',
      ],
      [
        siege.id,
        siege.memoryClass.toJson(),
        '${persistentEnv.carryOverDeltas.length}',
        '${persistentEnv.derangements.length}',
        '${persistentEnv.priorSessionCount}',
      ],
    ],
  );

  // 2. Bounded digest across accumulating sessions.
  r.h2('2. History digest stays bounded regardless of session count');
  final library =
      CardLibrary(ownedCardIds: siege.resolvedCards.map((c) => c.id).toSet());
  final loadout = Loadout(
      cardIds: siege.resolvedCards.map((c) => c.id).toList(), slotCap: 6);
  final actions = _cycle(siege.interactionPatterns, 6);
  const compiler = MultiSessionDigestCompiler();

  var envelope = ms.envelopeForCase(siege.memoryClass);
  final digestRows = <List<String>>[];
  for (var session = 1; session <= 5; session++) {
    final start = ms.startingState(
      initialState: siege.initialState,
      rootSeed: 1000 + session,
      envelope: envelope,
    );
    final outputs = const CoreRunPath().resolveScripted(
      rulesetVersion: '0.1.0',
      manifest: siege,
      actions: actions,
      rootSeed: 1000 + session,
      clock: const InjectedClock.replay(1_700_000_000_000),
      loadout: loadout,
      library: library,
      startState: start,
    );
    envelope = ms.buildNextEnvelope(
      memoryClass: siege.memoryClass,
      previous: envelope,
      sessionOutputs: outputs,
      manifestClueTokens: siege.clueTokens,
    );
    final digest =
        compiler.compile(envelope: envelope, state: outputs.last.nextState);
    final sentences =
        digest.split('. ').where((s) => s.trim().isNotEmpty).length;
    digestRows.add([
      '$session',
      '${envelope.priorSessionCount}',
      '${envelope.collectedClues.length}',
      '$sentences',
      '${MarkdownReport.ok(sentences <= MultiSessionDigestCompiler.maxSentences)}',
    ]);
  }
  r.table([
    'session',
    'prior sessions',
    'clues collected',
    'digest sentences',
    '≤ ${MultiSessionDigestCompiler.maxSentences}?'
  ], digestRows);
  r.callout('The digest is a bounded structured summary of whitelisted enums + '
      'numbers (never raw deltas), so the prompt stays budget-bound (C-7) no '
      'matter how many sessions accumulate.');

  // 3. Attending Physician grading report.
  r.h2('3. Deterministic "Attending Physician" grading report');
  final gradedOutputs = const CoreRunPath().resolveScripted(
    rulesetVersion: '0.1.0',
    manifest: poc,
    actions: _cycle(poc.interactionPatterns, 8),
    rootSeed: 777,
    clock: const InjectedClock.replay(1_700_000_000_000),
    loadout: Loadout(
        cardIds: poc.resolvedCards.map((c) => c.id).toList(), slotCap: 6),
    library:
        CardLibrary(ownedCardIds: poc.resolvedCards.map((c) => c.id).toSet()),
  );
  final receipt = SessionReceipt(
    id: 'showcase-grade',
    rulesetVersion: '0.1.0',
    patientId: poc.id,
    idempotencyKey: 'showcase-idem',
    correlationId: 'showcase-corr',
    turnCount: gradedOutputs.length,
    startState: SimState.fromInitialState(777, poc.initialState).toJson(),
    actions: _cycle(poc.interactionPatterns, 8),
    deltas: gradedOutputs.expand((o) => o.deltas).toList(),
  );
  const calc = ClinicalGradingCalculator();
  final g1 = calc.calculate(receipt);
  final g2 = calc.calculate(receipt);
  r.table(
    ['dimension', 'score (0–100)', 'reason key'],
    [
      [g1.alliance.name, '${g1.alliance.score}', g1.alliance.reasonKey],
      [
        g1.pathEfficiency.name,
        '${g1.pathEfficiency.score}',
        g1.pathEfficiency.reasonKey
      ],
      [
        g1.pharmacologicalSafety.name,
        '${g1.pharmacologicalSafety.score}',
        g1.pharmacologicalSafety.reasonKey
      ],
    ],
  );
  final stable = g1.alliance.score == g2.alliance.score &&
      g1.pathEfficiency.score == g2.pathEfficiency.score &&
      g1.pharmacologicalSafety.score == g2.pharmacologicalSafety.score;
  r.bullet('${MarkdownReport.ok(stable)} the grading report is a pure function '
      'of the receipt — replay-stable and unit-testable');
  r.endBullets();

  // 4. Cross-session carry-over mechanics (§16).
  r.h2('4. Cross-session carry-over — Postponing decay, trauma & derangement');

  StructuredDelta carryDelta(StateAxis axis, int units, CardType type,
          {ContextFit fit = ContextFit.aligned,
          CardSignature sig = CardSignature.freeze}) =>
      StructuredDelta(
        rulesetVersion: '0.1.0',
        axis: axis,
        // Whole state units, exactly as the resolver emits them.
        deltaMillis: units,
        reasonKey: 'showcase.carryover',
        cardType: type,
        cardSignature: sig,
        contextFit: fit,
      );

  TurnOutput postponingTurn() => TurnOutput(
        nextState: const SimState(seed: 1, turn: 1),
        deltas: [carryDelta(StateAxis.agitation, -3, CardType.postponing)],
        requiredClueTokens: const [],
        outcome: SessionOutcome.ongoing,
      );

  // 4a. Postponing decay accrues across sessions and lifts the baseline.
  const baseAgitation = 30;
  var carry = const CaseHistoryEnvelope();
  final decayRows = <List<String>>[];
  for (var session = 1; session <= 3; session++) {
    carry = ms.buildNextEnvelope(
      memoryClass: MemoryClass.persistent,
      previous: carry,
      sessionOutputs: [postponingTurn(), postponingTurn()],
      manifestClueTokens: const [],
    );
    final start = ms.startingState(
      initialState: const {'agitation': baseAgitation},
      rootSeed: 1,
      envelope: carry,
    );
    decayRows.add([
      '$session',
      '${carry.postponingDecay}',
      '$baseAgitation',
      '${start.agitationLevel}',
    ]);
  }
  r.table(
    ['session', 'accrued decay', 'manifest agitation', 'starting agitation'],
    decayRows,
  );
  r.callout('Repeated Postponing (§16) makes the patient increasingly '
      'impatient: baseline starting agitation climbs each session, bounded by a '
      'config cap so cases stay winnable — a stalling player pays a growing, '
      'deterministic price.');

  // 4b. Trauma carry-over persists as a bounded whole-unit delta.
  final traumaEnv = CaseHistoryEnvelope(carryOverDeltas: [
    carryDelta(StateAxis.trauma, 8, CardType.manipulative,
        fit: ContextFit.mismatched, sig: CardSignature.gambit),
  ]);
  final traumaStart = ms.startingState(
    initialState: const {'trauma': 10},
    rootSeed: 1,
    envelope: traumaEnv,
  );

  // 4c. A low-trust Manipulative failure records an enumerated derangement.
  final derangeEnv = ms.buildNextEnvelope(
    memoryClass: MemoryClass.persistent,
    previous: const CaseHistoryEnvelope(),
    sessionOutputs: [
      TurnOutput(
        nextState: const SimState(seed: 1, turn: 1),
        deltas: [
          carryDelta(StateAxis.trauma, 2, CardType.manipulative,
              fit: ContextFit.mismatched, sig: CardSignature.gambit),
        ],
        requiredClueTokens: const [],
        outcome: SessionOutcome.ongoing,
      ),
    ],
    manifestClueTokens: const [],
  );

  r.bullet('${MarkdownReport.ok(traumaStart.trauma == 18)} trauma carry-over: '
      'manifest trauma 10 + carried 8 → **${traumaStart.trauma}** at next '
      'session start (whole state units, not fixed-point)');
  r.bullet('${MarkdownReport.ok(derangeEnv.derangements.isNotEmpty)} low-trust '
      'Manipulative failure → recorded derangement '
      '**${derangeEnv.derangements.map((d) => d.toJson()).join(', ')}** '
      '(bounded, enumerated, injection-safe)');
  r.endBullets();

  r.writeTo('$showcaseOutputDir/phase2/04-multisession.md');
}

List<InteractionPattern> _cycle(List<InteractionPattern> src, int n) =>
    [for (var i = 0; i < n; i++) src[i % src.length]];
