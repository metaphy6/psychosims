# 💸 Psychosims — Honest Assessment: Switching Back to P2P for Least Server Cost

- **Date:** 2026-07-11
- **Question answered:** *Given that applying the Part II mechanics fixes
  (GM-1…GM-5) will add server work, would switching back to a peer-to-peer
  (P2P) architecture reduce server-side cost?*
- **Source under review:** [`STARTER.md`](../../STARTER.md) (current server-client
  design), the planned patches in
  [`2026-07-09-mechanics-readiness-assessment.md`](2026-07-09-mechanics-readiness-assessment.md)
  (Condition 1: GM-1…GM-5), and the P2P design that was **removed** on
  2026-07-04 (commit `docs(starter): replace P2P architecture with server-client model`).
- **Prior audits:** [`2026-07-04-starter-assessment.md`](2026-07-04-starter-assessment.md)
  (C/A/D/L series — the audit that recommended removing P2P) and
  [`2026-07-07-starter-readiness-assessment.md`](2026-07-07-starter-readiness-assessment.md)
  (confirmed the removal closed the contradictions).
- **Type:** One-time decision-support snapshot. Do not hand-edit after commit.
- **How to verify:** every claim quotes verbatim text from `STARTER.md` or a
  prior report; grep the quoted string and read the cited section side by side.

---

## 1. Executive verdict

> **VERDICT: NO. Switching back to P2P would not reduce your real server cost,
> and it directly contradicts the fixes you are about to apply.**
>
> The costs you are worried about come almost entirely from the **trust plane**
> — the economy ledger, patient-ownership arbitration, moderation, and creator
> royalties. Those are exactly the systems that (a) P2P *cannot run* without a
> distributed-consensus implementation that costs far more to build than a small
> managed backend, and (b) the GM-1…GM-5 patches make *more* server-authoritative,
> not less. P2P does not delete this cost; it moves bandwidth around (usually
> **upward**, via TURN relays and seed-of-last-resort), while re-opening every
> contradiction the 2026-07-04 → 2026-07-07 work closed.
>
> **The current design is already the least-server-cost architecture that keeps
> the game honest.** It is local-first: the server is not in the session hot path,
> stores no transcripts, runs no AI inference, and holds profiles at ~0.5 KB each.
> The marginal server cost *per session* is already near zero. If cost is the
> concern, the levers are **deferral and scale-to-zero**, not decentralization.

---

## 2. The central finding — the question contains a contradiction

You want to do two things at once that pull in opposite directions:

1. **Apply GM-1…GM-5** (Condition 1 of the 2026-07-09 assessment).
2. **Reduce server dependence** by going P2P.

But read what GM-1…GM-5 actually require — every one of them **adds server
authority**:

| Patch | What it moves onto the server | Source |
|---|---|---|
| **GM-1** | The patient-ownership **lifecycle state machine** (`pool ⇄ owned`, referral, asylum-return). "The very first server-side artifact technical roadmapping produces is this state machine." | 2026-07-09 §GM-1 |
| **GM-2** | "Doubt is derived **server-side** from accepted receipt history"; "operational pressure is computed **server-side**"; "Trauma Severity Index accrual is a **server-side** function." | 2026-07-09 §GM-2 |
| **GM-3** | Derangement applied server-side: "authoritative case state updates (and the manifest is **re-signed**) only on server acceptance." | 2026-07-09 §GM-3 |
| **GM-4** | "Royalties accrue only on **server-validated** fee-payment and cure events … under per-creator rate caps, with … anomaly detection." | 2026-07-09 §GM-4 |
| **GM-5** | **Server-side** provenance carve-out on the trauma multiplier. | 2026-07-09 §GM-5 |

The 2026-07-09 assessment's own words: these fixes exist because three cross-session
quantities were "cheat-controllable" as client values and had "**no computation
owner**." The fix is to give them a **server** owner. You cannot simultaneously
"apply GM-2" and "let the client own these numbers again" (which is what P2P
requires). **The fixes and P2P are mutually exclusive by construction.**

Your instinct that the fixes add server work is **correct**. The conclusion that
P2P is the escape hatch is **backwards** — the fixes add work *precisely to the
layer P2P deletes*.

---

## 3. P2P is not a new idea here — it was tried and deliberately removed

This is a *revert* request, not a novel proposal. The project began with a P2P
foundation: a peer-replicated content network, P2P presence, P2P chat, an
"immutable append-only ledger" replicated peer-to-peer, and "progressive
distribution" that removed account data from the central DB.

The 2026-07-04 audit's headline finding:

> "The single most dangerous decision is treating the P2P network as a
> **foundational identity and data layer** rather than a bandwidth optimization.
> Most of the critical conflicts below trace back to that choice."
> — [`2026-07-04-starter-assessment.md`](2026-07-04-starter-assessment.md) §1

It was removed across four commits, and the 2026-07-07 audit confirmed the result:

> "the four revision commits **removed the P2P foundation** … the document no
> longer fights itself on any load-bearing wall."
> — [`2026-07-07-starter-readiness-assessment.md`](2026-07-07-starter-readiness-assessment.md) §1

Reverting re-opens, at minimum, these already-closed findings (all P2P-rooted):

| Prior finding | What P2P re-breaks |
|---|---|
| **C2** | "If accounts leave the server, there is no verified profile to sign, no authority to ban or adjust reputation, no royalty accounting, and **no anti-cheat story at all**." |
| **C3 / L3** | An immutable, replicated ledger carrying usernames is personal data you **cannot delete on GDPR request** — "you cannot revoke what you have designed to be immutable and replicated." |
| **C13** | "The server cannot log messages it never relays" — P2P defeats moderation. (Moot today: chat is already deleted.) |
| **A5** | Mobile peers churn; "real WebRTC deployments relay a large minority of traffic through **TURN servers — which is server bandwidth you pay for**," and the swarm "can't guarantee a manifest is fetchable when matchmaking assigns it, so the server ends up as **seed-of-last-resort**." |
| **A8** | "'One therapist at a time' across a P2P swarm is a distributed-locking problem (the double-assignment analog of double-spend). **Only the server can arbitrate this.**" |
| **A9** | Client signing keys still need a PKI (provisioning, certification, revocation, recovery) — *harder*, not easier, without a central authority. |

---

## 4. Where the server cost actually is (and where it isn't)

An honest cost model has to name the lines. The current design is already
aggressively minimized on the expensive ones.

### 4a. Already near-free by design — P2P saves nothing here

- **Profile storage:** "on the order of 1,000,000 profiles within a 500 MB
  table" at ~0.5 KB each (§3). Identity is nearly free centrally; the prior
  audit noted "the migration buys nothing and costs everything."
- **Transcripts:** none stored. "Dialogue transcripts are never written into the
  manifest" (§5); they are ephemeral and on-device.
- **AI inference:** 100% on-device via llama.cpp (§1). **Zero** server GPU/compute
  for the actual gameplay — the single most expensive thing an LLM product
  usually pays for, already off the server bill.
- **Session hot path:** entirely local. The server is touched at handshake,
  presence, and receipt submission — **not during play** (§3, §6). Marginal
  server cost per session ≈ 0.

### 4b. The real cost lines — and P2P makes each one worse or impossible

| Cost line | Current (server-client) | Under P2P |
|---|---|---|
| **Auth (per-MAU pricing)** | Linear in users; tiny early. Unavoidable in any design that has accounts. | **Same or worse** — you still need server-authoritative identity (C2), plus a PKI (A9). |
| **CDN egress** | Dominated by the **one-time ~1.8 GB model download** per install (§1), not by gameplay. Manifests are compact, cacheable JSON. | **Worse** — TURN relay traffic + seed-of-last-resort means you pay CDN/relay *anyway* (A5), on top of P2P infra. |
| **Receipt validation / matchmaking / ownership** | Cheap: plausibility bounds + anomaly detection, **not** rules re-execution — "the server does not hold a copy of the rules and does not re-derive outcomes" (§3). | **Impossible or far costlier** — ownership is double-spend (A8); you'd have to *build consensus/locking*, which dwarfs a BaaS. |
| **Moderation staffing (human)** | The **largest variable cost**, gated behind UGC (§2.4). Controllable by *deferring UGC*. | **Worse** — "cannot log messages it never relay" (C13); UGC revocation impossible on an immutable swarm (C3). |
| **Royalty accounting** | Server-validated fee/cure events (GM-4). | **Impossible** — no trusted accounting across untrusted peers. |
| **PKI for signing** | A small managed PKI (§3). | **Same, harder** — key recovery/revocation across peers with no anchor (A9). |

**Net:** P2P removes none of the trust-plane cost, adds TURN + seed-of-last-resort
bandwidth, and adds large one-time engineering cost (consensus/locking, the
"high-fidelity network sandbox" of §3 becomes dramatically harder to build and
test). It is a **false economy**.

---

## 5. What actually reduces server cost (the constructive path)

Your underlying goal — keep server cost low — is legitimate and *already the
design's stated intent*: "'Minimal' describes its storage footprint and
per-session compute" (§1). The correct levers keep the trust plane intact:

1. **Defer UGC / the Medical Director engine (§21).** This is the single biggest
   variable cost (moderation staffing, §2.4) and is *already sequenced as
   endgame*. Not shipping it early removes the largest cost line entirely, with
   zero integrity loss.
2. **Lean into the already-designed offline receipt protocol (§3, Phase 2).**
   The server is already out of the session hot path. Prefer **batch/async
   reconciliation** over chatty real-time calls.
3. **Defer real-time WebSocket presence at launch.** The design is
   "offline-tolerant" (§1); early on, lazy/poll-based presence and directory
   refresh cost far less than always-on sockets, at the price of freshness you
   don't yet need.
4. **Serverless / scale-to-zero for validation + matchmaking.** Receipt checks
   are per-request and stateless-ish; pay per invocation, not for idle capacity.
5. **Optimize the dominant egress line directly.** The ~1.8 GB model download is
   the real bandwidth cost — cheap object storage + resumable/CDN delivery, and
   the "download acceptance" gate (§1) already flags it. Gameplay manifests are
   already tiny and cacheable.
6. **Single-region launch.** Defer multi-region replication until MAU justifies it.
7. **Hold the line on §3's design choice** — never drift into re-executing the
   ruleset server-side. Plausibility bounds + anomaly detection is what keeps
   validation cheap; GM-2…GM-4 add *derivations over receipts*, not a second
   rules engine, and should stay that way.

This is the point worth internalizing: **the current architecture already *is*
the "minimal server" answer.** It is local-first with the server shrunk to a thin
trust/coordination plane. "Least server cost while keeping the game honest" is not
P2P — it is *this design, with the expensive optional systems deferred.*

---

## 6. The one legitimate P2P-shaped question (and its cheaper answer)

There is a narrow, defensible version of your instinct: **manifest/content
delivery** *could* in principle be offloaded to peers to cut CDN egress. But:

- Content is already compact, cacheable JSON on a CDN — the cheapest possible
  delivery tier (§3.3). The prior audit: "a CDN comfortably absorbs delivery at
  every scale in the §3 cost model, so no more exotic distribution scheme is
  needed."
- Mobile peer availability (A5) means you keep the CDN as seed-of-last-resort
  anyway, so you pay twice.

If CDN egress ever becomes a real line item at scale, the cheaper move is a
**pull-through cache / cheaper CDN tier**, not a peer swarm. Content delivery is
the *only* layer where P2P is even coherent, and it is already the cheapest layer
you have.

---

## 7. Bottom line & recommendation

1. **Do not revert to P2P.** It saves nothing on the trust plane (where the cost
   is), likely raises bandwidth cost, adds major engineering cost, and re-opens
   C2/C3/C13/A5/A8/A9/L3.
2. **Apply GM-1…GM-5 as written.** They are correct and they belong on the server.
   Their cost is *derivation over receipts you already collect*, not a new
   subsystem — small, bounded server compute.
3. **Control cost by deferral, not decentralization** — defer UGC (biggest lever),
   defer real-time presence, use serverless scale-to-zero, and optimize the 1.8 GB
   download. Model the result at the §3 MAU tiers (1k/10k/100k/1M) before the
   first online phase, per the existing cost-model entry gate.
4. **Record the decision so it stops being re-litigated.** The P2P removal lives
   only in these reports and a commit message —
   [`docs/project/DECISION_LOG.template.md`](../project/DECISION_LOG.template.md)
   and [`docs/design/ADR.template.md`](../design/ADR.template.md) are still
   templates. Capture "server-client over P2P, with rationale and cost model" as
   a real ADR / decision-log entry so this question is answered once, in writing.

**Provable statement:** For a product whose value rests on a currency economy,
single-owner patient arbitration (a double-spend problem), moderation of a
psychology theme, and creator royalties, the load-bearing systems *require* a
trusted authority. P2P cannot provide one cheaply; the GM fixes deepen the need
for one. Therefore P2P is strictly worse on cost **and** correctness for this
design, and the current local-first server-client model is already the
minimal-server answer.
