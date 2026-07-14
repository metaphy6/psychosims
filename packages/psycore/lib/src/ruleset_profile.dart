/// Pinned ruleset profiles for the deterministic core.
///
/// Each [RulesetProfile] carries the exact constants used by the portable PRNG
/// and seed derivation for a given [rulesetVersion]. Changing any constant
/// requires a new profile and a ruleset version bump in
/// `config/ruleset_registry.yaml`.
class RulesetProfile {
  /// The ruleset version this profile belongs to.
  final String rulesetVersion;

  /// SplitMix64 golden gamma constant.
  final int splitMixGamma;

  /// SplitMix64 first multiplier.
  final int splitMixMul0;

  /// SplitMix64 second multiplier.
  final int splitMixMul1;

  const RulesetProfile({
    required this.rulesetVersion,
    required this.splitMixGamma,
    required this.splitMixMul0,
    required this.splitMixMul1,
  });

  /// The initial profile for ruleset `0.1.0`.
  static const RulesetProfile v0_1_0 = RulesetProfile(
    rulesetVersion: '0.1.0',
    splitMixGamma: 0x9e3779b97f4a7c15,
    splitMixMul0: 0xbf58476d1ce4e5b9,
    splitMixMul1: 0x94d049bb133111eb,
  );

  /// Backwards-compatible profile for the PoC ruleset version.
  ///
  /// Uses the same constants as [v0_1_0] so existing PoC manifests and receipts
  /// remain replayable (0.8 wire-compat).
  static const RulesetProfile poc_1_0_0 = RulesetProfile(
    rulesetVersion: 'poc-1.0.0',
    splitMixGamma: 0x9e3779b97f4a7c15,
    splitMixMul0: 0xbf58476d1ce4e5b9,
    splitMixMul1: 0x94d049bb133111eb,
  );

  static const Map<String, RulesetProfile> _registry = {
    '0.1.0': v0_1_0,
    'poc-1.0.0': poc_1_0_0,
  };

  /// Resolves a profile from a [rulesetVersion] string.
  ///
  /// Throws [ArgumentError] if the version is unknown.
  factory RulesetProfile.forVersion(String rulesetVersion) {
    final profile = _registry[rulesetVersion];
    if (profile == null) {
      throw ArgumentError('Unknown ruleset version: $rulesetVersion');
    }
    return profile;
  }

  /// Returns true if a profile exists for [rulesetVersion].
  static bool supports(String rulesetVersion) =>
      _registry.containsKey(rulesetVersion);
}
