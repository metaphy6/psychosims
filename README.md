# psychosims

> A cross-platform, fictional psychology-practice social-simulation game: an
> on-device AI voices patients, a deterministic core owns every outcome, and a
> small authoritative server makes progression, ownership, and the economy
> trustworthy across players.

## Quickstart

```bash
scripts/bootstrap.sh # resolve project dependencies and local security tooling
make verify.contracts # build, lint, format and tests without model weights
# With the configured GGUF downloaded to assets/models/:
make verify          # also requires real-model smoke and sanitizer acceptance
```

## Documentation

- [`AGENTS.md`](AGENTS.md) — rules every AI coding assistant follows in this repo.
- [`docs/design/STARTER.md`](docs/design/STARTER.md) — the project blueprint (§1–§24).
- [`docs/planning/ROADMAP.md`](docs/planning/ROADMAP.md) — the plan.
- [`docs/project/CHARTER.md`](docs/project/CHARTER.md) — vision, scope, success criteria.
- [`docs/code/ARCHITECTURE.md`](docs/code/ARCHITECTURE.md) — module map + config authority.
- [`docs/tracking/README.md`](docs/tracking/README.md) — how the tracking log works.
- [`docs/tracking/context.md`](docs/tracking/context.md) — project context pack.
- [`.agents/skills/README.md`](.agents/skills/README.md) — curated skill library.

## Common commands

```bash
make help            # list available targets
make git.dry         # preview pending commits (read-only)
make git             # commit pending tracking rows + push
make track.add ACTION=note SUMMARY="..."
make native.acceptance # strict real-model generation and sanitizer cycles
server/scripts/postgres_test.sh # isolated local PostgreSQL integration/race tests
```

CI pins Flutter 3.38.5 (Dart 3.10.4) and Go 1.26. Native builds use the
recorded llama.cpp submodule, so clone with `--recurse-submodules`.
`verify.contracts` proves API and development-backend contracts; it does not
prove model quality or physical-device performance. Real-model validation uses
`PSY_MODEL_PATH` or the documented local Qwen path. PostgreSQL tests create and
remove their own local Docker container; any explicitly supplied test database
must be disposable.

## License

See [`LICENSE`](LICENSE).
