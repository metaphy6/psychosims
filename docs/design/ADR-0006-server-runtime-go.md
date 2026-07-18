# ADR-0006 — Server Runtime (Go)

- **Status**: accepted
- **Date**: 2026-07-18
- **Deciders**: @maintainer
- **Supersedes**: [ADR-0003](ADR-0003-server-runtime.md)

## Context

[ADR-0003](ADR-0003-server-runtime.md) chose Python/FastAPI for the
authoritative server. Its strongest justification was the possibility of sharing
schema and deterministic sim logic with the Dart `psycore`/`psychemas` packages
to avoid cross-language drift.

Revisiting the decision before Phase 3 begins — while `server/` is still a
health-check skeleton with **no sim math written** — the trust-plane model has
been clarified (see [`Consideration-server-runtime.md`](Consideration-server-runtime.md)):

- The server **verifies** integrity/authenticity over the exact received bytes
  (signatures) and enforces cheap, language-neutral invariants (ledger
  conservation, idempotency keys, ownership state-machine legality, rate caps).
- It **does not** re-derive doubt / operational pressure / Trauma Severity or
  re-simulate outcomes, so it never needs to reproduce the fixed-point PRNG or
  canonical-JSON byte format.

Because the server does not re-run sim math, the "share Dart code" advantage that
favoured a Dart server — and much of the parity concern that favoured any
shared-language option — largely evaporates. What remains shared is a handful of
parsed fields, already covered by golden-fixture contract tests.

## Decision

The server control plane will be implemented in **Go** (1.26.x), using the
standard library `net/http` for endpoints and `encoding/json` for schema
handling. No third-party web framework is adopted at this stage.

## Rationale

- **Scale-to-zero fit.** A statically linked Go binary has millisecond cold
  starts and a small memory footprint — the best shape for the intended
  scale-to-zero deployment. Python/FastAPI has the heaviest cold start of the
  candidates.
- **Type safety at the trust boundary.** Go gives compile-time types and a
  fail-closed error-handling culture on a correctness-critical surface.
- **Verify-in-place signatures.** Go's standard-library crypto verifies
  signatures over received bytes without re-canonicalization, keeping the server
  fully decoupled from the Dart determinism contract.
- **Mature server ecosystem.** Managed deploys, observability, and crypto/JWT
  libraries are first-class — unlike Dart's comparatively immature server
  ecosystem, which was the user's stated concern.
- **Bounded porting cost.** The server is small (byte verification + a few
  parsed fields + an ownership state machine), so a third language adds little.

## Consequences

- `server/` is a Go module (`psychosims.dev/server`): `cmd/psy-server/` holds the
  entrypoint; `internal/schemas/`, `internal/server/`, and `internal/psylog/`
  hold the schema mirror, HTTP wiring, and cross-stack logger.
- `packages/` remains Dart, reused by `app/` and `tools/`. Shared schemas are
  mirrored as Go structs in `server/internal/schemas/` and kept aligned via the
  golden-fixture contract tests in `test_fixtures/`.
- Build/lint/format/test flow through the existing `make server.*` targets,
  backed by `go build` / `go test` / `go vet` / `gofmt`.
- The former Python module, its `pyproject.toml`, and `.pydeps` tooling are
  removed. CI provisions Go instead of Python for the server.
- **Invariant to preserve:** the server verifies signatures over the exact
  received bytes and never re-serializes or re-simulates to check. If a future
  cheat can only be caught by re-deriving one specific outcome, that single
  routine is where sharing the Dart implementation would be reconsidered.

## Alternatives considered

- **Python/FastAPI (ADR-0003, superseded)**: best build velocity and ecosystem,
  excellent runtime validation via Pydantic, but heaviest cold start and only
  runtime type-safety. Would be reconsidered if ML-assisted moderation moves
  on-server in the near term.
- **Dart server (dart_frog / shelf / serverpod)**: would maximise repo cohesion
  and schema sharing, but its unique advantage (sharing sim math) is low-value
  under the minimal-server model, and its server/deploy/observability ecosystem
  is immature.
- **Rust**: best correctness/perf, highest build-time and contributor cost;
  overkill for a near-zero-traffic trust plane.
