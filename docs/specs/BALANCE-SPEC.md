# 🎚️ C-4 — Multi-currency balance specification

> **Closes register item C-4** ([ROADMAP](../planning/ROADMAP.md#-conceptual-corrections-register)).
> The §9 entry gate and the **single authoritative owner of every constant,
> percentage, and formula** in the design. Skeleton now; tuned in the sandbox
> (Phase 2.8). Section refs (§N) → [`STARTER.md`](../../STARTER.md).

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

## Tuning process (Phase 2.8)

1. Load all constants from config (never hard-coded).
2. Run bot scenarios across skill levels + parameter mutations (§3 sandbox).
3. Check: currency sources vs sinks balance; no runaway inflation; no dead currency;
   no dominant/degenerate strategy.
4. Record tuned values back **here**; config reads them; the sim core consumes config.

## Open (resolved during tuning)

- Final value for every placeholder above.
- Exact difficulty→XP and reputation-decay curve shapes.
- Whether subspecialty real-money cap is a % of attainable (per §19) — confirm the %.
