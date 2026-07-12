# config/

> The single centralized configuration authority for Psychosims.

All shared configuration lives here: one typed schema, environment overlays, and
a loader that validates once at startup and injects an immutable `Config` into
every module.

## Layout

- `lib/` — Dart config schema, loader, and validation.
- `schemas/` — serialized base schema and overlay definitions.
- `test/` — loader/validator unit tests.

No module outside `config/` reads raw environment variables. Secrets are
referenced by name only; values live in the runtime environment.

See [`docs/design/DESIGN-centralized-configuration.md`](../docs/design/DESIGN-centralized-configuration.md).
