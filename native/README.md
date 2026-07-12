# native/

> Native C/C++ layer and llama.cpp FFI bindings for Psychosims.

This module owns the thin native shim that sits between the Dart inference
service and llama.cpp. Build inputs are pinned; generated FFI bindings live in
`app/lib/shared/generated/` and are never hand-edited.

## Layout

- `src/` — C/C++ source files.
- `include/` — C headers consumed by `ffigen`.
- `test/` — native unit tests.
- `third_party/` — pinned llama.cpp submodule (not committed as a copy).

See [`docs/code/ARCHITECTURE.md`](../docs/code/ARCHITECTURE.md) and the
Phase 1.1 inference contract in [`docs/planning/ROADMAP.md`](../docs/planning/ROADMAP.md).
