# Determinism contract

The deterministic core (`packages/psycore/`) guarantees that the same
**state**, **action**, and **seed** always produce the same outcome and the same
serialized delta. This is the foundation of:

- Receipt replay and validation (§3, Phase 3.4).
- Mechanical solvability bots (§2.2, Phase 4).
- Cross-platform fairness (x86 vs ARM).

## Nondeterminism seam

All nondeterminism is injected through two seams:

1. **`SeededPrng`** — a deterministic random source initialized from a seed.
2. **`InjectedClock`** — a monotonic/authoritative time source; in tests it is
   frozen or stepped manually.

No wall-clock, no ambient randomness, and no platform-dependent floating point
may leak into pure rules code.

## Fixed-point economy

All currency, multipliers, ratios, and percentages use integer or fixed-point
representation. Floating point is banned from `core/` and the economy to ensure
byte-identical replay across platforms and to prevent rounding from creating or
destroying value. See `packages/psycore/lib/src/fixed_point.dart`.

## Authoritative time

Time-dependent rules reconcile to server time when online and to the injected
clock when offline:

- Lease TTLs, cooldowns, recovery windows, daily resets → server-authoritative.
- Local durations and monotonic timers → device monotonic source only.
- The device wall clock is treated as untrusted.

## Validation

- `packages/psycore/test/determinism_property_test.dart` asserts identical
  outcomes across repeated runs.
- `packages/psycore/test/fixed_point_test.dart` asserts rounding invariants.
