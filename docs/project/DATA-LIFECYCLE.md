# Data lifecycle & erasure

## Classification

- **Authoritative ledger:** pseudonymous IDs only; no PII.
- **Client cache:** encrypted local store; refreshed from server.
- **Auth tokens:** platform secure storage.
- **Raw transcripts:** intentionally never persisted.

## Erasure

- Right-to-erasure triggers revocation-list update + ledger tombstone.
- PII separation means no PII needs to be scrubbed from the ledger.
- Age-gate/consent data is deleted on revocation.

## Backup / DR

- Point-in-time recovery target: 1 hour RPO, 4 hour RTO for authoritative store.
- Restore drill runs in Phase 3.2 once the store exists.
