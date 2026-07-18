# Phase 3.7 Deployment Shape

## Target platform

- Go static binary (`go build`) built for `linux/amd64`.
- Container image based on `gcr.io/distroless/static` or equivalent.
- Managed Postgres-compatible store (e.g. Cloud SQL, RDS, Neon, Supabase) for
  authoritative state.

## Cold-start budget

- Binary size target: < 50 MB compressed.
- Startup time target: < 2 s from process start to serving traffic, including
  DB pool warm-up and migration check.
- Scale-to-zero: the service can start from zero to serving in the cold-start
  budget; keep migrations idempotent and backward-compatible.

## Canary / rollback

- Deploy behind a load balancer / reverse proxy.
- Canary: route 5% of traffic to the new version; monitor p95 validation
  latency, error rate, and store saturation.
- Rollback: revert the active image tag. Migrations are expand-then-contract, so
  a rollback does not require schema reversal unless a contract-breaking change
  was deployed.

## Health probes

- `/health` — liveness; returns 200 if the process is healthy.
- `/ready` — readiness; verifies DB reachability and reports dependency status.
- `/v1/boot` and receipt endpoints return 503 when backpressure is engaged.

## Cost levers

- Receipt validation compute: bounded per-receipt checks; no sim engine.
- DB connections: pooled; readiness fails if saturated.
- Audit / ledger retention: raw receipts age out; derived aggregates and ledger
  snapshots stay.
