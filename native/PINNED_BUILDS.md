# Native pinned build inputs

This file records the exact build inputs for the Psychosims native inference
module so that behaviour is reproducible across machines and CI.

## llama.cpp

| Input | Value | Rationale |
|---|---|---|
| Repository | `https://github.com/ggerganov/llama.cpp.git` | Upstream source of truth for GGUF inference. |
| Pinned commit | `6b4dc2116` (tag `b9977`) | Recent stable tag at integration time; includes `llama_decode`, `llama_token_to_piece`, `llama_chat_apply_template`, KV-cache management, and sampler APIs used by Phase 1.1. |
| Submodule path | `native/third_party/llama.cpp` | Large dependency; vendored as a submodule per the 0.1 large-binary policy. |

## Quantization + download sources

| Tier | Model | Quantization | Download URL | Rationale |
|---|---|---|---|---|
| Tier A primary | Qwen2.5 1.5B Instruct | `Q4_K_M` | `https://huggingface.co/Qwen/Qwen2.5-1.5B-Instruct-GGUF/resolve/main/qwen2.5-1.5b-instruct-q4_k_m.gguf` | Best quality/size trade-off for the 1.5B parameter class; `Q4_K_M` preserves enough weights accuracy for acting quality while keeping the file under ~1 GB and KV-cache RAM within the 4 GB device floor. |
| Tier A comparator | Phi-3.5-mini Instruct | `Q4_K_M` | `https://huggingface.co/bartowski/Phi-3.5-mini-instruct-GGUF/resolve/main/Phi-3.5-mini-instruct-Q4_K_M.gguf` | MIT-licensed comparator for the Phase 1.6 acting-quality gate; comparable size to the Tier A primary. |
| Tier B fallback | SmolLM2 1.7B Instruct | `Q4_K_M` | `https://huggingface.co/HuggingFaceTB/SmolLM2-1.7B-Instruct-GGUF/resolve/main/smollm2-1.7b-instruct-q4_k_m.gguf` | Apache-2.0 fallback for 4 GB-class devices; the 1.7B size at Q4 keeps peak RAM within the DEVICE-SPEC floor. |

> **Checksums.** SHA-256 hashes must be computed after the first verified
> download and recorded in `config/lib/src/loader.dart` under `modelChecksums`.
> Empty checksums disable verify-before-load until the release manifest pins
> them.

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
