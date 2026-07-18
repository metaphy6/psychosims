# ADR-0007 — Server Data Store

- **Status**: accepted
- **Date**: 2026-07-18
- **Deciders**: @maintainer
- **Supersedes**: roadmap "BaaS ecosystem" assumption for Phase 3 persistence

## Context

Phase 3 graduates the Go health-check skeleton into the authoritative control
plane. Before endpoints for identity, profiles, receipts, ownership, and audit
land, the persistence layer must be chosen: it underlies every authoritative
write path and every consistency guarantee.

An earlier roadmap sketch assumed a "BaaS ecosystem" might supply persistence.
That assumption predates:

- [ADR-0006](ADR-0006-server-runtime-go.md): the server runs in Go, not inside a
  BaaS runtime.
- [ADR-0002](ADR-0002-desktop-distribution-and-auth.md): identity is
  server-authoritative OAuth (Google/Apple), not BaaS identity.
- The C-3 cost model: the #2 cost driver is receipt write + bounded anomaly
  compute, #3 is DB-connection concurrency, and scale-to-zero is required.

A managed relational store gives the transactional guarantees, connection
control, operational maturity, and scale-to-zero options that a BaaS document
store sacrifices.

## Decision

The server control plane will use a **Go service fronting a managed relational
database** (Postgres-compatible, e.g. managed Postgres or Aurora) as its
authoritative store.

## Rationale

- **ACID transactions.** Profile, ledger, ownership, and audit-trail mutations
  for one receipt must commit atomically (3.0). Relational databases provide
  this natively; document stores require application-level compensation.
- **Connection pooling.** The C-3 model identifies DB connections / hot reads as
  the #3 cost driver. A pooled relational client bounds this directly; most
  serverless BaaS stores charge per request and offer less predictable latency.
- **Scale-to-zero fit.** Managed Postgres offers scale-to-zero or low-cost idle
  tiers matching the C-3 budget; the Go static binary cold-starts quickly and
  then warms a small connection pool.
- **Row-level security + optimistic concurrency.** `UPDATE … WHERE version = $n`
  and per-account foreign-key relationships are simple, reviewable SQL — not
  custom lock managers.
- **Audit trail + ledger fit.** Append-only ledger rows and hash-chained audit
  rows map cleanly to relational tables with indexed idempotency keys and
  correlation ids.
- **Operational maturity.** Backup, PITR, migrations, monitoring, and rollback
  are well-understood for managed Postgres and align with the 0.6 reliability
  targets.

## Schema scope

The store holds:

- `accounts` — server-authoritative identity rows.
- `profiles` — primitive atomic career metrics (<0.5 KB).
- `ledger_events` — append-only, idempotency-keyed, fixed-point-micros economy
  events.
- `ledger_snapshots` — periodic checkpoint rows for bounded replay.
- `cases` / `ownership_records` — C-8 ownership state machine rows.
- `device_keys` — per-account public signing keys + revocation metadata.
- `idempotency_keys` — deduplication records with bounded retention + GC.
- `audit_log` — hash-chained, append-only authoritative actions.
- `presence` — hot read/write presence records.

## Transactional model

- Every multi-entity authoritative write runs inside a single SQL transaction.
- The application uses **pessimistic locking only for short, bounded owner-record
  updates**; otherwise it uses optimistic concurrency (`version` columns with
  `UPDATE … WHERE version = $n`).
- The connection pool is sized to the C-3 concurrency cap and warmed at startup
  so a login storm is connection-bounded, not unbounded.

## Migration model

- Migrations are ordered, backward-compatible, expand-then-contract steps run at
  deploy.
- A bad migration is revertible via the rollback path in the migration runbook.
- The application fails loudly if the database schema version does not match the
  expected version range.

## Consequences

- `server/internal/store/` becomes the persistence boundary for all
  authoritative state.
- Schema migrations live under `server/internal/store/migrations/`.
- Local development uses a containerized Postgres; CI uses an ephemeral Postgres
  service.
- Secret values (DSN, credentials) are resolved by reference through the config
  authority; **no secret is committed to the repo**.
- ⏭ Production custody (KMS-encrypted credentials, automated rotation, PITR
  automation, DR drills) is the 0.6 hardening pass / Phase 7.6; Phase 3 stands
  up the interface + a manual restore drill.

## Alternatives considered

- **BaaS document store / Firebase / Supabase**: rejected because it reintroduces
  BaaS lock-in, weaker transactions, and unpredictable per-request pricing under
  the C-3 write-heavy receipt workload.
- **SQLite / embedded store**: rejected because it cannot satisfy the
  concurrency, connection-pooling, and operational-recovery requirements of a
  multi-client authoritative service.
- **DynamoDB / Cassandra**: rejected because the workload is relational
  (foreign-key account rows, atomic multi-entity commits, hash-chained audit
  log) and the team already uses SQL-shaped tooling.
