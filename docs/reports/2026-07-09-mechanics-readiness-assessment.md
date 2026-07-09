# 🎲 Psychosims — Game-Mechanics Readiness Assessment (Part II, §7–§24)

- **Date:** 2026-07-09
- **Source under review:** [`STARTER.md`](../../STARTER.md), **Part II — Game Mechanics &
  Design (§7–§24)**, working tree as of 2026-07-09 (last commit `eaea034`
  `docs: starter v4.1.4`, plus the staged Part I/Part II split pending commit).
  Part I (§1–§6) is read as the dependency contract Part II must honour.
- **Prior audits:** [`2026-07-04-starter-assessment.md`](2026-07-04-starter-assessment.md)
  (C/A/D/L series) and
  [`2026-07-07-starter-readiness-assessment.md`](2026-07-07-starter-readiness-assessment.md)
  (NC/G series, blueprint-level CONDITIONAL GO).
- **Question answered:** *Are the game mechanics — specifically — ready to move to the
  next stage, technical roadmapping?*
- **Type:** One-time audit snapshot. Do not hand-edit after commit.
- **How to verify:** every finding quotes verbatim text; grep the quoted string in
  `STARTER.md` and read the cited sections side by side. No finding rests on opinion.

---

## 1. Executive verdict

> **VERDICT: CONDITIONAL GO — split into two lanes.**
>
> **Lane A (client-core mechanics): READY NOW.** The session loop — card taxonomy (§16),
> loadout (§11), multi-session siege (§15), sim-core/dialogue split (§4/§6), progression
> display (§9/§10) — is internally consistent, exploit-aware, and fully decomposable into
> roadmap phases today. Nothing found in this audit touches it structurally.
>
> **Lane B (server-facing mechanics): NOT READY AS-IS.** The case lifecycle, ownership
> economy, trauma economy, and creator royalties contain **one blocker-class internal
> contradiction (GM-1)** and **four high/medium findings (GM-2…GM-5)** sitting exactly on
> the client/server authority boundary that technical roadmapping would formalize first.
> Roadmapping these systems before the patches would encode a state machine that
> contradicts its own required transitions.
>
> **The gap is closable in one bounded editing pass** — six paragraph-level patches to
> `STARTER.md` (GM-1…GM-5 plus carried-open NC-2). **No finding requires new design
> exploration or reopens a settled decision.** After that pass, the mechanics are ready
> without reservation.

The proof structure, as in the prior audits:

1. The readiness bar is defined before scoring (§2, criteria M-R1…M-R10).
2. Prior findings that touch Part II are re-verified against the current text (§4):
   of the mechanics-relevant NC/G items, **all but one (NC-2) are resolved in citable
   text**; one (L5 wording) is partially resolved.
3. A fresh mechanics-focused scan (§5) yields **11 findings (GM-1…GM-11)**: 1 blocker,
   2 high, 2 medium, 6 low/editorial.
4. The verdict follows mechanically from the scorecard: no criterion fails for Lane A;
   Lane B fails M-R2 until GM-1 lands.

---

## 2. Readiness scorecard

Criteria fixed before scoring. "Mechanics ready for technical roadmapping" means: an
engineer could derive the client sim-core spec, the server state machine, and the economy
service boundaries from Part II without inventing missing intent or arbitrating
contradictions on load-bearing rules.

| # | Criterion | Score | Evidence |
|---|---|---|---|
| M-R1 | Core session loop (card → sim resolution → dialogue) specified end-to-end and consistent | ✅ PASS | §11 (loadout, controllers), §16 (four types, signature principle, contextual bias), §15 (siege loop), backed by §4/§6 (core owns outcomes and clues). No contradictions found in the loop itself |
| M-R2 | Case lifecycle state machine admits every transition the mechanics require | ❌ FAIL | GM-1: §18's lifecycle omits `owned → active` (walkout/transfer/re-pool) and `hospitalized → owned`, both of which §12, §13, §16, §17 and §18's own prose require |
| M-R3 | Every cross-player / economy quantity has a named authoritative owner | ⚠️ PARTIAL | GM-2 (Doubt, operational pressure, Trauma Severity Index accrual unassigned), GM-3 (client "mutates" a server-signed manifest). The receipt machinery (§3) makes all of them server-derivable — the assignments are just not written |
| M-R4 | Economy loops carry exploit analysis at parity | ⚠️ PARTIAL | §17 anti-collusion is exemplary; §21 royalties have **no** equivalent (GM-4); §13↔§17 referral incentives fight each other (GM-5); NC-2 (chaos-roll new-player trap) still open |
| M-R5 | All constants externalized to one balance spec + sandbox | ✅ PASS | §9: "all specific constants, percentages, and formulas in this document … are illustrative placeholders owned by that single balance spec and tuned in the sandbox"; consistently repeated at §12, §13, §24 |
| M-R6 | Monetized items classified per §19's own two-bucket rule | ◐ PARTIAL | GM-9: Premium Practice Modes and Legacy Unlocks sit in neither bucket |
| M-R7 | Roles/progression mapped to shipping sequence | ◐ PARTIAL | §7 declares five roles "a core part of the experience rather than a later expansion," while §21/§24 gate two of them behind endgame. Not a contradiction — but the roadmap must state which roles exist at which milestone (GM-10f) |
| M-R8 | Terminology and cross-reference integrity | ◐ PARTIAL | GM-6 ("Empathy cards" — a type that doesn't exist), GM-7 (§15 dangling antecedent), GM-8 (endorsement signals promised, never defined), GM-11 (§2.x citations vs 3.x headings) |
| M-R9 | Prior mechanics-touching audit debt cleared | ◐ PARTIAL | §4 below: NC-1/3/4/5/6/7/8 and G-1/2/6 resolved or scheduled in citable text; **NC-2 open**, L5 wording partial |
| M-R10 | No mechanic requires new design exploration | ✅ PASS | Every GM fix below is a paragraph or less; none reopens a design decision |

**Score: 3 PASS / 6 PARTIAL / 1 FAIL → conditional go, lane-split as stated in §1.**

---

## 3. What is genuinely strong (and why Lane A passes)

Honest assessment cuts both ways. Part II is unusually mature for a mechanics spec, and
visibly hardened by two prior audit cycles:

1. **The card system is a real game.** The four-type taxonomy (§16) with the Signature
   Card Principle — context-over-deck, situational correctness, "advertising through
   mechanics" — plus the loadout constraint (§11) and the two-session research loop
   (§15) form a coherent tactical core with genuine depth. This is the part of the
   design most likely to survive contact with players unchanged.
2. **Manipulative cards are designed as a system, not an edge case.** Three-outcome
   resolution keyed to trust state, explicit risk framing, reputation tradeoff, and a
   scheduled age-rating/tone strategy (§8) — the most dangerous mechanic in the game is
   also its most carefully specified.
3. **Dual-canonicalization notes prevent self-fighting math.** §10 explicitly demotes
   its own display formulas ("illustrative display math, not the authoritative
   matchmaking function") and re-bases reputation as event-sourced — killing the
   ratio-vs-decay contradiction class permanently.
4. **`memory_class` discipline holds everywhere.** Stateless chronic patients carry no
   history envelope (§12, §17), which keeps the trauma multiplier, the ledger rules, and
   the training-pool role mutually consistent. Checked in every section that touches
   patient memory; no violation found.
5. **Anti-collusion guards on the trauma multiplier (§17)** — caps, referral-multiplier
   reduction, chain decay, provenance checks, anomaly detection — remain the best
   paragraph in the document (though see GM-5 for an unpriced side effect).
6. **Monetization is structurally honest.** The real-money/currency-sink split, the
   enforced SKU test, hard-capped subspecialty purchases, sidegrade-validated decks,
   and deferred cosmetics (§19) survive re-review; the NC-3 foreclosure fix is present
   in §24.
7. **Recovery paths exist for every failure spiral.** §14 (financial), §23 (pressure),
   §18 (broken cases) — failure states have designed exits, which most blueprints omit.
8. **Placeholder discipline is airtight.** Every number in Part II is marked as owned
   by the §9 balance spec. There is no "implement the example math" trap left.

---

## 4. Prior-finding verification (mechanics-relevant subset)

Re-verified against the current text. Statuses: ✅ resolved · ◐ partial · ❌ open.

| ID | Was | Status | Evidence in current text |
|---|---|---|---|
| NC-1 | Referral payload carried dialogue history | ✅ | §18: "The referral payload carries only the structured §17 history envelope … Raw dialogue transcripts never leave the originating device" |
| NC-2 | Chaos roll targets new players; escape valve requires a friend | ❌ **open** | §13 still reads "routes an elite, volatile, or highly mistreated patient manifest to a **new user's** clinic" and the valve still targets "a qualified **friend**". No tenure gate, no NPC referral target was added. Carried into the §7 conditions |
| NC-3 | Foreclosure confiscated paid cosmetics | ✅ | §24: "purchased cosmetics return to inventory on foreclosure rather than being destroyed" |
| NC-4 | Server re-derivation implied second rules build | ✅ decided | §3: plausibility bounds + anomaly detection + `ruleset_version` pinning; "the server does not hold a copy of the rules and does not re-derive outcomes" |
| NC-5 | Solvability harness conflated model with ruleset | ✅ | §2.2: mechanical solvability (bots, every manifest) split from sampled acting-quality QA |
| NC-7 | Revenue streams mixed with currency sinks | ✅ (residual) | §19 now has separate "Core Revenue Streams (Real-Money SKUs)" and "In-Game Currency Sinks (No Real Money)" — residual classification gap tracked as GM-9 |
| NC-8 | Offline receipts undefined | ✅ | §3 "Offline Receipt Protocol (Phase 2 Deliverable)": queue, idempotency keys, ownership lease TTL, cure/transfer race |
| G-1 | No prompt token budget | ✅ scheduled | §1 PoC exit artifact + §6 tiered prompt structure with assembler contract |
| G-2 | No age-rating strategy | ✅ scheduled | §8: "Age-Rating & Content Strategy (scheduled, not yet written)" with a named milestone (first content phase → before store submission) |
| G-6 | UGC moderation staffing unquantified | ✅ scheduled | §2.4: "Moderation Staffing & SLA (UGC-phase entry gate)" |
| L5 | Peer-healer framing reads as real emotional support | ◐ | §23 flows are structured/typed only (consistent with the no-messaging rule), but wording like "share support" and "peer-healer sessions" between real players remains; still a wording-level softening task |

**Takeaway:** the post-audit editing pass genuinely happened — with one miss (NC-2) that
this report re-raises as a hard condition, since it is a Part II mechanics defect.

---

## 5. New findings register — GM-1…GM-11

Severity: **Blocker** (would be encoded wrongly into the roadmap if unfixed) ·
**High** (must be fixed before the affected system is roadmapped) · **Medium** (fix in
the same editing pass) · **Low/Editorial**.

### GM-1 — The lifecycle state machine forbids transitions the mechanics require · **Blocker**

- **The canonical line (§18):** "they move through an explicit lifecycle:
  `active → owned → (cured | abandoned | hospitalized) → archived`."
- **What the mechanics actually require:**
  1. **`owned → active` (re-pool on transfer):** §12: the patient "may decide to leave
     the current clinic and be **reassigned to a different available therapist**."
  2. **`owned → active` (re-pool on walkout):** §13: forcing a session causes the
     patient to "walk out"; §16: mistreatment escalates agitation to walkout.
  3. **`owned → active` (trauma economy supply):** §17: severity grows when a patient is
     mistreated "by **previous players**" (plural), and elite players "hunt for broken
     cases" — both impossible unless mistreated cases repeatedly re-enter the pool.
     Note §17 also says a misstep makes a mythic patient "walk out **permanently**" —
     the same event that must re-pool the case elsewhere in the design.
  4. **`hospitalized → owned` (asylum is temporary):** §18's own prose: the asylum holds
     the patient "**until** the player finishes the academic studies needed to treat
     them again" — yet the lifecycle line routes `hospitalized → archived`, terminal.
  5. **`owned → owned′` (referral):** §13/§18 referrals hand ownership to another player.
- **Why it is the blocker:** §12 makes ownership "a locking problem … arbitrated by the
  server." The very first server-side artifact technical roadmapping produces is this
  state machine. As written, the canonical diagram contradicts five transitions required
  by four sections — an engineer implementing §18 verbatim builds a system in which the
  trauma economy (§17), the transfer valve (§12), and asylum recovery (§18) cannot occur.
- **Resolution (bounded):** redraw the lifecycle once, e.g.
  `pool(active) ⇄ owned` (assign/accept vs walkout/transfer/abandon-to-pool),
  `owned → owned′` (referral), `owned ⇄ hospitalized` (freeze/unfreeze, same owner),
  `owned → cured → archived`, plus an explicit rule for which abandonment variants
  archive vs re-pool. One diagram + three sentences; then §12/§13/§16/§17 all conform.

### GM-2 — Three cross-session hidden quantities have no computation owner · **High**

- **The quantities:**
  1. **Doubt (§12):** "a hidden Doubt value that rises gradually over time and can
     increase when the therapist uses Manipulative cards repeatedly or when session
     prices rise sharply" → "If Doubt crosses a threshold and a stochastic roll
     succeeds," the patient transfers. *Who accrues Doubt, and who rolls?*
  2. **Operational pressure (§23):** "Every active session … increases operational
     pressure" — and §2.3 routing "should consider … current operational pressure."
     *A matchmaking input must be server-visible; nothing says how it gets there.*
  3. **Trauma Severity Index (§17):** "grows inside the ledger" — the ledger is
     server-signed, but the accrual function (which receipt fields increment it, by how
     much) is nowhere assigned.
- **Why it matters:** all three drive server-authoritative outcomes (patient loss,
  routing, multiplied payouts). Part I's own axiom — "A client-computed number is a
  claim, not a fact" (§3) — means a client-side default here would hand players control
  over patient retention (suppress Doubt), routing (understate pressure), and bounty
  size (inflate severity). The machinery to do it right **already exists**: receipts
  carry ordered card/medication actions and pricing history is server-known, so all
  three are derivable server-side from accepted receipts. The design just never says so.
- **Resolution (bounded):** one clause per section: "Doubt is derived server-side from
  accepted receipt history and pricing changes; the transfer roll executes server-side"
  (§12); "operational pressure is computed server-side from receipt cadence and case
  tier" (§23); "Trauma Severity Index accrual is a server-side function over signed
  history entries" (§17).

### GM-3 — Client-side manifest "mutation" contradicts the signed-manifest integrity model · **High**

- **Clash:** §16 (Manipulative failure): "The **Dart engine may mutate the patient's
  manifest** into a chaotic, secondary pathology state" — vs §5: the manifest "grows
  incrementally as **structured session deltas**"; §17: entries are "tamper-evident —
  any edit breaks the server signature"; §2.2: the server validates and signs all
  published content.
- **Why it matters:** a client cannot mutate a server-signed artifact without breaking
  every downstream consumer (referral receivers, the trauma index, moderation). Worse,
  derangement **feeds the Trauma Severity Index**, which multiplies payouts (§17) — so
  an unclarified client-claimed derangement is an economy input on the anti-cheat
  boundary (circular with GM-2.3).
- **Resolution (bounded):** one sentence in §16: derangement is recorded as a structured
  session delta in the receipt; the client renders the deranged state provisionally;
  authoritative case state updates (and the manifest is re-signed) only on server
  acceptance. This is exactly the client-proposes/server-decides pattern §1 already
  mandates — the text just needs to invoke it.

### GM-4 — Creator royalties lack the anti-farming analysis the trauma multiplier got · **Medium**

- **The text (§21):** "Every time another active player **downloads**, pays a treatment
  fee, or successfully treats that custom manifest, the server's royalty accounting
  credits the original creator with continuous passive royalties in clinic currency and
  prestige points."
- **The gap:** royalties trigger on raw **downloads** — a free, unlimited CDN fetch —
  and mint currency with no cap, no per-player-per-case dedupe, and no provenance rule.
  Sybil accounts fetching a manifest in a loop is a straightforward currency printer.
  §17 devotes a full paragraph to closing the *analogous* trauma-farming loop
  (caps, provenance, A→B→A detection, anomaly flags); §21 has none of it. The rigor is
  inconsistent across the two creator-incentive economies.
- **Resolution (bounded):** mirror §17 in one paragraph: royalties accrue only on
  server-validated **fee-payment and cure events** (never raw downloads), at most once
  per player-case pair, under per-creator rate caps, with the same anomaly detection.

### GM-5 — §17's referral-multiplier nerf undermines §13's referral safety valve · **Medium (design tension)**

- **Clash:** §13 canonizes referral as the *ethically correct* play for an overwhelming
  case ("The Referral Reward (The Safety Valve) … rewards them with +1 Universal
  Experience Point for demonstrating professional ethical awareness") — while §17's
  anti-collusion guard imposes "**no (or steeply reduced) multiplier on cases received
  via friend/direct referral**."
- **Effect:** the qualified friend receiving a chaos-roll mythic case inherits **full
  risk** (a misstep = walkout = "severely cripples … reputation") with the bounty
  **removed**. Rational receivers decline; the safety valve the new-player experience
  depends on (§13, and open finding NC-2) quietly stops working. The two sections are
  individually correct and jointly self-defeating.
- **Resolution (bounded):** the provenance machinery §17 already requires can
  distinguish *when* trauma accrued. Carve out: multiplier is retained for severity
  accrued **before** the referring player's ownership window; only severity attributable
  to the referrer is excluded. Collusion stays unprofitable (A's abuse still pays B
  nothing); good-faith referrals of genuinely broken cases stay worth accepting.

### GM-6 — "Empathy cards" is not a card type · **Low (gameplay-critical wording)**

- **§16 (Transference Spike):** "conventional **Empathy cards** are read
  programmatically as Manipulative Failures."
- The taxonomy defines exactly four types: Disclosing, Relatable, Postponing,
  Manipulative. A rule that *inverts card classification* — the most mechanically
  consequential sentence in the section — names a type that does not exist (stale
  vocabulary from an earlier draft). Presumably "Relatable"; say so.

### GM-7 — §15 references a feedback system that is never described · **Low (editorial)**

- "Once a player reaches a sufficiently advanced progression tier, the game unlocks its
  analytical advanced simulator. **These notifications** are replaced by an advanced
  Clinical Assessment Matrix." — "These notifications" has no antecedent anywhere in
  Part II; the basic-tier feedback system being replaced was evidently edited out of an
  earlier draft. Also: the stray bullet-as-heading "* The Professional-Tier Shift
  (Advanced Grading Rubric)". Describe the basic-tier feedback in one sentence, or cut
  the comparative framing.

### GM-8 — "Endorsement signals" are promised by Part I and defined nowhere · **Low (gap)**

- §1 justifies the no-messaging rule by listing the structured interactions that replace
  chat, including "**reputation/endorsement signals (§10)**" — but §10 defines
  reputation display only; no endorsement mechanic (who endorses whom, with what effect)
  exists anywhere in Part II. Either define it in §10 in two sentences or delete the
  word from §1's list. As written, a promised social feature has no spec.

### GM-9 — Two monetized items escape §19's own classification rule · **Low (residual of NC-7)**

- "Premium Practice Modes: … unlocked through **premium progression or currency-based
  purchase**" and "Legacy Unlocks: Let players **purchase** permanent content unlocks" —
  both sit under "Retention-Oriented Monetization," in *neither* the Real-Money SKU list
  nor the currency-sink list, with payment rails unstated. §19's SKU Test requires every
  item to be classifiable; classify them.

### GM-10 — Editorial bundle · **Low**

- **(a)** §11: "a hard restriction limit of **5 or 6** Active Card Slots" — an
  either/or in a spec; pick one or mark it explicitly as a balance-spec placeholder.
- **(b)** §22: audits read "over-medication histories … logged in **the database
  files**" — there is no such store; per §3's split, medication history lives in signed
  case-history envelopes / receipts, not a client "database file." Name the real source.
- **(c)** §17: "all earned experience points, **leaderboard rankings**, and in-game
  currency payouts are multiplied" — a *ranking* cannot be multiplied; presumably
  leaderboard *score/points*.
- **(d)** §13: "+1 **Universal Experience Point**" — term used once; everywhere else
  it's "Experience Points."
- **(e)** §14: the ASCII recovery-matrix table is visibly mangled (broken borders/column
  alignment) — cosmetic, but this is the section engineers will screenshot.
- **(f)** §7 declares role diversity "a core part of the experience rather than a later
  expansion," while §21 (Medical Director) and §24 (Corporate) are endgame-gated. Not a
  contradiction — sequencing honesty elsewhere is good — but the roadmap must state
  explicitly which roles exist at which milestone so §7's promise has a schedule.
- **(g)** §16 derangement can end in "institutional referral" (in-fiction hospital)
  while §18 frames Commit-to-Mental-Hospital as a *bug-recovery* tool for model
  glitches. Dual-purpose is fine, but one sentence should say both triggers converge on
  the same frozen `hospitalized` state, else analytics will conflate gameplay outcomes
  with defect reports.

### GM-11 — Part II citations point at section numbers that don't exist · **Low (reference integrity)**

- Part II (and Part I's §1) cite "§2.2," "§2.3," "§2.5" — but the subsections of
  "## 2. Server-Side Patient Generation & Distribution Frame" are headed **3.1–3.5**
  ("### 3.1 Content Generation Pipeline" … "### 3.5 Governance & Moderation Backdoor"),
  a leftover from a pre-split numbering scheme that also collides with "## 3. State
  Management." The recent renumbering commit fixed the top level but not these anchors.
  Renumber 3.1–3.5 → 2.1–2.5 so every cross-reference in the document resolves.

---

## 6. Balance-sandbox watchlist (not findings — scenarios the §3 sandbox must test)

Recorded so they aren't lost; none blocks roadmapping because all constants are owned by
the balance spec (M-R5 PASS):

1. **Chaos roll × trauma multiplier × new account:** a first-week player curing a
   chaos-routed mythic case takes a multiplied windfall (or reputation wipeout) —
   variance bounds for week-one accounts need explicit testing (interacts with NC-2).
2. **§15's intended research loop vs §16's Postponing decay:** the recommended optimal
   play (Session 1 Relatable/Postponing → exit → study → Session 2 counter) is exactly
   the pattern the multi-session Postponing decay punishes. Intended tension, but tune
   so the *designed* loop is not net-negative.
3. **Sabbatical floor abuse (§14B):** verify the credential-derived reputation floor can
   never exceed organically earned reputation, or closing/reopening becomes a rep pump.
4. **Discount practice (§14A):** the 50% penalty hits XP only; confirm high-volume
   discounted play doesn't become a currency faucet (currency is only throttled by the
   low price itself).
5. **Associate capability ceiling (§24) vs chaos roll (§13):** define whether chaos
   cases can route to employed associates and how the +5 ceiling interacts.

---

## 7. Conditions attached to the GO

**Condition 1 — one editing pass on `STARTER.md` Part II (blocks Lane B roadmapping):**

| Patch | Finding | Size |
|---|---|---|
| Redraw §18 lifecycle (re-pool, referral, asylum-return transitions) | GM-1 | diagram + 3 sentences |
| Assign server-side computation of Doubt, pressure, severity | GM-2 | 3 clauses |
| Derangement = receipt delta, server-applied | GM-3 | 1 sentence |
| Royalty triggers = validated fee/cure events + caps + dedupe | GM-4 | 1 paragraph |
| Provenance carve-out for pre-referral trauma | GM-5 | 2 sentences |
| Tenure-gate the chaos roll / NPC referral target | NC-2 (carried) | 2 sentences |

**Condition 2 — hygiene pass (parallel, does not block):** GM-6…GM-11 — terminology,
antecedents, SKU classification, subsection renumbering.

**Condition 3 — roadmap obligations (land in the roadmap, not in `STARTER.md`):**
role-to-milestone mapping (GM-10f); the §6 watchlist as named sandbox scenarios in the
economy phase's entry gate; the server ownership state machine implemented from the
*post-GM-1* lifecycle.

**What can start immediately (Lane A, no waiting):** Phase 0/PoC and the offline
vertical slice — sim core (§4/§6), four-card taxonomy (§16), clue injection, loadout
(§11), prompt assembler (§6) — per the phase skeleton already recommended in the
2026-07-07 report. None of GM-1…GM-5 touches these systems.

---

## 8. Bottom line — the provable statement

**The game mechanics of Part II are creatively complete, internally consistent in their
client-facing core, and disciplined about ownership, placeholders, and exploits — with
five substantive exceptions, all of which sit on the server-authority boundary, and all
of which are paragraph-level text fixes rather than design work.**

Formally:

- **Lane A (client-core mechanics): READY.** Provable by the absence of any GM finding
  against §4/§6/§11/§15/§16's loop mechanics (scorecard M-R1, M-R5, M-R10 PASS).
- **Lane B (server-facing mechanics): READY AFTER the Condition-1 editing pass.**
  Provable by GM-1…GM-5 + NC-2: each cites text that, implemented verbatim today, would
  produce a server state machine that contradicts its own required transitions (GM-1),
  three cheat-controllable economy inputs (GM-2/GM-3), one currency-printing loop
  (GM-4), and one self-defeating incentive pair (GM-5).
- **Nothing found reopens design.** Every fix is specified above and none exceeds a
  paragraph — this is an editing sprint, not another design iteration.

**Recommendation:** execute Condition 1 as a single tracked commit, then declare Part II
mechanics-complete and proceed to technical roadmapping on both lanes. Do not begin the
server ownership/economy phase specifications from the current text.
