# app/

> Flutter cross-platform client for Psychosims.

This module owns the game loop, UI, local persistence, and the glue to on-device
inference. It consumes the shared `packages/` for schemas and `config/` for all
configuration.

## Layout

- `lib/core/` — pure deterministic simulation rules; no I/O, no model calls.
- `lib/features/` — one directory per domain (`session/`, `cards/`, `clinic/`,
  `progression/`, `recovery/`, `content/`, `presentation/`).
- `lib/shared/` — reusable utilities, models, and services (inference service,
  config access, networking, logging).
- `test/` — Dart unit/widget tests.

## Architecture conventions

- **State + DI**: GetX (see [ADR-0005](../docs/design/ADR-0005-getx-state-management.md)).
  - `lib/shared/injection.dart` wires the config authority and shared services.
- **Navigation**: typed named routes using `Get.toNamed`; routes defined in
  `lib/app/routes.dart` when the first flow is built.
- **Persistence**: a single offline-first storage seam (`lib/shared/storage.dart`)
  will manage the durable receipt queue, cached profile, and settings with
  explicit schema migrations.
- **Concurrency**: inference (llama.cpp/FFI), serialization, and network fetches
  run off the UI isolate so the frame loop never stalls.
- **Lifecycle**: durable checkpoints on state change; the app relaunches into a
  consistent state after backgrounding, OS kill, or crash.
- **Memory pressure**: the ~1.8 GB model stays resident; compact manifests swap
  and presentation assets load/evict against a budget.

## Feature-module skeleton

```
lib/features/<domain>/
  controller.dart      # GetXController + state
  binding.dart         # GetPage binding
  screen.dart          # UI
  service.dart         # Domain service (optional)
  widgets/             # Private widgets
  tests/               # Widget + unit tests
```

## Build

```bash
flutter pub get
flutter build linux
flutter build apk
```

See [`docs/code/ARCHITECTURE.md`](../docs/code/ARCHITECTURE.md) for module
boundaries.
