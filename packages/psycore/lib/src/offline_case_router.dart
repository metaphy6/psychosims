import 'package:psychemas/psychemas.dart';

import 'prng.dart';
import 'seed_derivation.dart';

/// Configuration values consumed by [OfflineCaseRouter].
class OfflineCaseRouterConfig {
  final int socialChronicBiasThreshold;
  final int chaosRollProbabilityMillis;
  final int chaosTenureGate;

  const OfflineCaseRouterConfig({
    this.socialChronicBiasThreshold = 20,
    this.chaosRollProbabilityMillis = 50,
    this.chaosTenureGate = 3,
  });
}

/// Deterministic, resumable offline case router (§10 / §13 local precursor to
/// Phase 4.5).
///
/// Pricing, reputation, and study-field coverage weight the incoming case
/// stream in fixed-point. The router is reseeded from the profile so an app
/// restart regenerates the identical stream.
class OfflineCaseRouter {
  final OfflineCaseRouterConfig config;

  const OfflineCaseRouter(this.config);

  /// Generates the next case seed for [profile] at [cursor].
  ///
  /// [profile] provides reputation, pricing, and unlocked fields.
  /// [tierBias] is the player's preferred case tier (e.g. from pricing slider).
  /// [cursor] is the persistent router cursor (must be replayed after restart).
  CaseRouterSeed nextCase({
    required CareerProfile profile,
    required int tierBias,
    required int playerLevel,
    required int cursor,
    required int rootSeed,
    String rulesetVersion = '0.1.0',
  }) {
    final seed = deriveRouterSeed(
      profileId: profile.profileId,
      cursor: cursor,
      rootSeed: rootSeed,
    );
    final prng = SeededPrng.forRuleset(seed, rulesetVersion);

    // Social-chronic bias: low-reputation players see more stateless cases.
    final reputation = profile.snapshotBalancesMicros['reputation'] ?? 0;
    final socialBias = reputation <= config.socialChronicBiasThreshold;

    // Chaos roll: only for tenured players, small chance of a misfortune case.
    final roll = prng.nextInt(1000);
    final misfortune = playerLevel >= config.chaosTenureGate &&
        roll < config.chaosRollProbabilityMillis;

    // Tier selection: deterministic around the bias, jittered by PRNG.
    final jitter = prng.nextInt(3) - 1; // -1, 0, +1
    var tier = (tierBias + jitter).clamp(1, 5);
    if (misfortune) tier = tier.clamp(3, 5);

    // Memory class: persistent cases only when not social-biased.
    final memoryClass = socialBias && prng.nextInt(1000) < 700
        ? MemoryClass.stateless
        : MemoryClass.persistent;

    return CaseRouterSeed(
      cursor: cursor,
      seed: seed,
      tier: tier,
      memoryClass: memoryClass,
      misfortune: misfortune,
    );
  }
}

/// A deterministic case slot produced by the router.
class CaseRouterSeed {
  final int cursor;
  final int seed;
  final int tier;
  final MemoryClass memoryClass;
  final bool misfortune;

  const CaseRouterSeed({
    required this.cursor,
    required this.seed,
    required this.tier,
    required this.memoryClass,
    required this.misfortune,
  });
}
