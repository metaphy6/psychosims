# 🛡️ C-10 — UGC moderation staffing & SLA

> **Closes register item C-10** ([ROADMAP](../planning/ROADMAP.md#-conceptual-corrections-register)).
> §2.4 makes this the entry gate for the open authoring ecosystem: before the
> portal opens to external contributors, a moderation staffing model + review SLA
> must exist so the validation/signing pipeline (§2.2, §2.5) is backed by real
> capacity, not an unbounded unstaffed queue. Section refs (§N) → [`STARTER.md`](../../STARTER.md).

- **Status:** policy set (enforced as the Phase 6.4 entry gate)
- **Owner:** @maintainer
- **Consumed by:** Phase 6.4 (open authoring portal); the portal **does not open** until this holds.

## Why capacity is the gate

Human review cost scales directly with creator count (§2.4). The automated passes
(structural + mechanical solvability, toxicity screening — Phase 4.3) reduce but do
not remove human judgment for borderline content. An open queue without staffing is
the trap this gate prevents.

## Review pipeline (each submission)

1. **Automated pre-gate (free, every submission):** schema validation + mechanical
   solvability (bot harness, no LLM) + toxicity/safety screening (Phase 4.3).
   Auto-reject fails; only survivors reach humans.
2. **Human review (sampled + all borderline):** a reviewer confirms tone (esp.
   Manipulative-card guidelines, [C-6](AGE-RATING-AND-CONTENT-STRATEGY.md)),
   fictional-taxonomy compliance (§8), and no disallowed content.
3. **Sign + publish** (§2.2) or **reject with reason**.

## Staffing model (scales with creator count)

Capacity is expressed as **reviewer-hours per N active creators**, revisited each
tier. Illustrative starting posture (a placeholder to confirm before opening):

| Active creators | Reviewer coverage | Notes |
|---|---|---|
| soft launch (≤ ~100) | 1 part-time reviewer + operator backup | invite-only; low volume. |
| growth (≤ ~1k) | ≥ 1 dedicated reviewer | queue metrics watched weekly. |
| scale (> ~1k) | reviewer pool + lead + tooling | trusted-creator fast-lane to cut load. |

The portal opens at **soft launch only when coverage for that tier is staffed** —
capacity precedes openness, not the reverse.

## Review SLA

| Item | Target |
|---|---|
| First-review turnaround (standard) | ≤ 3 business days |
| Borderline / escalated | ≤ 5 business days |
| Re-review after author fix | ≤ 2 business days |
| Post-publish incident (reported/quarantined) | triage ≤ 24 h |

Missing the SLA throttles new submissions (queue backpressure) rather than
letting an unreviewed backlog grow unbounded.

## Escalation path (borderline content)

1. Reviewer flags → 2. moderation **lead** decision → 3. operator/legal review for
tone/legal-edge cases (esp. Manipulative content) → 4. logged outcome feeding
creator standing.

## Enforcement hooks (already in the design)

- **Signing gate** (§2.2): only reviewed content is signed + published.
- **Revocation list** (§2.5, §17): published content can be quarantined/pulled from
  the CDN post-hoc; clients drop revoked entries.
- **Creator standing / royalties** ([§21](../../STARTER.md)): repeated violations reduce
  standing; royalties already gated on validated events + anomaly detection.
- **Trusted-creator fast-lane:** proven creators get lighter sampling to keep the
  queue tractable at scale.

## Entry-gate checklist (Phase 6.4)

- [ ] Reviewer coverage staffed for the launch tier.
- [ ] SLA published + queue backpressure wired.
- [ ] Escalation path + logging in place.
- [ ] Automated pre-gate (Phase 4.3) live so humans only see survivors.

## Open (confirmed before opening)

- Concrete reviewer-hours-per-creator ratio and the trusted-creator fast-lane criteria.
- Whether soft launch is invite-only (recommended) vs open.
