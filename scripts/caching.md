# Build / dependency caching strategy

## CI caching

- `~/.pub-cache` — Dart/Flutter package cache.
- `~/.cache/go-build` + Go module cache — Go build/dependency cache.
- `native/build` — native compile artifacts.
- `test_fixtures/` — golden fixtures are committed, not generated.

## Local caching

- Dart `.dart_tool/` is gitignored and reused across builds.
- Go build cache (`~/.cache/go-build`) is reused across verify runs.

## Budget

- `make verify` target: under 5 minutes on a warm CI runner.
- Flaky tests fail the build; do not re-run without investigation.
