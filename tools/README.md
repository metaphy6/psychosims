# tools/

> Headless tooling, sandboxes, bots, and diagnostics for Psychosims.

This module runs outside the Flutter app: balance sandboxes, mechanical
solvability bots, integration sandboxes, and diagnostics. It imports the same
`packages/psycore/` deterministic core the app uses.

## Layout

- `bin/` — runnable entry points.
- `lib/` — shared tool logic.
- `test/` — tool tests.

See [`docs/code/ARCHITECTURE.md`](../docs/code/ARCHITECTURE.md) §2 and §5.
