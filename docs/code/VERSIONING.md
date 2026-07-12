# Versioning registry

Psychosims pins two versioned contracts from day one:

1. **`ruleset_version`** — the deterministic simulation/economy rules used to
   resolve a session and validate a receipt.
2. **`manifest_schema_version`** — the JSON schema for a `PatientManifest` and
   related content payloads.

Both live in a single registry so a receipt can state exactly which rule set and
schema it was produced under, and the server can validate against that same pair.

## Registry location

[`config/ruleset_registry.yaml`](../../config/ruleset_registry.yaml) is the
single source of truth. It is checked into git and changes require a PR that
updates golden fixtures and tests.

## Version scheme

- Format: `major.minor.patch` (SemVer-ish).
- `major` — breaking rule or schema change; old clients cannot validate against it.
- `minor` — additive, backward-compatible change (new optional fields, new actions).
- `patch` — clarification/bugfix with no serialized-output change.

## Current baseline

```yaml
ruleset_version: 0.1.0
manifest_schema_version: 0.1.0
supported_ranges:
  client_min: 0.1.0
  client_max: 0.1.0
```

## Binding rules

- Every receipt carries `ruleset_version` and `manifest_schema_version`.
- The server rejects receipts whose versions are outside `supported_ranges`.
- The client pins the versions it was built with; it must not silently upgrade.
- A ruleset sunset is gated by a feature flag from the config authority.

## Golden fixtures

Any change that alters a serialized outcome must flip a golden fixture in
`test_fixtures/` or a determinism test in `packages/psycore/`. If tests stay
green but production output changed, that is a regression in coverage, not a
safe change.

## Unknown-field policy

Newer clients against older servers must ignore unknown fields (`additionalProperties: false`
for authoritative schemas, but unknown fields are dropped, not rejected, on
client parse). Older clients against newer servers stay within `supported_ranges`.
See [SERIALIZATION.md](SERIALIZATION.md) for wire-compatibility rules.
