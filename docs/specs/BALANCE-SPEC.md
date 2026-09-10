# 🎚️ C-4 — Multi-currency balance specification

> **Closes register item C-4** ([ROADMAP](../planning/ROADMAP.md#-conceptual-corrections-register)).
> The §9 entry gate and the **single authoritative owner of every constant,
> percentage, and formula** in the design. Skeleton now; tuned in the sandbox
> (Phase 2.8). Section refs (§N) → [`STARTER.md`](../design/STARTER.md).

- **Status:** skeleton (currencies + sources/sinks enumerated; constants are placeholders)
- **Owner:** @maintainer
- **Consumed by:** every gameplay phase; loaded through the central config authority (Principle 1); tuned in Phase 2.8.

> ⚠️ **Every number here is a placeholder** owned by this spec and tuned in the
> balance sandbox (§3). No other doc or module may hard-code these — they load
> from config (Principle 1). This is the one place they live.

## The currencies

| Currency | Earned by (sources) | Spent on (sinks) | Real-money? |
|---|---|---|---|
| **Clinic currency (cash)** | session fees, cures | rent/overhead, taxes, study points, emergency consultations, offices | no (earned) |
| **Study points** | play, daily login, milestones, sabbatical | core field training tree | purchasable with **in-game currency only** |
| **Subspecialty points** | high-tier play, achievements | advanced cross-disciplinary fields | small play-earned + **hard-capped** real-money top-up (§19) |
| **XP** | sessions (difficulty-scaled), milestones | leveling (role/case-tier unlocks) | no |
| **Reputation** | good outcomes (event-sourced, recency-weighted) | decays; floored by credentials | no |
| **Prestige** | endgame milestones, creator royalties | status/legacy unlocks | no |
| **Royalties** | validated fee/cure events on authored cases (§21) | paid out in clinic currency + prestige | no (payout, not purchase) |

Every currency must have **both** a modelled source and a modelled sink. The
sandbox (Phase 2.8) runs sources-vs-sinks, inflation, and **dead-currency**
checks before any live tuning ships (§9).

## Placeholder constants (the single registry)

Grouped as they load into config. All values below are **illustrative** and owned here.

### Progression
- Difficulty→XP curve: harder cases worth proportionally more; trivial-grind diminishing returns (§9).
- Study / subspecialty point earn rates + field-tree costs (foundational cheap → advanced expensive).
- Reputation: recency-weighting half-life; credential-based floor formula; event-shock magnitudes (§10).

### Session / cards
- Active Card Slots per loadout: **5–6** (pick one at tuning) (§11).
- Relatable trust bump: **+2..+5** (§16); Postponing freeze: **1–2 turns**; Postponing multi-session decay rate.
- Manipulative success/partial/derangement thresholds keyed to trust state (§16).

### Routing / ownership
- Chaos "Misfortune Roll": **~5%**, tenure-gated (does not fire below the new-player threshold) (§13).
- Doubt-driven transfer: base **~2–4%/session**, escalating under sustained pressure, hard-capped (§12).
- Social-chronic bias thresholds (early-career level; reputation recovery floor) (§13, §17).
- Referral reward: **+1 XP** for ethical referral (§13).

### Economy / recovery
- Discount Practice XP penalty: **50%**; reputation critical threshold that triggers it (§14).
- Academic Sabbatical: `reputation_floor = total_study_fields × base_competency_constant` (§14).
- Trauma multiplier: **hard cap**, chain-decay rate, provenance carve-out window (§17).

### Institutional (endgame)
- Employer yield: **+25%** illustrative, diminishing per associate, firm-wide hard cap (§24).
- Employee skim rate + **2.0×** study multiplier (§24).
- Hire slots: start 1, scale to cap **6**; associate capability ceiling **+5** levels (§24).
- Clinic buy gate (capital + min level); structural-collapse threshold **<20%** (§22, §24).

### Offline / server
- Ownership lease TTL: **48–72 h** (§3).
- `ruleset_version` sunset: **90 days** after supersession (§3).
- Per-tier receipt plausibility bounds (XP/currency/reputation caps per session) (§3).

## Tuned values (Phase 2.8)

The 2.8 balance sandbox ran the deterministic core without inference on the
committed case corpus (`content/manifests/`). Findings and the first tuned
constants are recorded below; config is the single owner of every number.

| Constant | Tuned value | Source / rationale |
|---|---|---|
| Active card slots per loadout | **6** | Sandbox keeps all four card types relevant; 6 gives room for one of each plus flex slots. |
| Postponing freeze turns | **2** | Tempo control is meaningful but not a permanent stall. |
| Success progress threshold | **100** | Single-session cases resolve at the turn cap; multi-session siege cases are authored to require study + return. |
| Crisis threshold | **80** | Visible warning band before walkout at 95. |
| Walkout threshold | **95** | Hard fail floor. |
| Relatable aligned trust bump | **+3 centre, ±1 roll** | Expert bots build trust safely; novice random play still progresses. |
| Disclosing aligned resistance drop | **−4 centre, ±1 roll** | Cracks guarded/rigid defense in 2–3 aligned plays. |
| Manipulative success trust floor | **70** | Gambit is reliable only after rapport building. |
| Manipulative partial trust floor | **40** | Below this, derangement risk rises. |
| Transference Spike trauma floor | **70** | High-trauma Relatable plays reclassify to Manipulative failures. |
| Sandbox cash per win | **1.5 cash units** | Sources exist; overhead sink of 1.0 cash/run keeps inflation flag green. |
| Sandbox overhead per run | **1.0 cash unit** | Proxy for rent/overhead; ensures cash has a sink in the sandbox economy. |

### Sandbox diagnostics (median over 60 runs, 2 manifests, 3 skills)

- Overall win-rate: **83 %** (10 seeds × 3 skills × 2 manifests).
- Novice / Expert win-rate on `poc-vexa-001`: **100 %**.
- Intermediate win-rate on `siege.brumosis`: **50 %** — confirms the siege case
  is not trivially solved by heuristic play and rewards study unlocks.
- Throughput: **>1000 sessions/second** on the reference environment, satisfying
  the Phase 2.8 budget placeholder.
- Dead currencies flagged in the sandbox proxy economy:
  study, xp (no sink in the proxy), subspecialty, prestige (no source yet).
  These are expected: the proxy only models session rewards + cash overhead.
  Full career sinks (field training, clinic purchases, taxes) remove these flags
  in the integrated career model (Phase 2.9/3).

## Tuning process (Phase 2.8)

1. Load all constants from config (never hard-coded).
2. Run bot scenarios across skill levels + parameter mutations (§3 sandbox).
3. Check: currency sources vs sinks balance; no runaway inflation; no dead currency;
   no dominant/degenerate strategy.
4. Record tuned values back **here**; config reads them; the sim core consumes config.

## Open (resolved during tuning)

- Exact difficulty→XP and reputation-decay curve shapes (placeholder shapes remain).
- Whether subspecialty real-money cap is a % of attainable (per §19) — confirm the %.
- Final clinic-economy constants (rent, tax brackets) will be tuned once 2.9
  integrates the full career ledger with sinks.
