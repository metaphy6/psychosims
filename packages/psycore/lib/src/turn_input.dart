import 'package:psychemas/psychemas.dart';

import 'sim_state.dart';

/// Input to a single deterministic turn resolution.
///
/// All fields are core-facing values. Player-facing copy never reaches the
/// resolver.
class TurnInput {
  final String rulesetVersion;
  final PatientManifest manifest;
  final SimState state;
  final InteractionPattern action;

  const TurnInput({
    required this.rulesetVersion,
    required this.manifest,
    required this.state,
    required this.action,
  });
}
