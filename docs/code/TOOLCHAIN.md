# Toolchain & build matrix

> Pinned toolchains and the cross-platform build matrix for Psychosims.

## Pinned versions

| Tool | Version | Used by | Validation |
|---|---|---|---|
| Flutter / Dart | 3.38.5 / 3.10.4 | `app/`, `packages/`, `config/`, `tools/` | Current Linux tests; CI pins Flutter; device acceptance remains pending |
| Go | 1.26.x | `server/` | Linux desktop + CI |
| clang / CMake | system latest stable | `native/` | Linux desktop + CI |
| Android NDK | `flutter.ndkVersion` in Gradle | `native/` Android build | Exact SDK/NDK and emulator acceptance remain to be verified |
| ffigen | `^10.0.0` in `app/pubspec.yaml` | Dart FFI bindings | Generator lock/drift verification remains open |

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

- `server/go.sum` and the native gitlink/patch set are committed. Dart
  `pubspec.lock` files are currently ignored; committing and checking their
  reviewed dependency resolutions remains a supply-chain follow-up.
- Build inputs (toolchain versions, llama.cpp commit, GGUF quantization) are
  recorded in this file and in [`ARCHITECTURE.md`](ARCHITECTURE.md).
- The bootstrap script resolves project dependencies, installs the pinned
  vulnerability scanner in `.tools/bin`, and prints available SDK versions.
  It does not install operating-system packages or SDKs globally.
