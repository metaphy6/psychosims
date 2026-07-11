# 💰 C-3 — Infrastructure cost model

> **Closes register item C-3** ([ROADMAP](../planning/ROADMAP.md#-conceptual-corrections-register)).
> The §3 entry gate: model real server cost at 1k / 10k / 100k / 1M MAU against the
> **full** server dataset — not just profile rows. Section refs (§N) → [`STARTER.md`](../../STARTER.md).

- **Status:** drafted model (structure + assumptions fixed; $ figures are illustrative until quotes)
- **Owner:** @maintainer
- **Gate:** the first server-authoritative online phase (Phase 3) **does not ship** until this
  model holds at 10k MAU against the full dataset list below (§3).

> ⚠️ **Dollar figures are illustrative placeholders**, not quotes. They exist to
> shape the *structure* of the cost and flag where it concentrates. Real numbers
> come from provider pricing at implementation time and are recorded here then.

## Why the free tier is not a plan

§3 is explicit: the BaaS free tier (e.g. 500 MB / ~0.5 KB per profile) counts
**only profile rows** and ignores auth MAU caps, egress, connection limits,
project-pausing, and every *other* dataset below. Paid tiers are assumed from the
first real users onward.

## The full server dataset (what actually costs money)

| Dataset | Grows with | Weight | Notes |
|---|---|---|---|
| Profiles | MAU | tiny (~0.5 KB/row) | The only thing the free-tier math counts. |
| Auth (identities/sessions) | MAU | metered | Auth MAU caps bite before storage does. |
| Matchmaking / presence state | concurrent users | moderate, hot | Read/write heavy; drives DB connections. |
| Ownership records + lifecycle | active cases | moderate | Authoritative locking state (§12, §18). |
| Session receipts + anomaly history | sessions/day | **large, write-heavy** | The validation spine (§3); retention policy matters. |
| Moderation + revocation list | content + incidents | moderate | Must be fast-read at fetch time (§2.5, §17). |
| Signed case-history envelopes | persistent patients | moderate | Server-signed; not transcripts (§17). |
| Royalty accounting | creators × treatments | moderate | Per-event ledger (§21). |
| Audit + macro-event records | time | moderate | Retention-bounded (§22). |
| **CDN / object store egress** | downloads + sessions | **large** | Manifest fetches + the ~1.8 GB first-run model. |

## Cost drivers, ranked

1. **CDN egress** — the ~1.8 GB first-run model download dominates at scale
   (mitigated by the C-1 delivery/retry strategy + caching).
2. **Receipt write + anomaly-detection compute** — every session produces a receipt.
3. **DB connections / hot matchmaking reads** — concurrency, not storage, is the cap.
4. **Auth MAU** — metered per active user.
5. Storage is the *smallest* driver — the opposite of the free-tier assumption.

## Model skeleton (fill $ at implementation)

Per-tier, sum: `auth(MAU) + db_storage + db_compute/connections + receipt_pipeline
+ cdn_egress(first-run installs × 1.8GB + manifest fetches) + moderation + misc`.

| MAU | Installs/mo (est.) | Dominant line | Illustrative $/mo (PLACEHOLDER) | Verdict gate |
|---|---|---|---|---|
| 1k | ~1k | CDN first-run egress | $ (low, paid tier) | sanity only |
| **10k** | ~10k | CDN egress + receipts | $$ | **the ship gate** |
| 100k | ~100k | CDN + DB compute | $$$ | pre-scale review |
| 1M | ~1M | CDN + DB + auth | $$$$ | requires CDN contract + sharding plan |

## Levers that bound cost

- **Structured, cacheable manifests** (§2.3) keep per-fetch egress tiny.
- **Model delivery/retry strategy** (C-1) controls the expensive 1.8 GB line.
- **Receipt retention window** (raw receipts age out; keep derived aggregates).
- **No transcripts stored** (§5, §17) removes the largest potential dataset entirely.

## Revenue side (so the gate is two-sided)

Sustainability compares this cost against the §19 real-money SKUs (case packs,
sidegrade decks, identity packs, hard-capped subspecialty points). The revenue
inputs come from §19 and the SKU test (Phase 7.2); this model owns the **cost** side.

## Open (resolved with real quotes)

- Provider selection (BaaS + CDN) and their egress pricing.
- Receipt retention window (balance: anomaly-detection depth vs storage).
- Install→MAU ratio assumption (drives the dominant CDN line).
