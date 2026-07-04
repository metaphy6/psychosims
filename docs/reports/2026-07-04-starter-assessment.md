# 🔍 Psychosims — Honest Assessment of `STARTER.md`

- **Date:** 2026-07-04
- **Source:** [`STARTER.md`](../../STARTER.md) (project blueprint, §1–§24)
- **Reviewer:** AI agent (design + architecture review, requested by project owner)
- **Type:** One-time audit snapshot. Not auto-generated; do not hand-edit after commit.

---

## 1. Executive summary

**Verdict: strong creative vision with several genuinely correct architectural
instincts, sitting on top of a blueprint that contradicts itself in at least
a dozen material places and treats multiple unproven feasibility assumptions
as settled facts.**

The single best decision in the document is §2's *"Minimal Cross-Platform
Runtime First"* milestone — a real, falsifiable proof-of-concept with explicit
success criteria. The single most dangerous decision is treating the P2P
network as a **foundational identity and data layer** rather than a bandwidth
optimization. Most of the critical conflicts below trace back to that choice.

Scope-wise, this document describes a multi-year, live-ops-scale product
(local LLM inference, P2P content network, chat, UGC marketplace, guild/corporate
economy, dual simulation sandboxes, adaptive auto-balancing, moderation
infrastructure) while planning to run its backend on a database free tier.
The vision is coherent; the plan is not yet honest about cost, sequence, or
which systems depend on which.

**Headline numbers:**

| Category | Count |
|---|---|
| Direct internal contradictions (C1–C13) | 13 |
| High-risk unvalidated assumptions (A1–A9) | 9 |
| Design/economy exploits & risks (D1–D7) | 7 |
| Legal / policy / ethics exposures (L1–L6) | 6 |

---

## 2. What is genuinely strong

Honest assessment cuts both ways. These parts are *right*, and several are
unusually mature for a blueprint at this stage:

1. **Simulation core vs. dialogue layer split (§8, §16).** Deterministic
   rules engine decides outcomes; the LLM only voices them. This is the
   correct — arguably the *only* correct — architecture for an LLM-driven
   game. It solves fairness, reproducibility, and most jailbreak concerns
   structurally instead of with prompt duct tape.
2. **"Universal Actor" + tiny JSON manifests (§11).** One shared base model
   with ~50 KB patient files swapped into context is the right storage and
   memory model. Zero-bloat patient switching is a real, achievable win.
3. **Card-based input instead of free text (§9).** Right call for gameplay
   stability, content safety, moderation surface, and UI scalability.
4. **Phase-0 PoC with explicit success criteria (§2).** "Flutter UI → case
   definition → prompt assembly → local inference → rendered dialogue, on
   Android emulator + Linux desktop" is exactly the correct first milestone.
5. **Fictional pharmacology + disclaimers + PII separation (§4).** Shows
   genuine awareness of App Store and legal exposure (though §10 then
   undermines it — see C1).
6. **Anti-bankruptcy recovery loops (§13).** Designing explicit failure-state
   exits (discount practice, sabbatical) before launch is rare and good.
   Early designs usually only model success paths.
7. **Anti-pay-to-win stance stated as principle (§19).** The principles are
   right even where specific items leak against them (see D5).
8. **Four-card taxonomy with contextual signatures (§15).** "Context over
   deck" — cards are situationally correct rather than statically ranked —
   is a solid core mechanic with real strategic depth.
9. **Dual test infrastructure (§7).** Separating a fast rule/balance sandbox
   from a high-fidelity network simulation environment is sophisticated
   thinking, and the bot-driven simulation framework will be *required* to
   balance the economy (see D3).
10. **The Misfortune Roll + ethical-referral reward (§12).** Rewarding a
    player for recognizing a case beyond their competence and referring it
    out is elegant design that reinforces theme through mechanics.

---

## 3. Direct internal contradictions (conflict register)

These are places where the document disagrees *with itself*. Each needs one
canonical decision before implementation reaches the affected system.

### C1 — Fictional disorders vs. DSM-5 diagnoses ⚠️ resolve first

- **Where:** §4 vs. §10, §14.
- **Conflict:** §4 (App Store & Legal Safety) mandates *"Use fictional
  disorders and fictional pharmacology, not real clinical diagnoses"*. §10's
  Nine-Track Synthesis Pipeline then specifies *"Clinical Axis (DSM-5 Core):
  The foundational diagnosis (e.g., Major Depressive Disorder, Generalized
  Anxiety)"*, and §14 has players *"comparing text histories against …
  DSM manuals"* and a "diagnostic encyclopedia".
- **Why it matters:** This is the project's own legal firewall being breached
  by its own content pipeline. DSM-5 is APA-copyrighted material; real
  diagnoses also re-open the "is this medical advice?" App Store review risk
  §4 exists to close. Every patient manifest, study field, and encyclopedia
  entry built on the wrong side of this decision is rework.
- **Resolution:** Decide now, once: a fully fictional clinical taxonomy
  (parallel to the fictional pharmacology), with real-world frameworks used
  as *design inspiration only* (consistent with §5's "Free Source
  Inspiration" guidance, which already says exactly this). Purge "DSM" from
  the design vocabulary.

### C2 — Account data migrating into P2P vs. cloud DB as permanent anchor ⚠️ resolve first

- **Where:** §2 ("Progressive Distribution") vs. §7.
- **Conflict:** §2: user account information *"should be removed from the
  central database entirely once a safe threshold is reached"*. §7: the
  cloud database is the anti-tamper anchor that keeps progression
  *"permanently safe"* across devices and is the source of the
  *"cloud-verified data packet"* peers trust.
- **Why it matters:** These are mutually exclusive. If accounts leave the
  server, there is no verified profile to sign (§7), no authority to ban or
  adjust reputation (§3.5), no royalty accounting (§21), and no anti-cheat
  story at all. The doc's own math (0.5 KB/profile) proves central identity
  is nearly free — the migration buys nothing and costs everything.
- **Resolution:** Delete the progressive-distribution goal. Identity,
  economy balances, and reputation stay server-authoritative permanently.
  P2P remains the *content and presence* layer.

### C3 — Immutable append-only ledger vs. moderation revocation & privacy

- **Where:** §17 vs. §3.5 (and GDPR — see L3).
- **Conflict:** §17 specifies an *"Append-Only Ledger"* of *"cryptographic,
  signed transaction block[s]"* logging *"the previous doctor's public
  username"*, replicated peer-to-peer. §3.5 requires the operator to
  *"remove, quarantine, or replace"* content and *"freeze or invalidate
  suspicious content propagation"*.
- **Why it matters:** You cannot revoke what you have designed to be
  immutable and replicated. And an unerasable distributed record of real
  users' identifiers is a privacy liability by construction.
- **Resolution:** Replace immutability with *server-signed, revocable
  content envelopes*: history entries carry pseudonymous therapist IDs,
  a version, and a server signature; clients honor a revocation list.
  "Tamper-evident" is achievable; "immutable" is a bug, not a feature, here.

### C4 — Memory-poor chronic patients vs. every-session ledger memory

- **Where:** §10 ("Social Chronic Patients … do not retain meaningful user
  data, therapist identity, or long-term personal history") vs. §17
  ("*Every* session conclusion appends … the previous doctor's public
  username …"; patients actively reference past doctors).
- **Why it matters:** The content pipeline, manifest schema, and prompt
  assembly all need to know which rule applies to which patient class.
- **Resolution:** Make ledger participation an explicit manifest flag:
  individual patients carry history; social chronic patients are stateless
  by schema, not by convention.

### C5 — "No patient model is ever deleted" vs. cure retirement

- **Where:** §18 vs. §17 ("Cure Retirement Rule … removed from the live
  network and archived").
- **Why it matters:** Minor wording conflict, but it decides real storage
  and lifecycle semantics (who archives, where, who pays for it).
- **Resolution:** Define lifecycle states once: `active → owned → (cured |
  abandoned | hospitalized) → archived`, with "archived" explicitly outside
  the live swarm. Retire the "never deleted" slogan.

### C6 — Minimal control plane vs. accumulated server responsibilities

- **Where:** §2 ("small, inexpensive … minimum necessary responsibilities")
  vs. §3 (content factory, validation pipeline, catalog, routing
  intelligence), §12 (matchmaking matrix), §17/§18 (bug-log ingestion,
  *monthly model retraining*), §21 (royalty accounting), §22 (macro event
  seeding, audits, tax simulation), plus chat discovery/moderation (§2).
- **Why it matters:** The document repeatedly assigns the server another
  authoritative duty while maintaining the fiction that it is a minimal
  signaling layer. The result will be an under-provisioned, under-designed
  backend that actually runs the entire game economy. This is the most
  pervasive structural dishonesty in the blueprint.
- **Resolution:** Rename the concept: **small but authoritative**. Enumerate
  the real server services (identity, save-state, matchmaking, ownership
  arbitration, economy ledger, content validation/signing, moderation,
  events, royalties) and cost them. "Minimal" should describe what it
  *doesn't* store (transcripts, assets), not pretend it isn't the authority.

### C7 — Client-side outcome calculation vs. anti-cheat goals

- **Where:** §7 ("the Flutter app calculates the resulting metrics
  local-side and pushes a verified execution receipt") vs. §7's own purpose
  ("prevent file tampering"), §3.5 (anti-cheat enforcement).
- **Conflict:** A client-computed receipt is not "verified" — the client is
  the attacker in every cheating scenario. XP, reputation, currency, and
  trauma multipliers all derive from these receipts and drive matchmaking,
  royalties, and leaderboards.
- **Resolution:** Accept one of two honest positions: (a) server-side
  plausibility validation of session receipts (bounded gains per session
  tier, statistical anomaly detection) — cheap and probably sufficient for
  a co-op-flavored game; or (b) full server replay of deterministic session
  logs — expensive but airtight. Say which, and design receipts accordingly.

### C8 — LLM "voices, never decides" vs. gameplay-critical clues in dialogue

- **Where:** §8/§16 vs. §14 (players *"analyze collected linguistic clues,
  comparing text histories"* to pick the counter-card) and §12 (evaluating
  symptoms from the interview).
- **Conflict:** If clue discovery drives correct card selection, then LLM
  text *is* gameplay-authoritative. A 3B model that hallucinates, omits, or
  buries a clue breaks case solvability — exactly what §8 promises can't
  happen.
- **Resolution:** The simulation core must *own* clue emission: it selects
  which clue tokens are due this turn and injects them as mandatory content
  into the prompt; post-generation validation confirms the clue text
  survived (regenerate if not). Dialogue stays flavor; clues become state.

### C9 — "Jailbreak immunity" vs. untrusted text entering prompts

- **Where:** §9 ("mathematically impossible for users to trick or break the
  AI's character") vs. §17 (ledger text from *other players* parsed into
  prompts), §21 (user-authored manifests feeding the local model).
- **Conflict:** Card-only input closes the *direct* injection channel, but
  the design then opens two indirect ones: peer-authored case history and
  UGC manifests are attacker-controlled strings concatenated into prompts.
  "Mathematically impossible" is false confidence.
- **Resolution:** Treat manifests and ledger entries as untrusted input:
  strict schema whitelisting (enums/numbers over free text wherever
  possible), server-side sanitization at signing time, length caps on any
  free-text field, and template-level isolation of untrusted strings.

### C10 — Non-pay-to-win principles vs. specific monetized items

- **Where:** §19 principles ("Premium content should never replace …
  essential treatment outcomes") vs. §19 items: *Emergency Consultations*
  (buy a rescue mid-session to prevent a walkout — that *is* a treatment
  outcome), purchasable *Subspecialty Points* (progression currency), and
  *Specialty Expansion Decks* ("expand tactical options" — power, not
  cosmetics).
- **Resolution:** Run every SKU through the doc's own test. Emergency
  Consultations should cost in-game currency only or be cut; subspecialty
  purchases need a hard cap expressed as % of total attainable; expansion
  decks must be sidegrades (validated in the §7 balance sandbox), not
  upgrades.

### C11 — Attraction formula vs. routing intelligence

- **Where:** §6 (Clinic Attraction % = equal-weight mean of exactly three
  factors) vs. §3.3 (routing considers reputation, study-field coverage,
  pricing, *and current operational pressure*) and §23 (pressure/capacity
  states gate throughput).
- **Why it matters:** Two different matchmaking functions are specified.
  Whichever ships, the other is dead spec that will mislead contributors.
- **Resolution:** One canonical matchmaking spec, owned by the balance
  document, with the §6 formulas explicitly labeled *placeholder examples*.

### C12 — Reputation as lifetime ratio vs. decay/restore mechanics

- **Where:** §6 (Reputation % = successful/total, lifetime) vs. §7 sandbox
  ("reputation decay" as a tunable), §13 (reputation floor restored from
  credentials), §12/§17 (event-driven reputation shocks).
- **Conflict:** A lifetime ratio can't decay, can't be floored, and barely
  moves for veteran accounts (case 10,001 changes nothing). The mechanics
  described everywhere else require a windowed or event-sourced reputation.
- **Resolution:** Event-sourced reputation with recency weighting; the §6
  formula is a UI display at best.

### C13 — P2P chat delivery vs. server abuse detection

- **Where:** §2 chatrooms ("actual message exchange should favor P2P … may
  be logged lightly for abuse detection").
- **Conflict:** The server cannot log messages it never relays. Either
  clients dual-send (defeating the load-saving purpose; trivially spoofed
  by abusers) or moderation is report-only.
- **Resolution:** Be honest about the trade: server-relayed chat for public
  rooms (moderatable), P2P for private/ephemeral with client-side reporting
  + sender-signed message provenance. Don't promise both halves of a
  contradiction.

---

## 4. High-risk unvalidated assumptions

Things the blueprint treats as settled that are actually experiments. Each
should have a validation gate before systems are built on top of it.

- **A1 — A 3B local model can carry the acting load.** Nine psychological
  axes, ledger-aware grudges, medication effects, style archetypes,
  clue fidelity (C8), across thousands of sessions without incoherence —
  on a quantized 3B model. *This is the project's core bet and it is
  unproven.* Phase-0 must test worst-case prompts, not happy paths.
- **A2 — Mobile devices can run it.** ~1.8 GB weights + KV cache + Flutter
  + OS overhead. Older iPhones enforce per-app memory limits that make a
  3B model borderline-to-impossible below ~6 GB device RAM; Android
  mid-range will see single-digit tokens/sec and thermal throttling.
  Define a minimum device spec and benchmark on it in Phase 0. Expect
  pressure toward a 1–1.5B model, which makes A1 harder.
- **A3 — Users will accept the model download.** 1.8 GB first-run download
  (store cellular caps, churn during download, re-download on retrain —
  see A7).
- **A4 — Supabase free tier supports production.** §7's "1,000,000 active
  players in 500 MB" counts only profile rows. It ignores free-tier MAU
  caps on auth, egress limits, connection limits, project pausing — and
  all the *other* server data this design requires (matchmaking state,
  moderation logs, royalty accounting, audit events, bug logs, chat
  metadata). Free tier is a dev environment, not a capacity plan. Build a
  cost model at 1k / 10k / 100k MAU.
- **A5 — P2P works on mobile at useful availability.** Mobile peers churn
  (background kill, battery, NAT). Real WebRTC deployments relay a large
  minority of traffic through TURN servers — which is server bandwidth you
  pay for. The swarm also can't guarantee a manifest is fetchable when
  matchmaking assigns it, so the server ends up as seed-of-last-resort.
  P2P here is a *cost optimization to measure*, not an architecture to
  assume.
- **A6 — Automated "solvability" validation is buildable (§3.2).** Proving
  a generated case is winnable requires simulating play against the actual
  model+ruleset. That's a bot harness (the §7 sandbox) run per-manifest —
  real compute, real engineering, not a checkbox.
- **A7 — Monthly model retraining is operable (§18).** A recurring
  fine-tune → evaluate → re-quantize → redistribute-1.8 GB-to-every-device
  pipeline is a serious MLOps program, and it contradicts §11's "static
  footprint that never grows" framing. Recommend cutting it from the plan
  until there's a team to own it.
- **A8 — Distributed single-ownership works (§10).** "One therapist at a
  time" across a P2P swarm is a distributed-locking problem (the
  double-assignment analog of double-spend). Only the server can arbitrate
  this — another entry for C6's honest server inventory.
- **A9 — Client key management just works (§7, §21).** Signing keys need
  provisioning, server certification, revocation, and recovery on
  reinstall/device-switch. That's a small PKI. Unaddressed.

---

## 5. Design & economy risks

- **D1 — Trauma-multiplier collusion is a built-in exploit (§17 + §18).**
  Rewards scale with Trauma Severity Index; trauma is *created by players
  mistreating patients*; and patients are directly transferable to friends.
  The farming loop writes itself: A abuses the case, refers it to B, B
  cures it at multiplied payout, split proceeds. Mitigations needed at
  design time: multiplier caps, no multiplier on friend-referred cases,
  diminishing returns per transfer chain, provenance checks, server-side
  anomaly detection.
- **D2 — The design rewards making patients worse.** Even outside
  collusion, "elite players hunt for broken models" (§17) means the
  highest-value content is *harm done by other players*. Mechanically
  interesting; ethically and optically loaded (see L2) and it incentivizes
  the griefing it monetizes.
- **D3 — Seven interlocking currencies, zero economic modeling.** Currency,
  XP, study points, subspecialty points, reputation, prestige, royalties —
  plus employer skims (+25%/employee), 2× study multipliers, 50% XP
  penalties, trauma multipliers. Nothing in the doc analyzes sources vs.
  sinks. Inflation or dead-currency outcomes are near-certain without the
  §7 sandbox being used to simulate the economy *before* tuning ships.
- **D4 — Employer stacking multipliers create pyramid dynamics (§24).**
  Stacking +25% revenue per employee makes hiring strictly dominant and
  concentrates wealth at directors; combined with employee XP/revenue
  skims, the optimal junior strategy is permanent employment, collapsing
  the solo-clinic fantasy the rest of the doc sells.
- **D5 — P2W leaks** — covered as C10; listed here because it's also a
  balance problem, not just a consistency one.
- **D6 — False precision throughout.** Exact formulas (§6), percentages,
  and constants ("Base Competency Constant", 2–4% transfer chance, 5%
  chaos roll) appear next to "the manifest will be defined later" (§16).
  Precision theater invites contributors to implement placeholder math as
  gospel. Label every number as tunable placeholder; centralize them in
  one balance spec.
- **D7 — The "Adaptive Master Algorithm" (§9) is a second product.** A
  continuously-recomputed optimal-play oracle over all patient states is a
  research-grade solver plus telemetry pipeline. It's a good idea — but
  it's an *endgame balancing tool*, and the doc should say where it runs
  (server needs telemetry it claims not to collect; client leaks it to
  dataminers).

---

## 6. Legal, policy & ethics exposure

- **L1 — DSM-5/APA IP + own-rule violation.** See C1. Highest-priority
  fix; it's both a legal exposure and a self-contradiction.
- **L2 — App review sensitivity is understated.** Fictional disclaimers
  help, but the loop is still "roleplay a therapist, optionally *manipulate*
  traumatized patients into 'derangement' for rewards." Apple reviewers and
  journalists will read it that way. Needs a deliberate content-rating
  strategy, tone guidelines for Manipulative-card copy, and probably a
  16+/17+ rating assumption in planning.
- **L3 — GDPR/erasure vs. distributed ledger.** Public usernames in
  replicated, "immutable" P2P records = personal data you cannot delete on
  request. C3's pseudonymous, revocable envelopes are the fix; also keep a
  server-side mapping so erasure requests can be honored by revocation.
- **L4 — UGC safety gate is self-certified (§21).** The Medical Director
  "Validation Test Interview" proves *winnability*, not *appropriateness* —
  the author validates their own psychology-trauma content, then it's
  signed and published to the global swarm. Community-authored trauma
  narratives are about the highest-risk UGC category there is. All UGC must
  pass the §3.2 server validation + toxicity gate before signing, with
  sampled human review and a report/takedown flow (which C3 makes possible).
- **L5 — "Peer-Healer" blurs the fiction boundary.** §4's legal firewall
  says "not real therapy." §23's healer-to-healer economy has *real humans
  emotionally supporting real humans* for in-game rewards, and chatrooms
  will accumulate users discussing real distress. That is a real
  mental-health-adjacent service with real duty-of-care questions.
  Recommend reframing peer-recovery as purely mechanical co-op (resource
  exchange, not "support sessions"), plus crisis-resource signposting in
  chat as standard practice.
- **L6 — Chat moderation duty vs. P2P delivery.** See C13. Whatever ships
  must be defensible to app stores' UGC rules (report, block, filter —
  which require some server visibility or robust client-side reporting).

---

## 7. Scope reality check

Counting §1–§24: local inference runtime, prompt assembly, deterministic
sim core, card system, manifest pipeline + validation, matchmaking router,
P2P swarm + signaling, chat, BaaS identity/save, moderation control plane,
UGC authoring portal *and* in-client director tools, royalty economy,
clinic ops sim (rent/tax/audits), macro events, recovery systems, corporate
employment system, monetization storefront, two sandbox environments, an
adaptive balancing oracle, and a bespoke art pipeline. That is **~20 major
systems**. Several sections each independently claim their feature is
"core" — when everything is core, nothing is prioritized.

For calibration: the *content* of §2's PoC (one screen, one hardcoded case,
one model, one platform pair) is perhaps 2–4 weeks of work. Everything else
in the document is measured in team-years. The blueprint never states team
size, budget, or timeline — the most important missing numbers in the file.

**Dependency inversion to fix:** the doc makes P2P foundational (identity
distribution, delivery, referrals, ledger). Nearly every conflict above
(C2, C3, C6, C7, A5, A8, L3) gets simpler or disappears if P2P is demoted
to *content-delivery optimization behind a server-authoritative game*.

---

## 8. Recommended phase gating

Aligns with [`docs/planning/ROADMAP.md`](../planning/ROADMAP.md)'s
phase/gate structure; suggested replacement for its placeholder phases:

| Phase | Scope | Exit gate |
|---|---|---|
| **0 — PoC (as §2, keep verbatim)** | Flutter + llama.cpp FFI + one case JSON + prompt assembly + rendered dialogue; Linux + Android emulator | Coherent session on both targets; tokens/sec + RAM measured on a defined minimum device; **A1/A2 verdict written down** |
| **1 — Offline vertical slice** | Deterministic sim core, 4-card taxonomy, 5–10 authored cases, clue-injection design (C8 fix), single clinic loop; *no network* | A stranger can play 30 min and want more; sim core has full test coverage |
| **2 — Server-authoritative online** | Auth + save (Supabase paid-tier cost model), server-mediated matchmaking, referrals, chat (server-relayed), moderation basics | C2/C6/C7 resolutions implemented; cost model at 10k MAU holds |
| **3 — P2P as optimization** | Manifest delivery via swarm with server fallback; measure real TURN/relay ratios | P2P demonstrably reduces cost vs. Phase-2 baseline (A5 verdict) |
| **4 — UGC + endgame economy** | Director tools behind §3.2 server gate (L4), royalties, corporate systems, trauma economy with D1 mitigations | Economy simulated in the §7 sandbox before live tuning |

**Resolve before any further design work:** C1 (clinical taxonomy),
C2 (data authority), C6 (honest server inventory). Everything else can be
resolved at the phase that touches it.

---

## 9. Bottom line

This is one of the more inventive game concepts I've reviewed, and its two
deepest architectural instincts — deterministic core with LLM-as-actor, and
one universal model with tiny swappable manifests — are exactly right. But
the blueprint currently promises mutually exclusive things: a minimal
server that is also the authority for everything; an immutable ledger that
is also moderatable; fictional disorders that are also DSM-5; a
tamper-proof economy computed by the untrusted client; free-tier
infrastructure for a million players. None of these are fatal, because none
of them are built yet. Fix the thirteen contradictions on paper — starting
with C1, C2, and C6 — demote P2P from foundation to optimization, run the
§2 PoC honestly against A1/A2, and this becomes a credible (if ambitious)
multi-year plan instead of a beautiful document that fights itself.
