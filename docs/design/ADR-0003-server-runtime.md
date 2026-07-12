# ADR-0003 — Server Runtime

- **Status**: accepted
- **Date**: 2026-07-12
- **Deciders**: @maintainer

## Context

Phase 0.1 requires settling the server runtime/language so the `packages/`
sharing strategy (one schema package vs two aligned ones) and the toolchain are
unambiguous before Phase 3 implementation begins.

## Decision

The server control plane will be implemented in **Python 3.12+** with **FastAPI**
for HTTP endpoints and **Pydantic v2** for schema validation.

## Rationale

- The client and tools use Dart; shared schemas for client/tools live in
  `packages/psychemas/` (Dart).
- The server needs a separate language-neutral contract (OpenAPI/JSON Schema)
  because Python is not Dart. Pydantic models can generate JSON Schema that is
  kept in lockstep with the Dart schemas.
- Python/FastAPI offers a small, readable, deployable server footprint aligned
  with the cost model and a shallow learning curve for contributors.

## Consequences

- `packages/` contains Dart packages reused by `app/` and `tools/`.
- `server/` contains Python Pydantic models that mirror the Dart schemas.
- A contract test (Phase 0.5) will round-trip receipt/manifest JSON between
  Dart and Python to prevent drift.

## Alternatives considered

- **Dart server (shelf/conduit)**: rejected because the ecosystem for managed
  deployment, observability, and BaaS integration is smaller than Python's.
- **Go/Rust**: rejected as adding toolchain complexity before the PoC; can be
  revisited if the cost model demands it.
