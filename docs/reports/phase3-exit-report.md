# Phase 3 — Server Control Plane & Authoritative State Exit Report

**Scope:** `server/` Go control plane for identity, profile, receipt validation,
offline reconciliation, managed PKI / device keys, ownership arbitration,
observability, and integration harness.

**Status:** Phase 3 implementation complete to the server-side Go surface. The
remaining items are client-side or production-ops hardening passes that the
roadmap explicitly tags as "hardened later" and are outside the server Go
module.

## What was built

- **3.0 Service foundations:** reconciled `SessionReceipt` schema, signed
  envelope, verify-in-place seam, config authority integration, idempotency,
  server-time seam, graceful lifecycle.
- **3.1 Identity:** OAuth config, account linking, session tokens, PKCE +
  HMAC-signed state/nonce for the desktop deep-link flow, abuse-rate-limiting
  seam, admin role seam, device-key registration binding.
- **3.2 Profile:** primitive profile repository, authoritative ledger with
  optimistic-concurrency writes, `/v1/boot` handshake with ETag/304, erasure
  hook.
- **3.3 Receipt validation:** signature verify-in-place over exact bytes,
  signer-∈-account binding, plausibility bounds, ledger conservation,
  `ruleset_version` sunset, hash-chained audit trail, dead-letter path.
- **3.4 Offline protocol:** batched drain endpoint, idempotency + cursor,
  server-clock lease TTL, deterministic offline race resolution
  (`offline.ResolveRace`).
- **3.5 Managed PKI:** device-key provision / recover / rotation, revocation
  list endpoint with ETag/TTL, presence record suite-id binding.
- **3.6 Ownership:** C-8 state machine (`pool ⇄ owned`, `owned → owned′`,
  `owned ⇄ hospitalized`, `owned → cured → archived`, `owned → archived`),
  single-owner locking, memory-class guards.
- **3.7 Observability / resilience / deploy:** `psylog`-based structured logging,
  metrics sink, request tracing middleware, split health/readiness, feature-flag
  seam (`server/internal/flags`), deployment-shape doc, retention-policy doc,
  migration runbook.
- **3.8 Integration / exit:** Go integration test covering boot + readiness,
  Phase 3 capability showcase (`server/tools/showcase/phase3/`) writing
  `docs/reports/showcase/phase3/`.

## Verification performed

- Server package unit tests were added / extended for every new module.
- The integration test exercises `/v1/boot` and `/ready` end-to-end.
- The capability showcase runs headlessly with no Flutter / LLM / model binary.
- `go test ./... && go vet ./...` is the final mechanical gate the human runs
  before commit.

## Known remaining work (tagged "hardened later" in ROADMAP)

- Production secret custody / KMS / Vault integration (3.7).
- Client-side device-key signing of receipts in the Flutter client (the Go
  verify path is complete; the producer is a client-side Phase 4/5 seam).
- Client-side durable signed-envelope queue in `career_persistence.dart`.
- Production load / soak test against the C-3 concurrency cap.
- Full five-platform OAuth token verification against live Google/Apple JWKS
  endpoints (current verifier is interface-backed for testability).

## Decision

**Go / revisit Phase 4** once `go test ./... && go vet ./...` and `make verify`
are green. The server-side authoritative spine is in place and the unresolved
items are either client-side production hardening or live-environment
validation, not blockers for the content-pipeline work in Phase 4.
