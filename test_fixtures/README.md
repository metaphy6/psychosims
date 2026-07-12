# Test fixtures

> Golden fixtures, sample manifests, sample receipts, and deterministic seeds.

## Layout

- `manifests/` — canonical sample patient manifests.
- `receipts/` — sample session receipts.
- `deltas/` — sample structured deltas.
- `seeds/` — deterministic RNG seeds for CI.

## Rules

- Fixtures move with the code they pin.
- CI uses a fixed seed convention; see `seeds/ci_seed.txt`.
