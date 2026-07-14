import 'package:psychemas/psychemas.dart';

import 'sim_state.dart';

/// Input to a single deterministic turn resolution.
///
/// All fields are core-facing values. Player-facing copy never reaches the
/// resolver. The [loadout] gates which cards may be played this session; the
/// [library] gates card ownership. The [controllers] feed the §11 sliders into
/// the core as typed tokens, never free text. All are enforced in the core so
/// a receipt cannot claim an unequipped or unowned card (2.2 / Phase 3.3 guard).
class TurnInput {
  final String rulesetVersion;
  final PatientManifest manifest;
  final SimState state;
  final InteractionPattern action;
  final Loadout loadout;
  final CardLibrary library;
  final TherapyControllerSettings controllers;

  const TurnInput({
    required this.rulesetVersion,
    required this.manifest,
    required this.state,
    required this.action,
    required this.loadout,
    required this.library,
    this.controllers = const TherapyControllerSettings(),
  });
}
