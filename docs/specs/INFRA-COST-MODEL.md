# 💰 C-3 — Infrastructure cost model

## Implementation plan — 2026-09-10

Goal: replace the placeholders below with a deterministic USD worksheet for
1k/10k/100k/1M MAU, including 1/12/36-month permanent data growth. Provider
selection, deployment and demonstrated production capacity remain pending.

Files: this cost spec (canonical editable assumptions), a standard-library
`scripts/infra_cost_model.py`, `xops/test/test_infra_cost_model.py`, and generated
`docs/reports/2026-09-10-infrastructure-costs.md`. Parent owns roadmap/gate wiring.

Tests: hand-calculated workload/storage fixtures, 90-day receipt plateau versus
permanent growth, billing-unit rounding, session/download sensitivity, invalid
inputs, and report drift failure. Verify official price pages before freezing;
distinguish price observations from unmeasured workload/capacity assumptions.

Checklist: [x] pin sourced rates and editable assumptions; [x] red regression
tests; [x] implement calculation/report; [x] verify arithmetic and drift gate.
Risk: request concurrency, DB throughput, retention, account churn and labor can
dominate the estimate; expose them rather than extrapolating the local 8-worker
acceptance gate into a capacity claim.


## Scope and invocation

This is a numeric planning worksheet, not provider selection or a capacity
acceptance. C-3's 10k-MAU ship gate remains pending a provider decision, measured
sustained workload, connection/lock limits, SLO/recovery evidence and a viable
revenue budget. The local 8-worker/64-receipt gate is correctness evidence only.

From the repository root, run `python3 scripts/infra_cost_model.py --write` to
refresh [the report](../reports/2026-09-10-infrastructure-costs.md), or run it
without arguments to fail on drift. `python3 -m unittest
xops.test.test_infra_cost_model` tests arithmetic, units and drift. The tool uses
only the standard library, Decimal arithmetic and these editable inputs. It has
no network, billing API, credentials or deployment side effects. Invalid or
ambiguous inputs fail; check mode never repairs a stale report silently.

## Observed price inputs

USD list rates were checked on 2026-09-10. They are reference arithmetic inputs;
no free-tier credits, promotional discounts, commitments or tax adjustments are
subtracted. A paid-plan included transfer entitlement is shown separately.

- Cloud Run request-based Iowa active CPU: $0.000024/vCPU-second, RAM:
  $0.0000025/GiB-second, requests: $0.40/million; the time quantum is 100ms.
  Minimum-instance idle CPU is $0.0000025/vCPU-second. This is one reference
  region and billing mode. [Official Cloud Run pricing](https://cloud.google.com/run/pricing).
- North America premium internet transfer reference: $0.12/GiB through 1024GiB,
  $0.11 for the next 9216GiB, then $0.08; the worksheet intentionally charges
  the normally free first GiB. Destinations and networking products alter
  rates. [Official network pricing](https://cloud.google.com/vpc/network-pricing).
- R2 Standard: $0.015/GB-month, class A $4.50/million, class B $0.36/million,
  direct R2 internet egress $0. R2 rounds storage/operation usage upward to
  billing units. Workers, CDN plans, WAF and other attached services are not
  automatically free. [Official R2 pricing](https://developers.cloudflare.com/r2/pricing/).
- Neon Launch/Scale compute: $0.106/$0.222 per CU-hour, database storage
  $0.35/GB-month, retained WAL history $0.20/GB-month. A CU is one vCPU with
  4GB RAM; published size bounds used here are 16/56CU. Current pricing HTML
  was checked directly because the browser parser failed; the November
  changelog independently corroborates compute rates. [Current pricing](https://neon.com/pricing),
  [compute-price change](https://neon.com/docs/changelog/2025-11-07),
  [CU and WAL billing explanation](https://neon.com/blog/new-usage-based-pricing).
- Neon paid plans include 500GB/project/month transfer from June 1, 2026,
  then $0.10/GB. The older 100GB search cache is stale.
  [June 2026 announcement](https://neon.com/blog/more-data-transfer-on-paid-plans),
  [current pricing](https://neon.com/pricing).

## Assumptions and equations

All usage, byte sizes, capacity and labor below are **assumptions**, not provider
promises or measured production distributions. The 32KiB structured-receipt
allowance is near the existing roughly 33KiB 100-turn fixture, but is not a
PostgreSQL row-size measurement. The protocol's 128KiB cap is tested as a
sensitivity. Model size 1.8GB is a delivery scenario, not a claim that all
current supported model artifacts have that size.

A month is normalized to 30 days/720 hours. For constant MAU M, sessions S=M×20
per month and cumulative sessions=S×age. Registered accounts=M×(1+0.1×(age−1));
churned identities remain represented. Month 1/12/36 results are end-of-horizon
monthly run rates, conservatively pricing that ending stock for a full month,
not cash invoices or acquisition forecasts. No erasure or archive discount is
assumed. The 90-day receipt stock is S×min(age,3), while permanent grants,
operation/hash/verdict markers, audit, ledger, cured ownership, royalties,
histories and moderation accumulate. Current receipt retention clears only
receipt bytes; it does not delete these replay or financial records. Future
moderation/history/royalty/macro services are explicitly budgeted even where
runtime implementation remains pending.

Database physical bytes=logical rows×2.5 for indexes, tuple/JSONB overhead and
bloat. Hot memory=physical GB×5%; estimated CU=max(1, peak operations/(200×50%),
hot memory/(4×70%)), rounded up to 0.25CU. Peak requests=monthly requests/
seconds×10. This **unmeasured** CU budget is priced for 720 hours, without
scale-to-zero savings. Exceeding a published CU limit flags the scenario as
outside a single compute shape; multiplying CU by a price is not proof a
sharded topology will work. The worksheet does not infer DB capacity from the
local acceptance latency or promise a connection limit.

HTTP volume includes 40 explicit refreshes per MAU, two requests per sign-in,
four other account requests, session requests, presence and abandoned starts.
Each rate is independently editable; refresh frequency is not hidden in the
other-request allowance. Each routine request is budgeted 40ms and a receipt 150ms, individually rounded
to 100ms, with one vCPU/0.5GiB and no concurrency sharing credit. Idle minimum
instance time, assumed cold starts, maintenance and backup compute are added.
This conservative per-request approximation can differ from real billed
instance intervals. API responses and SQL requests consume Cloud outbound
bandwidth; SQL responses and uncompressed full snapshot reads consume Neon
transfer. `pg_dump` compression happens on the client after that transfer.
Compressed snapshot uploads also consume Cloud outbound bandwidth. Model/manifest/history
traffic comes directly from R2, so its bytes are reported even when its egress
price is zero. Resumable range requests count as class B operations.

Two compressed full export copies plus four monthly exports are separate from
seven days of PITR WAL. WAL is estimated at 3×current-month logical
append/mutable write bytes: cumulative session/event bases add one month's
events, and permanent account bases add M accounts in month one then M×churn
each subsequent month. Lifetime stock divided by age is not the write rate;
validate with observed WAL amplification. Backup storage is based on logical
bytes×0.7 compression, avoiding index double-counting. R2 operation billing uses
ceil(requests/1,000,000) separately for A and B; aggregate storage rounds to GB.
Storage GB uses an explicit 1,000,000,000-byte worksheet convention; Cloud GiB
uses 2^30 bytes. Confirm each prospective provider's byte metering at purchase.

Provider-auth and observability allowances are internal budget contingencies,
not prices charged by Google/Apple OIDC or a selected auth vendor. Operations
and incident moderation labor are separate from the technical subtotal. No
server AI inference is modeled: gameplay inference remains local. Taxes,
external audits, payment-processing/creator cash payouts, multi-region standby,
24/7 staffing, private network endpoints and negotiated support need separate
quotes/decisions; royalty **accounting** storage/compute is included here.

## Canonical editable inputs

The unique JSON block is the calculator input. Bytes are logical per-row
allowances before the common DB multiplier. A dataset's `rows_per_basis`
expresses expected fractional/event rates, not a claim that partial rows exist.
Changing these inputs requires regenerating and reviewing the report.

```json
{
  "schema_version": 1,
  "price_checked": "2026-09-10",
  "usage": {
    "month_days": 30,
    "sessions_per_mau": 20,
    "new_accounts_per_mau_month": 0.1,
    "signins_per_mau": 2,
    "refreshes_per_mau": 40,
    "refresh_retention_days": 8,
    "receipt_retention_days": 90,
    "operational_retention_days": 2,
    "active_auth_sessions_per_mau": 2,
    "concurrent_users_fraction": 0.005,
    "session_minutes": 15,
    "presence_interval_seconds": 60,
    "api_requests_per_session": 4,
    "api_other_requests_per_mau": 4,
    "abandoned_start_fraction": 0.1,
    "model_downloads_per_mau": 0.2,
    "model_download_retry_factor": 1.1,
    "model_download_gb": 1.8,
    "download_chunk_bytes": 8388608,
    "manifest_fetches_per_session": 2,
    "manifest_fetches_per_mau": 2,
    "manifest_bytes": 65536,
    "model_and_catalog_storage_gb": 100,
    "history_events_per_session": 0.2,
    "history_fetches_per_session": 0.5,
    "moderation_incidents_per_mau_month": 0.005,
    "macro_events_per_month": 720,
    "db_index_bloat_multiplier": 2.5,
    "backup_copies": 2,
    "backup_exports_per_month": 4,
    "backup_compression_fraction": 0.7,
    "backup_object_chunk_bytes": 67108864,
    "pitr_days": 7,
    "wal_write_multiplier": 3,
    "mutable_write_bytes_per_request": 1024,
    "db_ops_per_request": 6,
    "db_response_bytes_per_request": 4096,
    "db_outbound_query_bytes_per_request": 1024,
    "api_response_bytes_per_request": 2048,
    "request_log_bytes": 512,
    "peak_to_average_requests": 10,
    "db_ops_per_cu_second": 200,
    "db_target_utilization": 0.5,
    "db_working_set_fraction": 0.05,
    "db_memory_utilization": 0.7,
    "db_memory_gb_per_cu": 4,
    "db_min_cu": 1,
    "db_cu_step": 0.25,
    "launch_max_cu": 16,
    "scale_max_cu": 56,
    "routine_request_seconds": 0.04,
    "receipt_request_seconds": 0.15,
    "app_vcpu": 1,
    "app_memory_gib": 0.5,
    "app_min_instances": 1,
    "cold_starts_per_mau": 0.05,
    "cold_start_seconds": 0.8,
    "background_cpu_seconds_per_session": 0.02,
    "background_cpu_seconds_base": 3600,
    "db_backup_cpu_seconds_per_gb": 2,
    "provider_auth_usd_per_mau_allowance": 0.005,
    "observability_fixed_usd": 75,
    "observability_usd_per_log_gb_allowance": 0.5,
    "ops_base_hours": 20,
    "ops_hours_per_10k_mau": 2,
    "ops_usd_per_hour": 60,
    "moderation_minutes_per_incident": 10,
    "moderation_usd_per_hour": 35,
    "storage_bytes_per_gb": 1000000000
  },
  "rates": {
    "cloud_active_vcpu_second": 2.4e-05,
    "cloud_idle_vcpu_second": 2.5e-06,
    "cloud_gib_second": 2.5e-06,
    "cloud_request_million": 0.4,
    "cloud_billing_quantum_seconds": 0.1,
    "cloud_egress_first_gib": 0.12,
    "cloud_egress_next_gib": 0.11,
    "cloud_egress_high_gib": 0.08,
    "neon_launch_cu_hour": 0.106,
    "neon_scale_cu_hour": 0.222,
    "neon_storage_gb_month": 0.35,
    "neon_pitr_gb_month": 0.2,
    "neon_included_transfer_gb": 500,
    "neon_transfer_gb": 0.1,
    "r2_storage_gb_month": 0.015,
    "r2_class_a_million": 4.5,
    "r2_class_b_million": 0.36,
    "r2_egress_gb": 0
  },
  "datasets": [
    {
      "name": "profiles",
      "basis": "accounts",
      "rows_per_basis": 1,
      "bytes_per_row": 1536,
      "retention": "live",
      "store": "db"
    },
    {
      "name": "provider_identities",
      "basis": "accounts",
      "rows_per_basis": 2,
      "bytes_per_row": 512,
      "retention": "live",
      "store": "db"
    },
    {
      "name": "active_auth_claims",
      "basis": "active_auth_sessions",
      "rows_per_basis": 1,
      "bytes_per_row": 2048,
      "retention": "live",
      "store": "db"
    },
    {
      "name": "refresh_rotation_material",
      "basis": "retained_refreshes",
      "rows_per_basis": 1,
      "bytes_per_row": 2048,
      "retention": "8d",
      "store": "db"
    },
    {
      "name": "oauth_attempt_state",
      "basis": "recent_signins",
      "rows_per_basis": 1,
      "bytes_per_row": 1024,
      "retention": "2d",
      "store": "db"
    },
    {
      "name": "auth_issue_replay_markers",
      "basis": "cumulative_signins",
      "rows_per_basis": 1,
      "bytes_per_row": 384,
      "retention": "permanent",
      "store": "db"
    },
    {
      "name": "oauth_exchange_replay_markers",
      "basis": "cumulative_signins",
      "rows_per_basis": 0.5,
      "bytes_per_row": 320,
      "retention": "permanent",
      "store": "db"
    },
    {
      "name": "device_keys_and_operation_markers",
      "basis": "accounts",
      "rows_per_basis": 3,
      "bytes_per_row": 512,
      "retention": "permanent",
      "store": "db"
    },
    {
      "name": "presence",
      "basis": "concurrent_users",
      "rows_per_basis": 1,
      "bytes_per_row": 1024,
      "retention": "live",
      "store": "db"
    },
    {
      "name": "live_ownership",
      "basis": "mau",
      "rows_per_basis": 3,
      "bytes_per_row": 2048,
      "retention": "live",
      "store": "db"
    },
    {
      "name": "terminal_ownership",
      "basis": "cumulative_sessions",
      "rows_per_basis": 0.1,
      "bytes_per_row": 2048,
      "retention": "permanent",
      "store": "db"
    },
    {
      "name": "structured_receipt_payloads",
      "basis": "retained_sessions",
      "rows_per_basis": 1,
      "bytes_per_row": 32768,
      "retention": "90d",
      "store": "db"
    },
    {
      "name": "accepted_grants_hashes_verdicts",
      "basis": "cumulative_sessions",
      "rows_per_basis": 1,
      "bytes_per_row": 8192,
      "retention": "permanent",
      "store": "db"
    },
    {
      "name": "session_start_replay_markers",
      "basis": "cumulative_starts",
      "rows_per_basis": 1,
      "bytes_per_row": 512,
      "retention": "permanent",
      "store": "db"
    },
    {
      "name": "unused_authorizations",
      "basis": "unused_starts",
      "rows_per_basis": 1,
      "bytes_per_row": 8192,
      "retention": "2d",
      "store": "db"
    },
    {
      "name": "response_idempotency_cache",
      "basis": "recent_sessions",
      "rows_per_basis": 1,
      "bytes_per_row": 2048,
      "retention": "2d",
      "store": "db"
    },
    {
      "name": "audit_records",
      "basis": "cumulative_sessions",
      "rows_per_basis": 4,
      "bytes_per_row": 768,
      "retention": "permanent",
      "store": "db"
    },
    {
      "name": "auth_audit_records",
      "basis": "cumulative_signins",
      "rows_per_basis": 2,
      "bytes_per_row": 512,
      "retention": "permanent",
      "store": "db"
    },
    {
      "name": "ledger_events",
      "basis": "cumulative_sessions",
      "rows_per_basis": 4,
      "bytes_per_row": 384,
      "retention": "permanent",
      "store": "db"
    },
    {
      "name": "certified_cures",
      "basis": "cumulative_sessions",
      "rows_per_basis": 0.2,
      "bytes_per_row": 512,
      "retention": "permanent",
      "store": "db"
    },
    {
      "name": "moderation_records",
      "basis": "moderation_incidents",
      "rows_per_basis": 1,
      "bytes_per_row": 2048,
      "retention": "permanent",
      "store": "db"
    },
    {
      "name": "revocation_and_erasure_markers",
      "basis": "accounts",
      "rows_per_basis": 0.05,
      "bytes_per_row": 512,
      "retention": "permanent",
      "store": "db"
    },
    {
      "name": "signed_history_metadata",
      "basis": "history_events",
      "rows_per_basis": 1,
      "bytes_per_row": 512,
      "retention": "permanent",
      "store": "db"
    },
    {
      "name": "signed_history_objects",
      "basis": "history_events",
      "rows_per_basis": 1,
      "bytes_per_row": 4096,
      "retention": "permanent",
      "store": "object"
    },
    {
      "name": "royalty_ledger",
      "basis": "cumulative_sessions",
      "rows_per_basis": 0.2,
      "bytes_per_row": 512,
      "retention": "permanent",
      "store": "db"
    },
    {
      "name": "creator_royalty_profiles",
      "basis": "accounts",
      "rows_per_basis": 0.005,
      "bytes_per_row": 4096,
      "retention": "live",
      "store": "db"
    },
    {
      "name": "macro_event_metadata",
      "basis": "macro_events",
      "rows_per_basis": 1,
      "bytes_per_row": 512,
      "retention": "permanent",
      "store": "db"
    },
    {
      "name": "macro_event_objects",
      "basis": "macro_events",
      "rows_per_basis": 1,
      "bytes_per_row": 8192,
      "retention": "permanent",
      "store": "object"
    }
  ]
}
```
