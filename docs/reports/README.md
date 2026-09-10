# 📊 `docs/reports/`

Generated reports — audit snapshots, status dumps, performance baselines.
Filenames embed the date (`YYYY-MM-DD-<topic>.md`).

This folder is mostly written by tools, not humans. Don't hand-edit reports
after they're committed.

## Current assessment

- [2026-09-10 — end-to-end project assessment](2026-09-10-project-assessment.md): implemented capabilities, remaining roadmap, integration defects, current verification evidence and recommended next milestones.
- [2026-09-10 — remediation progress](2026-09-10-remediation-progress.md): current local acceptance, finite certified progression, verification evidence and remaining implementation; supersedes historical completion claims without replacing the roadmap.
- [2026-09-10 — local database recovery](2026-09-10-local-database-recovery.md): actual PostgreSQL logical backup and restore, recovered receipt replay protection and session revocation; local synthetic fixture only.
- [2026-09-10 — local control-plane load](2026-09-10-local-control-plane-load.md): declared HTTP/SQL workload budgets, fresh signed acceptances and retries, admission under a saturated database pool, and executable startup measurements.
- [2026-09-10 — infrastructure costs](2026-09-10-infrastructure-costs.md): sourced reference rates and editable workload assumptions at four MAU tiers and three data-age horizons; capacity and provider decisions remain pending.

- [2026-09-10 — three-model local baseline](2026-09-10-model-baseline.md): complete measured latency/quality failures and passes with raw samples; no device-acceptance claim.

## Living generated evidence

- [Resolved dependency inventory](dependency-inventory.cdx.json): deterministic CycloneDX inventory, dependency edges and license fingerprints. `scripts/sbom.sh` checks it without rewriting; `scripts/sbom.sh --write` explicitly updates it for review. This inventory is intentionally regenerated when dependency inputs change.
