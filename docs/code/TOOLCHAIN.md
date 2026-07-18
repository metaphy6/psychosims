# Toolchain & build matrix

> Pinned toolchains and the cross-platform build matrix for Psychosims.

## Pinned versions

| Tool | Version | Used by | Validation |
|---|---|---|---|
| Flutter / Dart | 3.22.x / 3.4.x | `app/`, `packages/`, `config/`, `tools/` | Linux desktop + x86 Android emulator (Phase 1) |
| Go | 1.26.x | `server/` | Linux desktop + CI |
| clang / CMake | system latest stable | `native/` | Linux desktop + CI |
| Android NDK | 26.x | `native/` Android build | x86 Android emulator (Phase 1) |
| ffigen | 12.x | Dart FFI bindings | Linux desktop + CI |

## Build matrix

| Target | Phase validated | Notes |
|---|---|---|
| Linux desktop | Phase 1 | Primary dev target |
| x86 Android emulator | Phase 1 | Packaging + CI baseline |
| arm64 Android device | Phase 1.6 | Device-viability gate |
| macOS desktop | deferred | Build only in CI |
| Windows desktop | deferred | Build only in CI |
| iOS | deferred | Requires Apple hardware |

## Reproducibility

- Dependency lockfiles are committed (`pubspec.lock` for Dart when stable,
  `go.sum` for Go, `CMakeLists.txt` for native).
- Build inputs (toolchain versions, llama.cpp commit, GGUF quantization) are
  recorded in this file and in [`ARCHITECTURE.md`](ARCHITECTURE.md).
- The bootstrap script installs pinned SDKs where possible and prints the
  expected versions.
