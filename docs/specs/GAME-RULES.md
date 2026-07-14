# 🎲 C-11 — Session rule model (game-rules design)

> **Closes register item C-11** ([ROADMAP](../planning/ROADMAP.md#-conceptual-corrections-register)).
> The authoritative **design** of the deterministic session mechanics — the
> functional *forms* the pure core (`packages/psycore`) implements and the 2.8
> sandbox tunes. This spec owns the rule **shapes**; every numeric value is owned
> by [C-4](BALANCE-SPEC.md). Section refs (§N) → [`STARTER.md`](../design/STARTER.md).

- **Status:** spec (implemented against in Phase 2.1 / 2.3; tuned in 2.8)
- **Owner:** @maintainer
- **Consumed by:** Phase 2.1 (card taxonomy), 2.3 (resolution / state model / pharmacology), 2.4 (grading), 2.5 (progression curves), 2.8 (sandbox tuning)

## Why this spec exists

The blueprint (§11, §15, §16) describes the session mechanics *qualitatively*;
[C-4](BALANCE-SPEC.md) owns the *numbers*; [C-8](PATIENT-LIFECYCLE.md) owns the
case lifecycle and [C-9](SERVER-DERIVED-QUANTITIES.md) the server-derived
quantities. Nothing else pins the **rule model itself** — the state variables and
their ranges, the card-resolution band function, the outcome-engine thresholds,
the pharmacology model, and the progression-curve *shapes*. Without this, Phase 2
would design those load-bearing rules *inside* `psycore` code, leaving the design
un-reviewable except by reading Dart — the exact failure C-8/C-9 were written to
avoid. This spec closes that gap so the mechanics are a reviewable design before
they are code (documentation-first).

## Ownership boundary (read first)

| Owns | Doc |
|---|---|
| Rule **shapes** — state model, resolution functions, threshold *forms*, outcome partition, pharmacology model, curve *forms* | **C-11 (this doc)** |
| Every **number** — constants, thresholds, coefficients, curve parameters, band widths | [C-4](BALANCE-SPEC.md) |
| Case **lifecycle** state machine + transition guards | [C-8](PATIENT-LIFECYCLE.md) |
| **Server-derived** Doubt, operational pressure, Trauma Severity | [C-9](SERVER-DERIVED-QUANTITIES.md) |
| Prompt assembly + token budget | [C-7](PROMPT-TOKEN-BUDGET.md) / §6 |
| Fictional naming + content integrity | ROADMAP 0.12 |

When this doc names a value (e.g. "1–2 turns", "+2..+5"), it is an **illustrative
placeholder owned by C-4**, quoted only to make the rule shape concrete. If a
number changes, it changes in C-4 — never here, never forked into code.

> **§4 boundary (absolute).** Every rule below is resolved by the **deterministic
> core**. The local model voices dialogue only; it never decides an outcome,
> reads a threshold, or mutates state. Medication and style filters shift *how a
> line sounds*, never *what mechanically happens*.

## 1. Session state model (`SimState`)

The typed state the core owns (evolves the PoC `Map<String,int> axes`, per 2.3).
All fields are **bounded integers or fixed-point** (0.8) and are **clamped to
range after every applied delta** — no float, no wall-clock, no ambient
randomness.

| Field | Type / range (shape) | Meaning |
|---|---|---|
| `trustScore` | int `[0, MAX_TRUST]` | therapeutic alliance |
| `agitationLevel` | int `[0, MAX_AGITATION]` | acute distress / crisis pressure |
| `activeDefense` | enum (fixed catalogue) | the patient's current defensive posture |
| `sessionProgress` | int `[0, turnCap]` | turns elapsed / phase within a session |
| `medicationState` | typed (§7) | prescribed fictional-drug tokens, dosage band, tolerance, dependency |
| `clueProgress` | set of collected clue tokens | drives the §15 siege / breakthrough |

Ranges (`MAX_*`, `turnCap`) are **shapes**; the exact caps are C-4 values. The
state serializes through the one canonical serializer (2.0) and is the input the
2.9 save and the Phase 3 receipt carry.

## 2. Card-resolution band function

Every card play resolves through one function shape:

1. **Context-fit** `fit ∈ {aligned, partial, mismatched}` is computed from the
   card's `signature` against the current state (`trustScore`, `agitationLevel`,
   `activeDefense`) and the patient's axes.
2. Each card type has a **base effect vector** over the state fields.
3. The **band** (the spread of the deterministic draw around the base) is
   **narrow and favourable when `aligned`**, and **widens and shifts unfavourable
   as fit degrades to `partial` then `mismatched`**.
4. Resolution: `draw = prng.nextInt(width)` (integer only, 2.0 PRNG); the applied
   delta = `base ± g(draw, band)`. Aligned → tight band centred on the strong
   effect; mismatched → wide band centred lower and less predictable.

This is the **signature principle** (§16) made mechanical: a card is strong and
predictable *in-context*, weaker and less stable *out-of-context* — reading the
scene beats memorising a deck. The band widths, centres, and the `fit` cut-points
are **C-4 numbers**; the *function form* is owned here. Fixed `(state, card,
seed)` → fixed `fit` → fixed band → **byte-identical** outcome.

## 3. The four card types (functional roles)

Each type is a role, not a fixed win/lose button (§16). Numbers are C-4.

| Type | Signature context (aligned when…) | Primary effect | Special rule |
|---|---|---|---|
| **Disclosing** | a truth/insight is "due" (defense crackable) | large `agitation↓`, `trust↑`, cracks defense, emits due clue | breakthrough tool |
| **Relatable** | rapport-safe, trauma not yet touched | small `trust↑` (placeholder +2..+5), prevents crisis | buffer / stall while gathering clues |
| **Postponing** | crisis pressure needs to be bled off | freezes state 1–2 turns (placeholder) | **multi-session decay**: repeated use raises *baseline* starting agitation across sessions (injected clock) |
| **Manipulative** | defense too rigid for rapport, trust high enough to gamble | three-way partition (§4 below) | high-risk; over-use feeds Doubt (C-9) |

## 4. Manipulative three-way partition

A Manipulative play partitions on **trust state** (and accumulated leverage) into
three deterministic outcomes (§16):

- **Success** (high-trust band): defense shattered, hidden insight / core node
  unlocked, can bypass a study-gate.
- **Partial** (mid band): a new vulnerability exposed, patient more unstable, next
  turn more dangerous.
- **Derangement** (low-trust band): proposes a **derangement mutation as a bounded,
  enumerated structured delta** — a selection from a fixed catalogue of
  secondary-pathology states, **never free text and never an in-place manifest
  rewrite** (0.12). Rendered provisionally on-device; authoritative only on server
  acceptance (C-9 / §16), so a client-claimed derangement cannot inflate the
  Trauma Severity Index.

The partition **cut-points are C-4 numbers**; the three-way shape and the
enumerated-delta rule are owned here.

## 5. Outcome engine (turn → {succeed, fail, stabilize, crisis})

After a play's delta is applied and clamped, the turn is classified by threshold
*shape* over `(trustScore, agitationLevel, clueProgress)`:

- **crisis** — `agitationLevel ≥ crisisThreshold` → routes to the crisis loop / possible walkout.
- **stabilize** — agitation fell below `calmThreshold` and trust ≥ `stableTrustFloor`.
- **succeed** — the case goal is met (clue set complete / core defense cracked).
- **fail** — walkout (agitation spike) or the hard-fail threshold (§18 → `archived`).

Thresholds are **C-4 numbers**; the classification order and the state it reads
are owned here. The engine is a pure function of the receipt's ordered actions —
unit-testable and replay-stable.

## 6. Transference Spike & reclassification

In a high-trauma state, **Relatable plays reclassify as Manipulative failures**
(§16) — the required tactic flips. This is driven entirely by core state (the
trigger threshold is a C-4 number), never by the model.

## 7. Fictional pharmacology model

- **Prescribe** a fictional-drug token (drawn from the 0.12 fictional-taxonomy
  registry; passes the no-real-label lint) at a dosage band.
- **Tolerance** accrues per dose; **dependency** accrues under sustained dosing;
  both are typed integer fields on `medicationState`.
- Each drug **class** has a **side-effect vector** that shifts *case pressure /
  pacing* (e.g. dampens agitation now, raises baseline later) — resolved by the
  core.
- **Medication shifts only dialogue delivery via the style filter — never the
  mechanical outcome** (§4). The mechanical arm is the pressure/pacing shift; the
  *voice* arm is prompt-only.
- A `persistent`-`memory_class` case **inherits chemical dependency from its
  history** (§17), wiring 2.3 pharmacology to the 2.4 carry-over and the 2.7
  over-medication audit.

Effect magnitudes, tolerance/dependency rates, and side-effect vectors are **C-4
numbers**; the model (what accrues, what it feeds, the §4 split) is owned here.

## 8. Progression & economy curve *shapes* (numbers → C-4)

Only the *forms* live here; every coefficient and table entry is a C-4 value.

- **difficulty → XP**: monotone-increasing, **convex** (a harder case is worth
  proportionally more), with **diminishing returns** on grinding trivial cases.
  Implemented as an **integer XP-by-tier table** (no float).
- **reputation**: **event-sourced, recency-weighted** (not a lifetime ratio),
  with **decay via an integer decay table** (no float `exp`) and a
  **credential-based floor** of the form `total_study_fields × base_competency_constant`
  (§14). Recency uses the **injected clock** (0.8), never the device clock.
- **patient-attraction vector** (§10): `reputation + price-accessibility +
  study-coverage`, surfaced as a **UI readout mean** — explicitly **not** the
  routing function (routing is server-owned, Phase 4.5).

## 9. Determinism & integrity invariants

- Every rule is **pure**, integer / fixed-point, on the 2.0 seeded PRNG + injected
  clock (0.8) — a fixed `(state, action, seed)` replays **byte-identically** across
  architectures.
- State is **clamped to range after every delta**; the economy holds the
  **ledger-conservation invariant** (2.5) — rounding never mints or destroys value.
- Outcomes are **structured deltas, never transcripts** (0.6).
- The rule model + PRNG constants are **pinned to `ruleset_version`** (0.7/2.0): a
  change to any rule *shape* is a tracked ruleset bump, not a silent replay break.

## 10. What this spec does NOT own

Numbers ([C-4](BALANCE-SPEC.md)); the lifecycle state machine
([C-8](PATIENT-LIFECYCLE.md)); server-derived Doubt / operational pressure /
Trauma Severity ([C-9](SERVER-DERIVED-QUANTITIES.md)); prompt assembly + token
budget ([C-7](PROMPT-TOKEN-BUDGET.md)); fictional naming + content-integrity rules
(ROADMAP 0.12).

## Test obligations (Phase 2)

- **Card taxonomy (2.1):** each type's signature-in-context beats its
  mismatched-out-of-context outcome across seeds; the Manipulative partition splits
  cleanly by trust; determinism is byte-identical for fixed inputs.
- **Outcome engine (2.3):** all four classifications reached; boundary thresholds
  exercised; a fixed multi-turn case pinned by a golden fixture.
- **Pharmacology (2.3):** tolerance/dependency accrue monotonically; medication
  never alters a mechanical outcome (only pressure/pacing + dialogue voice).
- **Curves (2.5):** difficulty→XP convex + diminishing; reputation decays, floors,
  and shock-responds; no currency minted/destroyed by rounding.

## Open (resolved during 2.x design + 2.8 tuning)

- The exact band widths / centres, `fit` cut-points, outcome thresholds, partition
  cut-points, and every curve table → authored into **[C-4](BALANCE-SPEC.md)** and
  tuned in the 2.8 sandbox.
- The final `activeDefense` enum catalogue and the per-tier clue-set completion
  condition (settled as 2.1 / 2.3 land).
