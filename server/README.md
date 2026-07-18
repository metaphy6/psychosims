# server/

> Authoritative server control plane for Psychosims.

This module owns identity, profiles/progression, receipt validation, ownership
arbitration, matchmaking, content signing, economy ledger, moderation, and
macro-event seeding.

## Runtime

Go 1.26+. See [`ADR-0006`](../docs/design/ADR-0006-server-runtime-go.md) for the
runtime decision (superseding ADR-0003). No third-party web framework is used;
the control plane is built on the standard library.

## Layout

- `go.mod` — module definition (`psychosims.dev/server`).
- `cmd/psy-server/` — the server entrypoint (`main`).
- `internal/server/` — HTTP wiring (health check today; Phase 3 endpoints later).
- `internal/schemas/` — Go structs mirroring the Dart `packages/psychemas/` contract.
- `internal/psylog/` — cross-stack structured logger (see [`docs/code/LOGGING.md`](../docs/code/LOGGING.md)).

## Run

```bash
go run ./cmd/psy-server   # from server/
```

## Develop

```bash
make server.build          # go build ./...
make server.test           # go test ./...
make server.lint           # go vet + gofmt check
make server.format         # gofmt -w
```

See [`docs/code/ARCHITECTURE.md`](../docs/code/ARCHITECTURE.md) for the
trust-boundary contract and [`docs/code/SHARED_SCHEMAS.md`](../docs/code/SHARED_SCHEMAS.md)
for the Dart↔Go schema alignment discipline.
