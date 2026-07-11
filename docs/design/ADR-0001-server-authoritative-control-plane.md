# 📐 ADR-0001: Server-authoritative control plane (not P2P)

- **Status**: accepted
- **Date**: 2026-07-04 (reaffirmed 2026-07-11)
- **Deciders**: @maintainer
- **Supersedes**: none
- **Superseded by**: none

## Context

An earlier design draft used a peer-to-peer foundation. The 2026-07-04 audit
found P2P could not enforce the guarantees the product depends on: stable
identity, moderation and content revocation, single-owner patient arbitration,
an anti-cheat economy, and creator royalties. A 2026-07-11 cost assessment
([`../reports/2026-07-11-p2p-server-cost-assessment.md`](../reports/2026-07-11-p2p-server-cost-assessment.md))
re-examined reverting to P2P to save server cost and concluded **no**.

## Decision

Use a **server-client** architecture with a small but authoritative server
control plane; the client is local-first at the session level but holds no
authority. The client proposes; the server decides.

## Consequences

- ➕ Identity, moderation, ownership, economy, and royalties become enforceable
  because a trusted party owns the authoritative state (§1, §3, §12, §17, §21).
- ➕ Local-first play stays fast/offline-tolerant; only server-accepted results
  mutate the authoritative profile.
- ➖ The server is a real, cost-bearing service — it must be cost-modelled per MAU
  tier (roadmap C-3), not treated as a free static host.
- 🔁 Reversible only at high cost: every trust-dependent system assumes server
  authority. Reverting would reopen all six guarantees above (see 2026-07-11 verdict).

## Considered options

- **Server-authoritative control plane** (chosen) — the only option that makes
  identity, moderation, ownership, and the economy trustworthy for a small team.
- **Peer-to-peer** — rejected: cannot enforce identity/moderation/economy; higher
  mobile-networking risk; re-confirmed not worth reverting to on cost grounds.
- **Fat backend that re-derives outcomes** — rejected: a second rules build that
  drifts from the client; replaced by receipt validation + `ruleset_version` (§3).
