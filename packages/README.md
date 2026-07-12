# packages/

> Cross-cutting Dart packages shared by `app/`, `tools/`, and any Dart server
> components.

These packages hold the canonical schemas and shared models so the client and
tools consume exactly one definition of the manifest, receipt, and structured
delta formats.

## Layout

- `psychemas/` — shared schema package (manifest, receipt, structured deltas).
- `psycore/` — pure deterministic core package (used by `app/lib/core/` and
  `tools/` bots/sandboxes).

Code generation output (FFI bindings, serialization) lands under
`lib/src/generated/` and is never hand-edited.
