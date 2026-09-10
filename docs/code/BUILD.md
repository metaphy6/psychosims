# Build & task orchestration

> The single monorepo entry point for build, test, lint, and format.

Every module is driven through the root [`Makefile`](../../Makefile). Do not
invent per-module commands; add targets here and call through to the module
script in `scripts/`.

## Daily commands

```bash
make build        # build all modules
make test         # run all test suites
make lint         # run all linters
make format       # format all code
make format.check # check formatting without writing
make verify       # full gate, including real-model acceptance
make verify.contracts # CI gate without weights; no model-quality claim
make native.acceptance # real-model smoke and sanitizer cycles
make doctor       # sanity-check framework wiring and toolchains
```

## Module scripts

- `scripts/dart_*.sh` — Dart packages and Flutter app.
- `scripts/server_*.sh` — Go server (uses the module-local Go build cache).
- `scripts/native_*.sh` — pinned llama.cpp native engine and explicit stub contracts.
- `server/scripts/postgres_test.sh` — isolated local PostgreSQL race/integration gate.

## CI

CI runs `make verify.contracts` through the same build/lint/test orchestration,
selecting the explicitly model-free native contract target. `make verify`
also includes Flutter suites tagged `model_acceptance`, which contract CI
explicitly excludes and which fail on missing weights. The full gate
continues to require real weights and real-model sanitizer acceptance. Models
are large out-of-band assets; absent weights must never count as a passed
real-model test. Hosted matrix runs, branch protection, and physical-device
acceptance remain distinct gates; local passing tests do not prove them.
The rationale and alternatives are recorded in
[ADR-0008](../design/ADR-0008-explicit-model-acceptance.md).
