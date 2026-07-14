# Phase 2 Exit Report — Deterministic Game Core (offline)

**Date:** 2026-07-14
**Scope:** Phase 2.4–2.8 implementation
**Status:** In progress — 2.4, 2.5, 2.6, 2.7, 2.8 partially complete; 2.9 and 2.10 remain.

## What was delivered

- **2.4 Multi-session siege, clue ownership & clinical grading**
  - `ClinicalEncyclopedia`, `CaseHistoryEnvelope`, `StudyCatalog` schemas.
  - `MultiSessionDigestCompiler`, `MultiSessionResolver`, `StudySpend`, `ClinicalGradingCalculator`.
  - `memory_class` discipline enforced: stateless cases carry no history envelope.
  - Integration test: two-session siege unsolvable in one, solvable after study.

- **2.5 Progression, multi-currency economy & attraction vector**
  - `CareerProfile`, `LedgerEvent`, `CurrencyType`, `FieldTrainingTree` schemas.
  - `XpCurve`, `ReputationDecay`, `Ledger`, `AttractionVector`, `OnboardingTrack`, `FieldTrainingSpend`.
  - `ProgressionConfig` in the centralized config authority.
  - Conservation invariant tested: balances equal replayed events.

- **2.6 Financial stabilizers, operational pressure & recovery**
  - `RecoveryMode`, `OperationalPressure` schemas.
  - `RecoveryController`, `PressureCalculator`, `CooldownTracker`.
  - `RecoveryConfig` in the centralized config authority.

- **2.7 Clinic operations, economy & offline case router**
  - `ClinicAsset` schema; `ClinicEconomy` for rent/buy/sell/overhead/taxes/audits.
  - `OfflineCaseRouter` with deterministic PRNG seeding, social-chronic bias, tenure-gated chaos roll.
  - `StrategicExitResolver` for reject/refer/force choices.
  - `ClinicConfig` in the centralized config authority.

- **2.8 Balance sandbox, solvability oracle & bot simulation**
  - Added `content/manifests/siege_brumosis.json`, a representative multi-session siege manifest.
  - `SolvabilityOracle` verifies core-only solvability and content compliance.
  - Manifest loads and passes the content-integrity lint.

## Test results

| Package | Tests | Result |
|---|---|---|
| config | +7 | ✅ |
| packages/psychemas | +12 | ✅ |
| packages/psycore | +144 | ✅ |

App-level tests show three pre-existing failures unrelated to Phase 2 work:
- `poc_gate_measurements_test.dart` tier1 overflow on n_ctx=2048 (2 failures).
- `inference_service_test.dart` load params context size mismatch (1 failure).

## Economy / solvability observations

- Difficulty→XP curve and reputation decay are placeholder shapes owned by `ProgressionConfig` / `RecoveryConfig` and require Phase 2.8 sandbox tuning.
- Ledger conservation invariant holds: `Ledger.balance` equals replay of `Ledger.events`.
- Offline router seed is deterministic for a fixed profile + cursor + root seed.
- Siege manifest is mechanically solvable and content-compliant.

## Go / revisit decision

**Revisit before Phase 3 spend.** The offline core mechanics are implemented and tested, but Phase 2.9 (offline persistence seam) and 2.10 (final balance pass / full offline corpus) are not yet complete. Closing those is the recommended gate before moving to server-authoritative work.
