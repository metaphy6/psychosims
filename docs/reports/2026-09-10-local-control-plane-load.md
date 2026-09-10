# Local control-plane operating measurements

## Protocol declared before measurement

This is a lightweight local acceptance gate, not a production SLO or sustained
capacity claim. No cloud service, provider registration, deployment or release
is used. The gate creates its own disposable loopback PostgreSQL database and
runs the actual HTTP composition with durable bearer sessions and Ed25519 keys.
All accepted rewards remain `held_unproven` with no XP/currency payout.

Declared workload and thresholds (2026-09-10, before the first run):

| Check | Samples / concurrency | Acceptance threshold |
|---|---:|---|
| Authenticated boot over loopback HTTP and SQL | 200 / 8 | zero failed responses; p95 <= 500 ms |
| Exact accepted signed-receipt replay | 200 / 8 | zero failed responses; p95 <= 500 ms |
| Fresh distinct signed receipt acceptance and commit | 64 / 8 | zero failed responses; p95 <= 1000 ms; exactly 64 new consumed grants/audit accepts |
| SQL-pool saturation admission | 1 blocked request, limit 1 | excess request returns 503 + Retry-After within 250 ms; liveness remains 200; cancellation releases admission |
| Actual executable process start to ready | 3 fresh processes | every launch <= 2 s (build time and PostgreSQL container startup excluded) |
| Compressed executable artifact | 1 build, gzip | <= 50 MiB |

The server's configured request admission cap is independent of the database
connection cap. Measurements record CPU/runtime metadata, host load, SQL pool
statistics, aggregate HTTP observation counts and histogram storage bounds.
Contention from other local work is reported, never hidden by silently changing
the thresholds. A failed gate remains failed until a diagnosed correction.

## Reproduction

From the repository root: `bash server/scripts/postgres_test.sh --load`.
The test is explicitly tagged `postgres,load` and requires the disposable real
store. The helper uses an existing official PostgreSQL image with `--pull=never`,
preserves pre-existing containers and removes only its own on exit.

## Results

First run **PASS**, captured in
`/tmp/agent-runs/server-local-load-first--20260910T122149Z-846190.log`.
Linux/amd64, Go 1.26.7, 16 logical CPUs / GOMAXPROCS 16; host load averages were
5.45 / 5.60 / 4.97. Other project work, including model measurements, was active.
The HTTP workload was compiled with Go's race detector. Fresh process starts
used a normal `go build` binary against an already-running local PostgreSQL
container; filesystem caches and database pages were warm.

| Workload | Samples | p50 | p95 | Maximum | Batch elapsed |
|---|---:|---:|---:|---:|---:|
| Boot | 200 | 3.907 ms | 9.983 ms | 13.432 ms | 123.042 ms |
| Fresh receipt acceptance | 64 | 18.213 ms | 62.304 ms | 78.183 ms | 254.472 ms |
| Exact receipt replay | 200 | 12.650 ms | 21.807 ms | 31.822 ms | 327.234 ms |

All 464 measured requests returned successful responses. The 64 separately
prepared server authorizations plus those requests produced exactly 528 HTTP
observations in 13 fixed histogram buckets, without dropped observations.
SQL recorded 64 consumed authorizations and 64 valid audit-chain acceptance
rows; the profile advanced from version 1 to 65, retained XP 5, and the ledger
remained empty. The connection cap was 10, with zero pool waits in these
workloads. Replaying accepted receipts produced no additional durable mutation.

The saturation fixture held the sole SQL connection while one authenticated
request waited. Its excess request returned 503 with Retry-After in **0.561 ms**;
liveness remained 200 and cancellation restored successful boot handling.

Independent review found that releasing the held SQL connection before checking
recovery could hide a lookup that ignored cancellation. The strengthened test
first requires admission-controlled `/time` to return 200 while SQL remains
held, then releases SQL and requires `/v1/boot` to recover. It passed in
`load-cancellation-gate--20260910T122724Z-870503` (0.428 ms excess rejection).
An independent Go overlay deliberately removing the SQL lookup's request
context now fails that assertion; the mutation driver verified the failure in
`load-cancel-mutation-recheck--20260910T122913Z-877894`.

Fresh executable process readiness took **9.269, 7.671 and 9.189 ms**. Each
process shut down cleanly. The gzip artifact was **6,294,884 bytes**, below the
predeclared 50 MiB limit. These starts include process launch, catalog loading,
DB connection/migration check and readiness response; they do not include
building the binary, starting PostgreSQL, cold disk caches or provider sign-in.

Sustained soak, multiple-host/fleet limits, representative production traffic,
cloud cold starts, physical-device behavior, operating costs and production
SLOs remain pending. Retention cleanup is a separate lifecycle task.
