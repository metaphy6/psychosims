# Generated code boundary

> Where generated code lands and the rule that it is never hand-edited.

## Generated outputs

| Source | Generator | Output | Commit? |
|---|---|---|---|
| `native/include/*.h` | `ffigen` | `app/lib/shared/generated/` | yes |
| `packages/psychemas/lib/src/*.dart` | `freezed` / `json_serializable` | `*.freezed.dart`, `*.g.dart` | yes |
| `packages/` schemas (future) | JSON Schema / OpenAPI | `server/src/schemas/*.py` | yes |

## Rule

**Generated files are never hand-edited.** If a generated file needs to change,
the source or the generator configuration changes, and the file is regenerated.
Code review treats generated files as build artifacts: scan them for unexpected
content, but do not edit them in place.

## Regeneration

```bash
# Dart freezed/json_serializable
(cd packages/psychemas && dart run build_runner build --delete-conflicting-outputs)

# FFI bindings (future, when ffigen config is added)
(cd app && dart run ffigen --config ffigen.yaml)
```
