# tools/

> Headless tooling, sandboxes, bots, and diagnostics for Psychosims.

This module runs outside the Flutter app: balance sandboxes, mechanical
solvability bots, integration sandboxes, and diagnostics. It imports the same
`packages/psycore/` deterministic core the app uses.

## Layout

- `balance_sandbox_cli.dart` — bounded solver and deterministic bot sweep.
- `validate_manifest.dart` — manifest validation entry point.
- `showcase/phase2/` — readable demonstrations of the shipped pure core.

Run `scripts/showcase.sh` from the repository root to refresh the
[capability reports](../docs/reports/showcase/INDEX.md). Run
`dart run tools/balance_sandbox_cli.dart content/manifests` for the strict
corpus and throughput gate. A solver result of `solved` contains a winning
path for its supplied seed/loadout; budget exhaustion is reported as unproven.

See [`docs/code/ARCHITECTURE.md`](../docs/code/ARCHITECTURE.md) §2 and §5.
