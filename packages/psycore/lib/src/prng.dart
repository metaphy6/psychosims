import 'dart:math' show Random;

/// Seeded deterministic PRNG for the pure core.
class SeededPrng {
  final Random _random;

  SeededPrng(int seed) : _random = Random(seed);

  /// Returns a deterministic int in [min, max).
  int nextInt(int max) => _random.nextInt(max);

  /// Returns a deterministic double in [0.0, 1.0).
  double nextDouble() => _random.nextDouble();
}
