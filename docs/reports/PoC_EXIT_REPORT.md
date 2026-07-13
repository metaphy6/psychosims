# PoC Exit Report — Phase 1 Minimal Cross-Platform Runtime

**Date:** 2026-07-13
**Scope:** Phase 1 — Minimal Cross-Platform Runtime (PoC)
**Status:** Engineering complete; real backend + weights verified on Linux desktop; Android build blocked by JDK/Gradle toolchain; acting quality requires a scored rubric pass before Phase 2.

## Executive decision

**Decision: revisit before Phase 2 spend.**

The Phase 1 *engineering* deliverables are implemented and verified against the
real `llama.cpp` backend on Linux desktop: the native library builds and links,
loads real GGUF weights, tokenizes with the model's real tokenizer, applies the
GGUF chat template, streams detokenized output, and respects the context-window
guard. All automated gates pass on this machine (`make verify` green) and the
headless harness runs a deterministic turn end-to-end with both the Tier A
primary (Qwen2.5-1.5B) and the comparator (Phi-3.5-mini).

However, the **falsifiable exit gates that justify Phase 2 spend are still
partially open**:

1. **Android target is unverified.** An x86_64 Android emulator is available and
   launches, but the APK build fails because the installed JDK is OpenJDK 25,
   which Gradle 8.14 / Android Gradle Plugin 7.3.0 do not support.
2. **Acting quality is un-scored.** The model emits text and follows the
   structured prompt, but a written rubric (in-character, clue-token survival,
   style-archetype fidelity) has not been applied; the sample output shows the
   model drifting into out-of-character meta-analysis rather than patient
   dialogue.
3. **Device viability on mobile is unmeasured.** Linux desktop tokens/sec and
   peak-RAM numbers are in hand, but Android emulator/device numbers (thermal
   sustained throughput, memory pressure, battery) are blocked by the APK build
   failure.

Per §1 and ROADMAP 1.6, *"it produced text" is not a pass*. Phase 2 spend
remains gated on an Android build + an acting-quality rubric pass.

## What is implemented and verified

| Area | Implementation | Evidence |
|---|---|---|
| Real `llama.cpp` build | `native/CMakeLists.txt` submodules `third_party/llama.cpp`; `scripts/native_build.sh` produces `libpsychosims_native.so` on Linux x86_64. | `scripts/native_build.sh` exits 0; native smoke test loads Qwen and generates text. |
| Android native wiring | `app/android/app/build.gradle` declares `externalNativeBuild` with CMake, ABI filters `arm64-v8a`/`x86_64`, and C++17 flags. | Gradle config parses; build fails at Java/Gradle compatibility, not at native wiring. |
| Real GGUF weights | Tier A primary (Qwen2.5 1.5B), comparator (Phi-3.5-mini), and Tier B fallback (SmolLM2 1.7B) Q4_K_M weights are present under `assets/models/` and checksum-verified against `config/lib/src/loader.dart`. | `sha256sum` matches the three pinned hashes. |
| FFI inference seam | `app/lib/shared/inference_service.dart` implements load / tokenize / chat-template / generate / cancel / unload behind a narrow seam. | `app/test/inference_service_test.dart` (11 tests pass) |
| Worker-isolate generation | Generation runs on a dedicated worker isolate; streamed tokens cross back over a port. | `inference_service_test.dart` end-to-end tests pass |
| Single-flight guard | A second concurrent `generate()` call is rejected; sequential retries from `ResponsePlanner` are safe. | `rejects concurrent generation requests` test passes |
| UTF-8-safe streaming | `_Utf8Accumulator` buffers raw token bytes and emits only complete codepoints. | `buffers partial UTF-8 codepoints across tokens` test passes |
| Context-window guard | `guardContextWindow()` rejects prompt + maxOutput > `n_ctx` before decoding. | `guards context window` test passes |
| Config-driven parameters | `n_ctx`, `n_batch`, `n_threads`, `kv_cache_type`, seed, temperature, top-p/k, repetition penalty, stop tokens, grammar path all resolve through `Config`. | Config tests + inference metadata tests pass |
| Deterministic decode | Greedy / temperature-0 path selectable via config; fixed seed exposed. | `runs a deterministic turn end-to-end` test passes |
| Grammar seam | `grammar` parameter wired through generation params (unused by baseline). | Parameter reaches native metadata |
| C++ logging shim | `native/src/psychosims_native.cpp` emits structured, correlation-id stamped log lines. | Shell logs in tests show stamped events |
| Error taxonomy | `InferenceErrorKind` covers missing/corrupt/unsupported-ABI model, load failure, OOM, cancellation, context overflow, generation error. | Mapped to localized UI messages |
| Session persistence | `SessionPersistenceService` checkpoints sim state, conversation window, delta log, and correlation id atomically. | `app/test/session_persistence_test.dart` (4 tests pass) |
| Model-fetch UI | `ModelFetchScreen` + `ModelFetchController` expose progress, pause/resume, metered posture, and localized error states. | Wired into routes; lint/tests green |
| Correlation id | Single `correlation_id` spans Dart client and C++ FFI logs per turn. | Log output in tests shows shared id |
| No raw transcript rule | Checkpoint stores only structured state, not raw model I/O transcripts. | `SessionCheckpoint` schema + persistence tests |
| Native memory-safety gate | ASan/LSan build of `native/src/psychosims_native.cpp` + `llama.cpp`; 3× load→generate→unload cycles pass with leak detection enabled. | `native/build-san/` build + `native/test/native_sanitizer_cycles.cpp` exit 0; no sanitizer errors reported. |

## What is blocked by this environment

| Gate | Why blocked | Unblock criteria |
|---|---|---|
| Android APK build | Installed JDK is OpenJDK 25; Gradle 8.14 / AGP 7.3.0 do not support Java 25 (`Unsupported class file major version 69`). | Install OpenJDK 21 (or 17), align Gradle + AGP versions, then rebuild. |
| Android emulator run | Emulator launches (`emulator-5554`), but the app cannot be installed/built until the APK build is fixed. | Fix JDK/Gradle, then `flutter build apk --target-platform android-x64` and `flutter run -d emulator-5554`. |
| Acting-quality measurement | The model emits text, but no written rubric has been applied to the sample outputs; initial samples show out-of-character meta-analysis. | Define rubric, run N samples per model under fixed seed + greedy decode, score, and escalate if red. |
| Device-viability measurement (Android) | Blocked by APK build failure. No mobile tokens/sec, peak RAM, thermal, or battery data. | Fix Android build, run headless harness on emulator, then on a physical floor device (human-gated). |
| Prompt batched decode (`n_batch`) benchmark | Real backend processes prompts, but a controlled prompt-ingestion latency comparison (with/without prefix KV-cache reuse) has not been run. | Add instrumentation to surface prompt-eval time and run the comparison on Linux + Android. |

## Measured numbers (real backend, Linux desktop)

Hardware: x86_64 desktop, CPU inference, `n_threads=4`, `n_ctx=2048`,
`n_batch=512`, KV cache `f16`, greedy / temperature-0 decode, fixed seed 42.

### Build / test gates

- `make verify` cold: **pass** (build + lint + format + tests + doctor).
- Dart tests: **54 passed** across config / psychemas / psycore / app.
- Server tests: **3 passed**.
- Native smoke test: **passed** with real Qwen2.5-1.5B backend.
- Native sanitizer cycles: **passed** (3× load→generate→unload under ASan/LSan).

### Prompt token budget (C-7)

Measured against the PoC sample manifest with an empty conversation window:

| Model | Advertised `n_ctx_train` | Shipped `n_ctx` | Input budget | Measured prompt tokens | Output reserve | Prompt + reserve |
|---|---|---|---|---|---|---|
| Qwen2.5-1.5B-Q4_K_M | 32 768 | 2048 | 1536 | **255** | 256 | 511 |
| Phi-3.5-mini-Q4_K_M | 128 000 | 2048 | 1536 | **225** | 256 | 481 |

Both prompts fit inside the configured `maxInputTokens=1536` and the total
prompt + generation reserve is well under the shipped `n_ctx=2048`. See
[`docs/specs/PROMPT-TOKEN-BUDGET.md`](../specs/PROMPT-TOKEN-BUDGET.md) for the
updated measured section.

### Linux desktop device viability (preliminary)

| Model | File size | Load time | KV cache (f16, n_ctx=2048) | Compute buffer | Generated tokens | Generation time | Tokens/sec |
|---|---|---|---|---|---|---|---|
| Qwen2.5-1.5B-Q4_K_M | ~1.06 GB | ~1.1 s | 56 MiB | 302.75 MiB | 247 | ~9.9 s | ~25 t/s |
| Phi-3.5-mini-Q4_K_M | ~2.28 GB | ~2.7 s | 768 MiB | 88.64 MiB | 256 | ~18.4 s | ~14 t/s |

> **Caveat:** these are single-shot desktop CPU numbers, not a median/p95
distribution and not a mobile measurement. They prove the control path and
rough feasibility on desktop; the mobile floor and sustained-throughput gates
remain open.

### Acting-quality sample (unedited, fixed seed)

Both models produced structured output containing the expected turn/state
markers, but neither stayed consistently in the patient voice. Representative
Qwen excerpt:

> "...the patient is experiencing significant restlessness or irritability. The
> resistance score of 20 indicates some degree of opposition..."

This reads as third-party analysis, not first-person patient dialogue. A
patient-voice rubric would likely score this red. The sim-core fallback
(bounded regeneration → templated line) is the safety net, but the baseline
prompt/template is not yet sufficient for a green acting-quality gate.

## Recommended next steps

1. **Unblock the Android build** — install OpenJDK 21 (or 17), update Gradle
   wrapper and Android Gradle Plugin to a compatible combination, and confirm
   `flutter build apk --target-platform android-x64` succeeds.
2. **Run Android gates** — install/run the APK on `emulator-5554`, then measure
   load time, tokens/sec, and peak RAM on the emulator; follow with a physical
   `arm64-v8a` floor-device pass (human-gated).
3. **Close the acting-quality gate** — write the rubric, run N fixed-seed
   samples per model, score in-character voice + clue-token survival + style
   archetype; escalate along [DECISION 0018](../project/DECISION_LOG.md) if red.
4. **Complete the device-viability artifact** — collect median/p95 desktop and
   mobile numbers, measure prompt-prefix KV-cache reuse benefit, and record the
   final go/revisit decision here before any Phase 2 spend.
