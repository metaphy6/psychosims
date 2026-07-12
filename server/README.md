# server/

> Authoritative server control plane for Psychosims.

This module owns identity, profiles/progression, receipt validation, ownership
arbitration, matchmaking, content signing, economy ledger, moderation, and
macro-event seeding.

## Runtime

Python 3.12+ with FastAPI. See `pyproject.toml` for dependencies and scripts.

## Layout

- `src/` — application source.
- `tests/` — server-side tests.
- `scripts/` — operational scripts.

## Run

```bash
python -m server
```

See [`docs/code/ARCHITECTURE.md`](../docs/code/ARCHITECTURE.md) for the
trust-boundary contract.
