import 'ruleset_profile.dart';

/// Portable, specified integer PRNG for the deterministic core.
///
/// Implements SplitMix64 using explicit 64-bit unsigned wrapping arithmetic.
/// The algorithm and constants are pinned to a [RulesetProfile] selected by
/// `ruleset_version` (0.7): any change is a tracked ruleset bump, not a silent
/// replay break.
///
/// Only integer draws are exposed on the core path. There is no `nextDouble`,
/// no `dart:math.Random`, and no platform-dependent float sequence.
class SeededPrng {
  final RulesetProfile _profile;
  int _state;

  /// Creates a PRNG from a 64-bit seed and a pinned [profile].
  SeededPrng(int seed, this._profile) : _state = seed & 0xFFFFFFFFFFFFFFFF;

  /// Creates a PRNG from a 64-bit seed and a ruleset version string.
  factory SeededPrng.forRuleset(int seed, String rulesetVersion) {
    return SeededPrng(seed, RulesetProfile.forVersion(rulesetVersion));
  }

  /// Returns the next 64-bit unsigned integer in the sequence.
  int nextUint64() {
    _state = (_state + _profile.splitMixGamma) & 0xFFFFFFFFFFFFFFFF;
    var z = _state;
    z = ((z ^ (z >> 30)) * _profile.splitMixMul0) & 0xFFFFFFFFFFFFFFFF;
    z = ((z ^ (z >> 27)) * _profile.splitMixMul1) & 0xFFFFFFFFFFFFFFFF;
    z = z ^ (z >> 31);
    return z;
  }

  /// Returns a deterministic int in [0, max).
  ///
  /// Uses rejection sampling in 32-bit unsigned space to avoid modulo bias
  /// when [max] does not evenly divide 2^32. [max] must be positive and
  /// small enough to fit in 32 bits (more than enough for all core draws).
  int nextInt(int max) {
    if (max <= 0) {
      throw ArgumentError('max must be positive: $max');
    }
    if (max == 1) return 0;
    // Fast path for powers of two.
    if ((max & (max - 1)) == 0) {
      return nextUint64() & (max - 1);
    }
    const full = 0xFFFFFFFF; // 2^32 - 1
    final limit = full - ((full % max) + 1) % max;
    while (true) {
      final draw = nextUint64() & 0xFFFFFFFF;
      if (draw <= limit) return draw % max;
    }
  }

  /// Returns a deterministic int in [min, max).
  int nextIntRange(int min, int max) {
    if (min >= max) {
      throw ArgumentError('min must be less than max: $min >= $max');
    }
    return min + nextInt(max - min);
  }
}
