# Native pinned build inputs

This file records the exact build inputs for the Psychosims native inference
module so that behaviour is reproducible across machines and CI.

## llama.cpp

| Input | Value | Rationale |
|---|---|---|
| Repository | `https://github.com/ggerganov/llama.cpp.git` | Upstream source of truth for GGUF inference. |
| Pinned commit | `311d4211bf1611ff7ca6b67035a4a07c79766efc` | Gitlink committed in this repository; includes `llama_decode`, `llama_token_to_piece`, `llama_chat_apply_template`, KV-cache management, and sampler APIs used by Phase 1.1. |
| Submodule path | `native/third_party/llama.cpp` | Large dependency; vendored as a submodule per the 0.1 large-binary policy. |

### Pinned patches

The submodule is patched at build time by [`scripts/native_build.sh`](../scripts/native_build.sh),
which applies every `native/patches/*.patch` idempotently. A reverse-apply check
proves that an existing patch is already present; an incompatible patch fails
the build. Missing submodules fail with initialization instructions. This keeps
arm64 reproducibility from depending on an unrecorded working-tree edit.

| Patch | Purpose |
|---|---|
| `0001-sgemm-arm-fp16-scalar-fallback.patch` | Adds a scalar fallback for `load(const ggml_fp16_t*)` in `ggml-cpu/llamafile/sgemm.cpp` when the target ARM core lacks `__ARM_FEATURE_FP16_VECTOR_ARITHMETIC`, so the `arm64-v8a` device build compiles on cores without FP16 vector loads. |

## Quantization + download sources

| Tier | Model | Quantization | Download URL | Rationale |
|---|---|---|---|---|
| Tier A primary | Qwen2.5 1.5B Instruct | `Q4_K_M` | `https://huggingface.co/Qwen/Qwen2.5-1.5B-Instruct-GGUF/resolve/main/qwen2.5-1.5b-instruct-q4_k_m.gguf` | Best quality/size trade-off for the 1.5B parameter class; `Q4_K_M` preserves enough weights accuracy for acting quality while keeping the file under ~1 GB and KV-cache RAM within the 4 GB device floor. |
| Tier A comparator | Phi-3.5-mini Instruct | `Q4_K_M` | `https://huggingface.co/bartowski/Phi-3.5-mini-instruct-GGUF/resolve/main/Phi-3.5-mini-instruct-Q4_K_M.gguf` | MIT-licensed comparator for the Phase 1.6 acting-quality gate; comparable size to the Tier A primary. |
| Tier B fallback | SmolLM2 1.7B Instruct | `Q4_K_M` | `https://huggingface.co/HuggingFaceTB/SmolLM2-1.7B-Instruct-GGUF/resolve/main/smollm2-1.7b-instruct-q4_k_m.gguf` | Apache-2.0 fallback for 4 GB-class devices; the 1.7B size at Q4 keeps peak RAM within the DEVICE-SPEC floor. |

> **Checksums.** SHA-256 hashes must be computed after the first verified
> download and recorded in `config/lib/src/loader.dart` under `modelChecksums`.
> Model download and loading must enforce the configured checksum; an unpinned
> model is not a verified application model.

## Targets

- Linux desktop (`x86_64`) — primary dev target.
- Android emulator (`x86_64`) — CI / local emulator target.
- Android device (`arm64-v8a`) — declared in the Gradle build; physical-device validation is gated on human sign-off per Phase 1.6.

## Build requirements

- CMake 3.10+
- C++17 compiler (clang or g++)
- Android NDK r25c+ (for Android targets)
- ninja (recommended)

See [`docs/code/BUILD.md`](../docs/code/BUILD.md) for the full build command.

## Local validation

`scripts/native_build.sh` configures `native/build/current/` and writes the app's
shared library to `native/build/`. It preserves the legacy CMake cache; if the
current cache refers to a different checkout it preserves that directory with
a `.relocated.<timestamp>.<pid>` suffix before configuring fresh. Set
`PSY_NATIVE_BUILD_DIR` for a separate build and `CMAKE_BUILD_PARALLEL_LEVEL` for
the compile worker limit (default 4).

- `scripts/native_test.sh` requires real GGUF weights and checks backend identity,
  tokenization, template rendering, generated output/statistics and identical
  greedy answers across repeated prompts and KV reset. Set `PSY_MODEL_PATH` to
  test another local model; otherwise the Tier A primary is used.
- `scripts/native_sanitizer_test.sh` instruments the wrapper and llama.cpp with
  AddressSanitizer, LeakSanitizer and UndefinedBehaviorSanitizer, exercises three
  load/generate/unload cycles and active cross-thread cancel/regenerate/unload.
- Both scripts accept `--contracts-only` for an explicitly limited no-weights
  check. That checks errors and development backend contracts and does not
  constitute real-model acceptance. CTest separates `native_contracts` from
  `native_real_smoke`. Assertions remain enabled in release test executables.

The public C ABI is unchanged. Load parameters now default to
`"backend":"llama.cpp"`; a missing or corrupt real model returns `NULL` and
never falls back. Tests can explicitly set `"backend":"stub"`. Model metadata
reports `backend` as `llama.cpp` or `stub`. `use_mmap` maps to the pinned
llama.cpp `load_mode` enum.

Generation returns `-2` for context overflow, using the loaded model's actual
context size. Rejection leaves the prompt and KV cache unchanged; the Dart
wrapper reports `InferenceErrorKind.contextOverflow`. An optional Dart `nCtx`
argument can impose a tighter cap but cannot enlarge the loaded context.
