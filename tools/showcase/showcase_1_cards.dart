import 'dart:io';

import 'package:psychemas/psychemas.dart';
import 'package:psycore/psycore.dart';

import 'report.dart';

/// Showcase 1 — Card taxonomy & signature principle (Phase 2.1).
///
/// Demonstrates: the four card types + their signatures, context-biased
/// resolution (a play is stronger/more predictable in-context), and the
/// Manipulative three-way partition keyed to trust state.
void main() {
  final r = MarkdownReport(
    'Showcase 1 — Card Taxonomy & Signature Principle (2.1)',
    subtitle: 'Four card types · context-fit resolution · Manipulative '
        'three-way partition',
  );

  final manifest = const ManifestLoader()
      .load(File('content/manifests/poc_sample.json').readAsBytesSync());

  // A. Taxonomy map.
  r.h2('1. Card taxonomy — every interaction pattern is a typed card');
  r.table(
    ['interaction pattern', 'card id', 'type', 'signature'],
    [
      for (final p in manifest.interactionPatterns)
        [
          p.toJson(),
          cardFromInteractionPattern(p).id,
          cardFromInteractionPattern(p).type.toJson(),
          cardFromInteractionPattern(p).signature.toJson(),
        ],
    ],
  );
  r.callout('Each of the four types (disclosing / relatable / postponing / '
      'manipulative) resolves on its **type + signature** only — visual variety '
      'never shifts an outcome (§4 boundary).');

  // B. Context-biased resolution across a state grid.
  r.h2('2. Context-biased resolution — same card, different scenes');
  final library = CardLibrary(
      ownedCardIds: manifest.resolvedCards.map((c) => c.id).toSet());
  final loadout = Loadout(
      cardIds: manifest.resolvedCards.map((c) => c.id).toList(), slotCap: 6);
  const resolver = TurnResolver(InjectedClock.replay(0));

  final scenes = <(String, SimState)>[
    (
      'calm + trusting',
      _state(trust: 70, agitation: 20, defense: DefenseState.none)
    ),
    (
      'guarded + tense',
      _state(trust: 40, agitation: 60, defense: DefenseState.guarded)
    ),
    (
      'rigid + hostile',
      _state(trust: 20, agitation: 85, defense: DefenseState.rigid)
    ),
  ];

  for (final p in manifest.interactionPatterns) {
    r.h3('Card: `${p.toJson()}` '
        '(${cardFromInteractionPattern(p).type.toJson()} / '
        '${cardFromInteractionPattern(p).signature.toJson()})');
    r.table(
      ['scene', 'context fit', 'Δ trust', 'Δ agitation', 'outcome'],
      [
        for (final scene in scenes)
          _resolveRow(
              resolver, manifest, loadout, library, p, scene.$1, scene.$2),
      ],
    );
  }

  // C. Manipulative three-way partition.
  r.h2('3. Manipulative resolution partitions by trust state');
  final manipPattern = InteractionPattern.values.firstWhere(
    (p) => cardFromInteractionPattern(p).type == CardType.manipulative,
    orElse: () => manifest.interactionPatterns.first,
  );
  final withManip = {...manifest.interactionPatterns, manipPattern}.toList();
  final m2 = manifest.copyWith(interactionPatterns: withManip);
  final lib2 =
      CardLibrary(ownedCardIds: m2.resolvedCards.map((c) => c.id).toSet());
  final load2 =
      Loadout(cardIds: m2.resolvedCards.map((c) => c.id).toList(), slotCap: 8);
  final manipCard = cardFromInteractionPattern(manipPattern);
  r.p('Playing `${manipPattern.toJson()}` '
      '(type=${manipCard.type.toJson()}, signature=${manipCard.signature.toJson()}) '
      'at rising trust:');
  r.table(
    ['trust state', 'context fit', 'Δ trust', 'Δ agitation', 'outcome'],
    [
      for (final trust in [20, 50, 85])
        _resolveRow(resolver, m2, load2, lib2, manipPattern, 'trust=$trust',
            _state(trust: trust, agitation: 55, defense: DefenseState.rigid)),
    ],
  );
  r.callout(
      'A low-trust Manipulative failure proposes a **derangement mutation** '
      'as a bounded, enumerated structured delta — never free text, never an '
      'in-place manifest rewrite (injection-safe, 0.12).');

  r.writeTo('$showcaseOutputDir/01-cards.md');
}

SimState _state({
  required int trust,
  required int agitation,
  required DefenseState defense,
}) =>
    SimState(
      seed: 20260715,
      trustScore: trust,
      agitationLevel: agitation,
      activeDefense: defense,
    );

List<String> _resolveRow(
  TurnResolver resolver,
  PatientManifest manifest,
  Loadout loadout,
  CardLibrary library,
  InteractionPattern action,
  String label,
  SimState state,
) {
  final out = resolver.resolve(TurnInput(
    rulesetVersion: '0.1.0',
    manifest: manifest,
    state: state,
    action: action,
    loadout: loadout,
    library: library,
  ));
  final fit = out.deltas.isEmpty ? 'n/a' : out.deltas.first.contextFit.toJson();
  return [
    label,
    fit,
    _fmt(_axisDelta(out, StateAxis.trust)),
    _fmt(_axisDelta(out, StateAxis.agitation)),
    out.outcome.toJson(),
  ];
}

int _axisDelta(TurnOutput out, StateAxis axis) => out.deltas
    .where((d) => d.axis == axis)
    .fold(0, (s, d) => s + d.deltaMillis);

String _fmt(int delta) {
  final sign = delta > 0 ? '+' : '';
  return '$sign$delta';
}
