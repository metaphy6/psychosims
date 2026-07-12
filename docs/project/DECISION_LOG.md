# 🗳 Decision log

Append-only log of **meta-decisions** about Psychosims. Code-level architectural
decisions go in [`../design/`](../design/) as ADRs. Section refs (§N) point at
[`STARTER.md`](../../STARTER.md); audit refs point at [`../reports/`](../reports/).

| # | Date | Decision | Context | Consequence | Owner |
|---|---|---|---|---|---|
| 0001 | 2026-07-04 | Replace the P2P foundation with a server-client model | P2P could not enforce identity, moderation, ownership, or the economy (2026-07-04 audit) | Small but authoritative server owns all trustworthy state; see [ADR-0001](../design/ADR-0001-server-authoritative-control-plane.md). | @maintainer |
| 0002 | 2026-07-04 | Ship **no** free-form player messaging / chat | Chat is the single largest moderation, safety, and legal surface for a small team (§1) | Social features are structured, typed interactions only (referrals, hiring, reputation). | @maintainer |
| 0003 | 2026-07-04 | Fictional clinical taxonomy across the whole pipeline | Real DSM/ICD labels + drug brands are IP and store-review risk (§8) | No real diagnostic label or medication appears in any game content; real frameworks inform design only. | @maintainer |
| 0004 | 2026-07-04 | Case history is revocable + signed, not immutable | You cannot moderate or honour erasure on a permanently immutable ledger (§17) | Tamper-evident entries + a server revocation list; clients drop revoked entries. | @maintainer |
| 0005 | 2026-07-07 | Server does **not** re-derive session outcomes | A second server-side rules build is costly and drifts from the client (2026-07-07, NC-4) | Receipts validated via plausibility bounds + anomaly detection + `ruleset_version` pinning (§3). | @maintainer |
| 0006 | 2026-07-07 | No monthly model retrain-and-ship pipeline | An MLOps retrain loop contradicts the fixed-footprint model + needs a team we lack (§18) | Bug logs feed an offline, opt-in improvement queue; the asylum mechanic is pure client-state freeze. | @maintainer |
| 0007 | 2026-07-07 | Defer paid cosmetics to post-launch | Cosmetics are not core; launching without them reduces scope + review surface (§19) | Launch with a common functional UI; architecture stays cosmetic-ready (theming hooks, skin slots). | @maintainer |
| 0008 | 2026-07-09 | Encode the corrected patient-lifecycle state machine | The original lifecycle forbade transitions the mechanics require (GM-1) | `pool ⇄ owned`, referral, temporary hospitalization, cure/archival are all first-class (§18); built in Phase 3.6. | @maintainer |
| 0009 | 2026-07-11 | Keep server-client; do not revert to P2P | Re-examined P2P vs server cost (2026-07-11 assessment) | Verdict **no**: server-client retained; cost is modelled explicitly per MAU tier. | @maintainer |
| 0010 | 2026-07-11 | Centralized configuration is mandatory, no exceptions | Scattered per-module/per-env config is a maintainability trap (roadmap Principle 1) | One typed, validated `config/` authority; see [DESIGN-centralized-configuration](../design/DESIGN-centralized-configuration.md). | @maintainer |
| 0011 | 2026-07-11 | Tests target load-bearing logic, not blanket TDD | Prioritize working software + speed while protecting the risky core (roadmap Principle 4) | Sim core, economy, prompt assembler, and receipt validation are tested; UI/content iterate fast. | @maintainer |
| 0012 | 2026-07-11 | Desktop = Steam (Win/macOS) + direct signed download (Linux); identity = unified Google/Apple OAuth | Closing C-5: all five platforms needed a named channel + sign-in path (§3) | One portable server account across every channel; Steam is distribution only. See [ADR-0002](../design/ADR-0002-desktop-distribution-and-auth.md). | @maintainer |
| 0013 | 2026-07-11 | Target a mature age band (ESRB 17+ / PEGI 16–18) with Manipulative-card tone guidelines | Closing C-6: the derangement loop (§16) will be scrutinized (§8) | Content framed as "clinical gamble, not cruelty"; finalized pre-submission (Phase 7.5). See [C-6](../specs/AGE-RATING-AND-CONTENT-STRATEGY.md). | @maintainer |
| 0014 | 2026-07-11 | Entry-gate artifacts (C-1…C-10) live under `docs/specs/` as the single owner of their subject | Addressing the roadmap corrections register in one pass | Specs are living references; later phases edit them in place, never fork a second copy. See [docs/specs/](../specs/README.md). | @maintainer |
| 0015 | 2026-07-12 | Provisional base model: permissive-licensed only — Tier A **Qwen2.5 1.5B (Apache-2.0)** primary + **Phi-3.5-mini (MIT)** comparator, Tier B **SmolLM2 1.7B (Apache-2.0)** | Commercial redistribution of embedded weights demands minimal legal surface; custom-license models (Gemma, Llama) add notice/AUP/attribution/MAU obligations (C-2) | Bundle Apache-2.0/MIT weights; custom-license models deferred unless they clearly win the Phase 1.6 acting-quality gate; final pick confirmed at PoC. See [C-2](../specs/MODEL-LICENSE-SHORTLIST.md). | @maintainer |

## Rules

- **Append-only.** Reversing a decision = a new row that references the prior one.
- **One line per decision.** Anything longer becomes an ADR in [`../design/`](../design/).
- **Owner is a real person**, not a team — the human accountable for the consequence.
