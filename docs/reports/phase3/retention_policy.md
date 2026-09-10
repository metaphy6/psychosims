# Phase 3.7 Data Retention Policy

> Historical proposal, superseded for implemented behavior by
> [Local retention and account erasure](../../../server/MAINTENANCE.md) and
> [Data lifecycle](../../project/DATA-LIFECYCLE.md). In particular, the blanket
> token TTL and jurisdiction-specific deletion timetable below are not enforced
> policy or claims of compliance. Actual expiry/retry protection, permanent
> replay fences and independently replayed erasure journals govern local code.

## Goals

- Keep enough history to reconstruct account state, audit chains, and support
  abuse investigation.
- Age out raw receipts and large telemetry artifacts to limit storage growth.
- Comply with the project's "no transcripts" rule: never retain free-form
  conversation transcripts.

## Default windows

| Data class | Default retention | Action at expiry |
|---|---|---|
| Raw submitted receipts | 90 days | Aggregate then hard-delete |
| Audit chain records | 2 years | Archive to long-term object storage |
| Device-key rotation history | 2 years | Anonymise key fingerprints |
| Profile ledger events | 3 years | Compress into snapshot rows |
| Session / auth tokens | <= 24 h | Hard-delete |
| Telemetry counters | 30 days | Roll into weekly aggregates |

## Exceptions

- A legal hold flag on an account extends retention of all related records.
- EU player data follows GDPR: account deletion request triggers a 30-day grace
  period then hard-delete unless legally retained.

## Implementation notes

- Soft-delete fields (`deleted_at`) mark rows for a background purge job.
- The purge job is idempotent and logs counts to `audit`.
- Canonical JSON snapshots are immutable once archived.
