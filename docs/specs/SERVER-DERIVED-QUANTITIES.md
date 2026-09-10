# 🖥️ C-9 — Server-derived hidden quantities

> **Closes register item C-9** ([ROADMAP](../planning/ROADMAP.md#-conceptual-corrections-register)).
> The three cross-session quantities that drive server-authoritative outcomes must
> be **derived server-side from accepted receipts** — never client-reported
> (resolving audit findings GM-2/GM-3). Section refs (§N) → [`STARTER.md`](../design/STARTER.md).

- **Status:** spec complete (implemented in Phase 5.3 + 5.5)
- **Owner:** @maintainer
- **Consumed by:** Phase 5.3 (Trauma Severity Index), Phase 5.5 (Doubt, operational pressure)

## The axiom this enforces

"A client-computed number is a claim, not a fact" (§3). A client-owned value for
any of these would let a player **suppress** patient loss (Doubt), **understate**
routing load (operational pressure), or **inflate** a bounty (Trauma Severity).
The machinery to derive them already exists: accepted receipts carry ordered
card/medication actions and pricing history is server-known.

## The three quantities

### 1. Doubt (§12) — patient transfer pressure
- **Inputs (from accepted receipts):** repeated Manipulative-card use; sharp
  session-price rises across consecutive sessions; time.
- **Derivation:** server accrues Doubt per accepted receipt; rises gradually,
  spikes under the above stressors.
- **Action:** if Doubt crosses its threshold, the **server executes** the stochastic
  transfer roll (base ~2–4%/session, escalating, hard-capped — placeholders in [C-4](BALANCE-SPEC.md)).
- **Never:** held or rolled client-side.

### 2. Operational pressure (§23) — routing + recovery input
- **Inputs:** receipt cadence (sessions over time) and case tier.
- **Derivation:** server computes pressure so it is a **trustworthy routing input**
  (§4.5 / §2.3) and drives visible recovery states (§23) — not a hidden client value.
- **Action:** feeds matchmaking weighting + recovery-window triggers.
- **Never:** a client-held stat; there is no hidden well-being value (§10, §23).

### 3. Trauma Severity Index (§17) — bounty multiplier
- **Inputs:** the signed history entries (mistreatment/misdiagnosis/crisis outcomes)
  from accepted receipts.
- **Derivation:** server-side function over the signed envelope; grows with genuine
  abuse history only.
- **Action:** multiplies XP / leaderboard score / currency payouts on cure, under the
  §17 anti-collusion guards (cap, chain-decay, provenance carve-out, anomaly detection).
- **Never:** a client-reported severity; a client-claimed derangement cannot inflate it.

## Client-proposes / server-decides (resolves GM-3)

Derangement (§16) and other manifest changes are **proposed** by the client as
structured **session deltas in the receipt**, rendered *provisionally* on-device.
The authoritative case state updates — and the manifest is **re-signed** — only on
server acceptance (§3). A client never mutates a server-signed manifest directly;
this is the exact client-proposes/server-decides pattern §1 mandates.

## Common properties

- **Derived only from *accepted* receipts** (post-validation, §3) — rejected/anomalous
  receipts never contribute.
- **Idempotent** under the receipt idempotency key (§3) — a re-submitted receipt
  never double-counts.
- **All constants** (accrual rates, thresholds, caps, decay) are placeholders owned by
  [C-4](BALANCE-SPEC.md) and tuned in the sandbox (§3).

## Test obligations (Phase 5.3 / 5.5)

- A client cannot change any of the three by sending a crafted value (only accepted
  receipts move them).
- Doubt transfer roll executes server-side and respects the hard cap.
- Trauma Severity accrues only from genuine abuse history; A→B→A collusion pays B nothing (§17).
- Provisional client-side derangement never affects the authoritative index until acceptance.

## Open

- Exact accrual/decay formulas and thresholds → [C-4](BALANCE-SPEC.md) + Phase 2.8/5.x tuning.
