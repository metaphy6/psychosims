# ✅ Psychosims — `STARTER.md` Readiness Assessment for Technical Roadmapping

- **Date:** 2026-07-07
- **Source under review:** [`STARTER.md`](../../STARTER.md) (§1–§24), as of commit `6b09820`
  (`docs(starter): replace P2P architecture with server-client model`).
- **Prior audit:** [`2026-07-04-starter-assessment.md`](2026-07-04-starter-assessment.md)
  (13 contradictions, 9 unvalidated assumptions, 7 economy risks, 6 legal exposures).
- **Question answered:** *Is the blueprint ready to move to the next stage — technical
  roadmapping (replacing the placeholder phases in
  [`docs/planning/ROADMAP.md`](../planning/ROADMAP.md) with a real, sequenced plan)?*
- **Type:** One-time audit snapshot. Do not hand-edit after commit.

---

## 1. Executive verdict

> **VERDICT: CONDITIONAL GO — the blueprint is ready to enter technical roadmapping,
> subject to the five conditions in §7.**

This is a provable statement, not an opinion, and the proof structure is:

1. **The readiness bar is defined first** (§2: ten criteria R1–R10, chosen before scoring).
2. **Every prior audit finding is re-verified against the current text** (§4): of the 35
   findings from 2026-07-04, **29 are fully resolved, 5 are partially resolved and
   re-tracked below as gaps, 1 is carried forward open** (age-rating strategy). Every
   status cites the exact section of the current `STARTER.md` that resolves it.
3. **A fresh conflict scan of the revised text** (§5) finds **8 new/residual findings
   (NC-1…NC-8)**. Critically: *none is foundational.* Each is either a bounded text edit,
   an architecture decision that belongs inside the roadmap's phase definitions, or a
   scheduled deliverable. None invalidates the product concept, the authority model, or
   the PoC-first sequence.
4. **The verdict follows mechanically from the scorecard** (§2): 6 PASS, 3 PARTIAL,
   1 CONDITIONAL-FAIL, no hard FAIL on any criterion that blocks *starting* roadmapping.

What changed since 2026-07-04 and drives this verdict: the four revision commits removed
the P2P foundation, removed free-form chat, made the clinical taxonomy fully fictional,
made the case history revocable, made the server explicitly authoritative, and converted
the project's three biggest technical bets into falsifiable Phase-0 gates. The
document no longer fights itself on any load-bearing wall. What remains are edge-of-spec
inconsistencies and missing artifacts — exactly the kind of items a roadmap exists to
schedule.

**What "conditional" means concretely:** conditions 1–3 (§7) are text edits to
`STARTER.md` achievable in a single editing pass; conditions 4–5 shape what the roadmap's
Phase 0/1 must contain. None requires new design exploration.

---

## 2. Readiness scorecard

Criteria fixed before scoring. "Ready for technical roadmapping" means: a competent
engineer could decompose this document into phases with entry/exit gates without having
to invent missing intent or arbitrate contradictions on load-bearing decisions.

| # | Criterion | Score | Evidence |
|---|---|---|---|
| R1 | Product concept, fantasy, and non-goals unambiguous | ✅ PASS | §1 (role-driven sim, explicitly fictional); §2 (no chat, with rationale); §4 (legal framing) |
| R2 | Core gameplay loop specified end-to-end | ✅ PASS | §2 (UI → case → prompt → inference → render); §8/§16 (sim core vs dialogue split); §9 (card input); §15 (card taxonomy) |
| R3 | First milestone falsifiable with measurable gates | ✅ PASS* | §2 PoC gates: acting quality under worst-case prompts, device viability vs written spec, download acceptance — with fallback plan (1–1.5B) and "revisit architecture if red". *Gate has one methodological flaw (NC-6, emulator perf) — fixable in one line |
| R4 | Authority & trust model coherent end-to-end | ✅ PASS | §2 ("client proposes, never self-certifies"; server-authoritative identity "for the life of the product"); §7 (receipt validation); §10 (server-arbitrated ownership); §17 (revocable signed history). No remaining authority contradictions found |
| R5 | Data model free of storage contradictions | ⚠️ CONDITIONAL FAIL | NC-1 (referral "dialogue history" vs no-transcript rule vs 50 KB cap); NC-8 (offline receipt semantics undefined). Both bounded; neither invalidates the split-storage architecture |
| R6 | Economy governance defined | ✅ PASS (artifacts pending) | §5 ("multi-currency balance is a first-class design deliverable"; all constants are placeholders owned by one balance spec); §7 (sandbox is core infrastructure); §17 (anti-collusion); §24 (diminishing returns + cap). The balance spec and cost model are *commissioned but not yet produced* (G-4) — a roadmap deliverable, not a blocker |
| R7 | Legal / store exposure managed | ◐ PARTIAL | Strong: §4 (fictional taxonomy enforced across pipeline, incl. §10 and §14 encyclopedia; naming principle; disclaimers; PII separation). Open: NC-3 (paid-cosmetic confiscation), G-2 (no age-rating strategy), G-7 (model license unpinned) |
| R8 | Scope sequenced against dependencies | ◐ PARTIAL | Good sequencing honesty: §9 (oracle is post-launch), §18 (no retraining pipeline), §2 (PoC gates everything). Missing: any statement of team/capacity/timeline (G-5); ~20 major systems still described with no cost attached |
| R9 | Prior-audit debt cleared | ✅ PASS | §4 below: 29/35 fully resolved with citable text; 5 partial → re-tracked; 1 carried (G-2). No prior *contradiction* (C-class) survives |
| R10 | No remaining blocking contradictions | ✅ PASS (with register) | 8 findings in §5; severity distribution: 0 blockers, 6 major (all bounded edits/decisions), 2 minor |

**Score: 6 PASS / 3 PARTIAL / 1 CONDITIONAL-FAIL / 0 blocking FAIL → conditional go.**

---

## 3. What is genuinely strong in the current revision

Credit where due — several of these are rare at blueprint stage, and they are the
reason the verdict is GO rather than "iterate again":

1. **All 13 prior contradictions fixed with named mechanisms, not hand-waving.**
   E.g., revocability replaced immutability (§17), `memory_class: stateless` replaced a
   convention (§10, §17), "small but authoritative" replaced "minimal" with an enumerated
   responsibility list (§2).
2. **The three existential bets are explicit, falsifiable, and gated before spend**
   (§2): small-model acting quality under *worst-case* prompts, device viability against
   a written minimum spec with a tested fallback, and download acceptance. Including the
   sentence "if these gates are red, the architecture is revisited" is exactly right.
3. **The no-chat decision** (§2) deletes the project's single largest moderation, legal,
   and duty-of-care surface in one move, and the doc correctly re-derives its social
   features as structured, typed interactions.
4. **Clue ownership** (§8): the simulation core injects mandatory clue tokens and
   validates they survive generation, with a templated fallback — this makes case
   solvability independent of LLM reliability. This single paragraph de-risks the entire
   "playable game on a 1–3B model" premise.
5. **Placeholder discipline** (§5): every constant in the document is declared a
   placeholder owned by one balance spec and tuned in the sandbox. This kills the
   "implement placeholder math as gospel" failure mode the prior audit flagged (D6).
6. **Scope honesty labels**: the adaptive oracle is explicitly a post-launch server-side
   tool (§9); the PKI is named as real infrastructure with a recovery flow (§7); the
   free tier is explicitly *not* a capacity plan (§7); the asylum mechanic explicitly
   does *not* imply a model-retraining pipeline (§18).
7. **Anti-collusion provenance guards** on the trauma multiplier (§17) close the
   A→B→A farming loop the prior audit identified (D1) with concrete mechanisms: caps,
   no multiplier on friend referrals, chain-diminishing returns, anomaly detection.
8. **Lifecycle accounting** (§18): `active → owned → (cured | abandoned | hospitalized)
   → archived` replaces the "nothing is ever deleted" slogan with real state semantics.
9. **The enforced SKU test** (§19): every monetized item must pass the non-pay-to-win
   test or be cut/converted to in-game currency; royalties pay out in-game only (§21),
   avoiding real-money payout compliance entirely.

---

## 4. Prior-audit resolution verification (the proof of progress)

Every finding from [`2026-07-04-starter-assessment.md`](2026-07-04-starter-assessment.md),
re-verified against the current text. Statuses: ✅ resolved · ◐ partial · ❌ open.

### Contradictions C1–C13 — 13/13 resolved

| ID | Was | Status | Evidence in current text |
|---|---|---|---|
| C1 | DSM-5 diagnoses vs fictional-content rule | ✅ | §10: "Clinical Axis (Fictional Core) … invented clinical taxonomy"; §14: "fictional clinical encyclopedia — a fully invented reference"; §4: rule made "authoritative across the entire content pipeline" |
| C2 | Accounts migrating into P2P vs cloud anchor | ✅ | P2P removed entirely; §2: "Server-Authoritative Identity (Permanent) … for the life of the product" |
| C3 | Immutable ledger vs moderation/erasure | ✅ | §17: "tamper-evident … deliberately *not* immutable … revocation list"; explicit note that you cannot moderate what is designed immutable |
| C4 | Memory-poor chronics vs every-session ledger | ✅ | §10/§17: explicit `memory_class: stateless` schema flag; stateless patients "carry no signed case-history envelope at all" |
| C5 | "Never deleted" vs cure retirement | ✅ | §18: explicit lifecycle states; "nothing is deleted means every case is accounted for" |
| C6 | "Minimal" server vs accumulated duties | ✅ | §2: "Small but Authoritative Control Plane" with enumerated authoritative responsibilities and demand for real cost modelling |
| C7 | Client-computed "verified" receipts | ✅ | §7: server "independently re-derives the outcome … or, at minimum, validates against plausibility bounds"; "a client-computed number is a claim, not a fact" (residual architecture decision → NC-4) |
| C8 | LLM text carrying gameplay-critical clues | ✅ | §8 "Clue Ownership": core-selected clue tokens injected as mandatory content + post-generation validation + templated fallback |
| C9 | "Jailbreak-immune" claim | ✅ | §9: "defended in depth, not mathematically impossible"; schema whitelisting, sanitization at signing, template isolation |
| C10 | P2W leaks (consultations, points, decks) | ✅ | §19: consultations in-game-currency-only + rate-limited; subspecialty purchases hard-capped as % of attainable; decks validated as sidegrades in sandbox; enforced SKU test |
| C11 | Two matchmaking functions | ✅ | §6: "Canonical Matchmaking (single owner)" — the three-factor mean demoted to UI readout |
| C12 | Lifetime-ratio reputation vs decay/floors | ✅ | §6: "Event-Sourced Reputation … recency-weighted score" |
| C13 | P2P chat vs server moderation | ✅ | Chat removed entirely (§2 "No Free-Form Player Messaging") |

### Assumptions A1–A9 — 7 resolved/gated, 2 partial

| ID | Was | Status | Evidence |
|---|---|---|---|
| A1 | 3B model can act | ✅ gated | §2: acting-quality gate under "worst-case prompts … not just happy-path cases" |
| A2 | Mobile devices can run it | ✅ gated | §2: device-viability gate vs "written minimum device spec", 1–1.5B fallback tested jointly; §11 footprint hedged as "target, not settled fact" |
| A3 | Users accept 1.8 GB download | ✅ gated | §2: download-acceptance gate with "chosen delivery/retry strategy" |
| A4 | Free tier as capacity plan | ◐ | §7: free tier correctly demoted to dev environment; cost model at 1k/10k/100k/1M MAU *demanded but not yet produced* → G-4 |
| A5 | P2P works on mobile | ✅ | Removed — CDN/object store delivery (§2, §3.3) |
| A6 | Solvability validation buildable | ◐ | §3.2 now budgets "real compute … per manifest" — but creates a new spec tension (NC-5) |
| A7 | Monthly retraining operable | ✅ | §18: "no monthly fine-tune-and-ship-1.8 GB pipeline in the plan" |
| A8 | Distributed single-ownership | ✅ | §10: "a locking problem … arbitrated by the server; the client proposes, the server decides" |
| A9 | Client keys "just work" | ✅ | §7: "Treat this as a small managed PKI" with provisioning, revocation, reinstall recovery |

### Design/economy D1–D7 — 5 resolved, 2 partial

| ID | Was | Status | Evidence |
|---|---|---|---|
| D1 | Trauma-multiplier collusion | ✅ | §17 "Anti-Collusion Guards": caps, no multiplier on friend referrals, chain decay, A→B→A detection |
| D2 | Design rewards making patients worse | ◐ | §17: deliberate infliction "penalized rather than rewarded" — but no mechanism distinguishes malice from incompetence; detection is delegated to anomaly detection. Tracked, acceptable at this stage |
| D3 | Multi-currency economy unmodelled | ◐ | §5: modelling mandated as "first-class design deliverable" in the sandbox — artifact still to be produced → G-4 |
| D4 | Employer pyramid dynamics | ✅ | §24: "diminishing returns … under a hard firm-wide cap"; skim tuned so employment "stays a genuine choice" |
| D5 | P2W leaks (dup of C10) | ✅ | See C10 |
| D6 | False precision | ✅ | §5: all constants declared "illustrative placeholders owned by that single balance spec" |
| D7 | Adaptive oracle is a second product | ✅ | §9 "Where It Runs (Scope Honesty)": server-side/offline, post-launch, never shipped to client |

### Legal L1–L6 — 4 resolved, 1 partial, 1 open

| ID | Was | Status | Evidence |
|---|---|---|---|
| L1 | DSM/APA IP breach | ✅ | See C1 |
| L2 | App-review sensitivity / age rating | ❌ carried | No rating strategy, no Manipulative-card tone guidelines in current text → G-2 |
| L3 | GDPR vs distributed ledger | ✅ | §17: pseudonymous therapist IDs ("never a real username or other PII") + revocation list keeps "data-erasure obligations enforceable" |
| L4 | UGC self-certified | ✅ | §21: creator test interview is *additive*; publication routes through server validation & signing "(§3.2)" incl. toxicity screening |
| L5 | Peer-healer duty-of-care blur | ◐ | Chat removal deletes the open-distress channel; §23 support is structured/typed only. Residual: "peer-healer"/"share support" framing still reads as emotional support between real humans — wording-level fix |
| L6 | Chat moderation vs P2P delivery | ✅ | Chat removed |

**Tally: 29 ✅ / 5 ◐ / 1 ❌ of 35.** All five ◐ items and the one ❌ item are re-tracked
in §5–§6 below so nothing silently drops.

---

## 5. New findings register — conflicts in the current text

Fresh scan of the revised document. Severity: **Blocker** (stops roadmapping) /
**Major** (must be resolved by the phase that touches it, or by a text edit now) /
**Minor** (hygiene). **There are no Blockers.**

### NC-1 — Referral payload contradicts the storage rules · Major

- **Clash:** §18: players "package a patient's custom case manifest **(including dialogue
  history)** and transfer it" — vs §7: the server "strictly forbids the storage of rich
  text logs, conversational transcripts", §11: patient file is "a microscopic text file
  under 50 KB", and §17: the signed envelope records only "the cards played, medications
  prescribed, the psychological outcome, and a schema version" — deliberately *not*
  transcripts.
- **Why it matters:** raw dialogue history grows unbounded across a multi-session siege
  (§14); if it rides in the manifest it breaks the 50 KB budget, and if it transits the
  server-mediated referral flow it violates the no-transcript rule. As written, three
  sections cannot all be true.
- **Resolution:** one sentence in §18: referrals carry the structured §17 history
  envelope only; raw transcripts never leave the originating device. (Optionally allow a
  size-capped, core-generated summary digest.)

### NC-2 — The Misfortune Roll targets the players §5 protects · Major

- **Clash:** §12 deliberately routes "an elite, volatile, or highly mistreated patient
  manifest to a **new user's** clinic" with a forced-play path that "severely cripples
  the player's clinic reputation" — vs §5: "Avoid harsh punishment for early failure;
  use mistakes to teach and redirect instead of drive players away."
- **Aggravator:** the designed escape valve rewards transferring the case "to a qualified
  **friend**" — the one asset a first-week player does not have.
- **Resolution:** gate the chaos roll on account tenure/level (e.g., disabled during the
  §5 "first week" path), and/or route the referral valve to a system NPC specialist for
  players with no network. Keeps the mechanic, removes the new-player trap.

### NC-3 — Foreclosure confiscates real-money purchases · Major (legal/consumer)

- **Clash:** §24: on structural collapse "the employer is instantly evicted, **loses all
  historical office cosmetic upgrades**" — vs §19: cosmetics ("visual office overhauls,
  clinic themes, UI skins") are one of the few things bought with **real money**.
- **Why it matters:** destroying paid entitlements via gameplay punishment invites
  refund claims, chargebacks, and store-policy/consumer-protection findings in several
  jurisdictions. It also violates §19's own tone ("investing in their practice").
- **Resolution:** on foreclosure, purchased cosmetics return to inventory; only earned/
  placed non-paid upgrades are lost.

### NC-4 — Server re-derivation implies a second rules implementation · Major (architecture)

- **Clash:** §7: "the server independently re-derives the outcome from the deterministic
  rules" — vs §16: "The **client app** handles deterministic outcome resolution using
  localized game logic" and §15: Manipulative outcomes are "evaluated dynamically by the
  **client/Dart engine**."
- **Why it matters:** re-derivation requires the ruleset to exist server-side too. That
  means either dual implementations (guaranteed drift) or a single portable rules module
  (e.g., a shared Dart package run server-side) — plus **seeded RNG committed in the
  receipt** (stochastic elements exist: §10 transfer roll, §15 gamble outcomes) and
  **ruleset version pinning** per receipt. None of this is specified, and it constrains
  the server technology choice — which is exactly a roadmap-phase-1 decision.
- **Resolution:** decide "shared rules module + seeded, version-pinned receipts" (or
  consciously accept plausibility-bounds-only validation) in the roadmap's first
  server phase, *before* the sim core is written.

### NC-5 — Solvability harness cost vs "the model never decides" · Minor (spec clarity)

- **Clash:** §3.2: proving winnability "requires simulating play against the actual
  **model-plus-ruleset** … real compute budgeted per manifest" — vs §8: "The local LLM
  does not decide gameplay outcomes" and clue emission is core-owned with a templated
  fallback.
- **Why it matters:** if outcomes and clues are core-owned, mechanical solvability needs
  only ruleset bots (cheap, no inference); the model affects tone alone. Either §3.2
  overstates per-manifest compute (skewing the cost model) or there is an unadmitted
  dialogue→outcome dependency (weakening §8's guarantee).
- **Resolution:** split validation: (a) per-manifest mechanical solvability via ruleset
  bots; (b) *sampled* acting-quality QA with the model in the loop.

### NC-6 — PoC perf gate measured on an emulator · Major (methodology, one-line fix)

- **Clash:** §2 requires "tokens/sec and peak RAM … measured against a written minimum
  device spec", but the stated test targets are "Android **emulator** and Linux desktop."
- **Why it matters:** emulator throughput and memory behavior (x86-on-desktop, no
  thermal throttling, different memory pressure) are not evidence about the minimum
  device spec. As written, the gate cannot produce valid pass/fail data for the
  project's most important bet (A2).
- **Resolution:** amend §2: perf gates must be measured on at least one physical
  minimum-spec Android device; the emulator validates build/packaging only.

### NC-7 — "Core Revenue Streams" contains non-revenue items · Minor (hygiene)

- **Clash:** §19 lists under *Core Revenue Streams*: "Study Point Purchases … purchasable
  **only using in-game currency, not real money**" and Emergency Consultations
  "purchasable with in-game currency only (never real money)".
- **Why it matters:** these produce zero revenue by definition; the section conflates
  revenue SKUs with currency sinks, leaving the actual expected revenue mix (which SKUs
  carry the business) unstated — an input the §7 cost model needs.
- **Resolution:** split §19 into "revenue streams" vs "in-game currency sinks."

### NC-8 — Offline-tolerant play vs server-accepted-only results · Major (gap)

- **Clash:** §2: "Play is local-first at the session level … offline-tolerant loop" — vs
  §7: "Only server-accepted results update the authoritative profile", §10 server-
  arbitrated ownership, §17 cure retirement.
- **Why it matters:** nothing defines receipt queueing while offline, idempotency/replay
  protection, ownership lease semantics during offline windows, or the race between an
  offline cure and a server-side transfer/doubt event. This is a real protocol design,
  not a footnote.
- **Resolution:** specify offline receipt semantics (queue + idempotency keys + ownership
  lease TTL) as an explicit deliverable of the roadmap's first online phase.

---

## 6. Gaps register (missing, not contradictory)

| ID | Gap | Where it lands |
|---|---|---|
| G-1 | **No prompt token budget.** Nine axes + case history + medication state + style archetype + mandatory clue tokens must fit a small-model context on-device; a naïvely injected 50 KB manifest is ~12k tokens. The budget must be a *measured PoC artifact* | PoC (Phase 0) exit artifact |
| G-2 | **No age-rating / content-rating strategy** (carried from L2). The manipulate-a-patient-into-derangement loop will be read harshly by store reviewers and press; plan for 16+/17+, write Manipulative-card tone guidelines | Pre-store-submission; draft during Phase 1 |
| G-3 | **Desktop distribution + auth unnamed.** Five platforms claimed; §7 auth is Apple/Google; Linux/Windows channel (Steam? direct?) and their OAuth flows unstated | First online phase |
| G-4 | **Commissioned artifacts don't exist yet:** MAU cost model (§7) and multi-currency balance spec (§5). Both are demanded by the blueprint itself | Cost model = entry gate to first online phase; balance spec before any tuning ships |
| G-5 | **No team/capacity/timeline statement.** ~20 major systems; the roadmap must map phases to actual capacity or explicitly defer systems | Roadmapping input |
| G-6 | **UGC human-moderation staffing/SLA unquantified** (§3.4, §21) — review cost scales with creator count | UGC phase entry gate |
| G-7 | **Base model license unpinned.** "Open-source base model (e.g., 3B)" — redistribution terms differ materially (Llama community license vs Apache-2.0 vs Gemma terms vs MIT); the choice constrains commercial embedding | Must be settled at PoC model selection |
| G-8 | **The "written minimum device spec" doesn't exist yet**, and §2's gates are defined against it | Day-one PoC input — write it first |

---

## 7. Conditions attached to the GO

1. **Amend the §2 PoC gate (NC-6):** physical minimum-spec device required for perf
   measurements. *One-line edit; do before the PoC phase is written into the roadmap.*
2. **One editing pass over `STARTER.md`** resolving the bounded text conflicts:
   NC-1 (referral payload = §17 envelope only), NC-2 (tenure-gate the chaos roll /
   NPC referral target), NC-3 (paid cosmetics survive foreclosure), NC-7 (split revenue
   vs sinks), plus the L5 wording softening ("peer-healer" → mechanical co-op framing).
3. **Write the two missing day-one inputs:** minimum device spec (G-8) and base-model
   license shortlist (G-7). Both are prerequisites of the PoC itself.
4. **Roadmap structure requirement:** commit firmly only to Phase 0 (PoC, per §2 as
   amended) and Phase 1 (offline vertical slice: sim core, card taxonomy, clue-injection,
   5–10 authored cases, no network). All later phases are written but explicitly
   *contingent on Phase-0 gates green* — which mirrors the blueprint's own sequencing rule.
5. **Encode the architecture decisions as named phase deliverables:** NC-4 (portable
   rules module + seeded, version-pinned receipts) and NC-8 (offline receipt protocol)
   in the first online phase; G-4 artifacts as that phase's entry gates; G-1 token budget
   as a Phase-0 exit artifact.

### Recommended phase skeleton (input for `ROADMAP.md`)

| Phase | Scope | Exit gate |
|---|---|---|
| **0 — PoC** | §2 verbatim, amended per NC-6; device spec + model license settled first | Three §2 gates measured on physical device; token budget written (G-1); A1/A2/A3 verdicts recorded |
| **1 — Offline vertical slice** | Deterministic sim core (portable module, NC-4 decision made), 4-card taxonomy, clue injection, 5–10 authored cases, single clinic loop, no network | Stranger plays 30 min and wants more; sim core fully test-covered; rating strategy drafted (G-2) |
| **2 — Server-authoritative online** | Auth + save + receipts (seeded/pinned, NC-4; offline protocol, NC-8), matchmaking, referrals, moderation basics | Cost model at 10k MAU holds (G-4); receipt validation demonstrated against a cheating client |
| **3 — Content pipeline + UGC** | §3 generation/validation/signing, authoring portal, §21 director flow behind the §3.2 gate | Solvability harness split per NC-5; moderation SLA staffed (G-6) |
| **4 — Endgame economy** | Trauma economy, corporate systems, macro events, oracle | Economy simulated in §7 sandbox before live tuning (balance spec, G-4) |

---

## 8. Bottom line

The 2026-07-04 audit said this was "a beautiful document that fights itself." The
revision fixed that: every one of the thirteen contradictions is resolved in citable
text, the P2P and chat foundations that generated most of them are gone, and the three
technology bets the whole project stands on are now explicit, falsifiable, and
sequenced *before* any dependent spend. The eight findings that remain are the normal
residue of a large design — bounded edits and phase-level decisions, none foundational,
none blocking.

**Therefore: the project is ready to move to technical roadmapping — a conditional GO.**
Do the single editing pass (conditions 1–3), then replace the placeholder phases in
[`docs/planning/ROADMAP.md`](../planning/ROADMAP.md) with the five-phase skeleton above,
binding commitment only through Phase 1 until the PoC gates report green. The next
document this project needs is not more design — it is the roadmap.
