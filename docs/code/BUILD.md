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
make verify       # build + lint + format.check + test + doctor (CI gate)
make doctor       # sanity-check framework wiring and toolchains
```

## Module scripts

- `scripts/dart_*.sh` — Dart packages and Flutter app.
- `scripts/server_*.sh` — Python server (uses project-local `.pydeps`).
- `scripts/native_*.sh` — C/C++ native stub.

## CI

The same `make verify` command runs locally and in CI. No CI-specific build
paths unless absolutely required.
