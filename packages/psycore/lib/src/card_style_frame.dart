import 'package:psychemas/psychemas.dart';

/// Linguistic Vector / style-filter hook (§16 AI-fatigue countermeasure).
///
/// Returns a deterministic style token from the resolved card type and the
/// patient's [StyleArchetype]. The prompt assembler can insert this token as
/// data to make identical mechanics sound distinct, without letting the
/// dialogue layer change any outcome (§4 boundary).
String resolveCardStyleFrame(CardType cardType, StyleArchetype archetype) {
  final archetypeName = archetype.name;
  return switch (cardType) {
    CardType.disclosing => '${archetypeName}_disclosing_voice',
    CardType.relatable => '${archetypeName}_relatable_voice',
    CardType.postponing => '${archetypeName}_postponing_voice',
    CardType.manipulative => '${archetypeName}_manipulative_voice',
  };
}

/// Card aesthetic-variety presentation hook (§16).
///
/// Resolves a surface-form token for a card from its type. This lives in the
/// presentation layer; the deterministic core resolves on type + signature
/// only, so visual variety never shifts an outcome (§4 boundary).
String resolveCardPresentationForm(CardType cardType, {required int seed}) {
  final forms = switch (cardType) {
    CardType.disclosing => ['full_sentence', 'compact_phrase', 'symbolic_cue'],
    CardType.relatable => ['warm_paragraph', 'brief_validation', 'gesture'],
    CardType.postponing => ['containment_ritual', 'pause_marker', 'breath_cue'],
    CardType.manipulative => [
        'framing_question',
        'reframe_probe',
        'tactical_nudge'
      ],
  };
  return forms[seed.abs() % forms.length];
}
