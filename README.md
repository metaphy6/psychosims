# psychosims

> A cross-platform, fictional psychology-practice social-simulation game: an
> on-device AI voices patients, a deterministic core owns every outcome, and a
> small authoritative server makes progression, ownership, and the economy
> trustworthy across players.

## Quickstart

```bash
# install dependencies (edit for your stack)
make doctor          # sanity-check the agent framework wiring
```

## Documentation

- [`AGENTS.md`](AGENTS.md) — rules every AI coding assistant follows in this repo.
- [`STARTER.md`](STARTER.md) — the project blueprint (§1–§24).
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
```

## License

See [`LICENSE`](LICENSE).
