# Phase 1 — current local acceptance evidence

**Assessment date:** 2026-09-10. **Status:** local measurements in progress; Phase 1 device acceptance remains pending. The July report below is historical and its blanket “exit gates cleared” claim is superseded by this status.

The expanded harness measures the current real native backend with the three SHA-256-pinned Q4_K_M artifacts configured by `psyconfig`: Qwen2.5-1.5B, Phi-3.5-mini, and SmolLM2-1.7B. Missing, misnamed, or checksum-mismatched artifacts fail acceptance; the explicit contracts profile is the separate path that does not require these weights.

The predeclared targets are taken from [PERFORMANCE_BUDGETS](../code/PERFORMANCE_BUDGETS.md): model load to first usable token ≤8 seconds, first usable token p95 ≤2.5 seconds, and generation throughput ≥8 tokens/second. The benchmark records target misses without relabeling them as passes. Its debug Linux host, shared CPU load, and filesystem cache differ from the specified release/profile build on a physical floor device; these measurements cannot complete C-1. The performance document's 4 GB Android reference also differs from the 6 GB primary floor in [DEVICE-SPEC](../specs/DEVICE-SPEC.md); both remain unvalidated targets.

**Method fixed before the run:** five fresh model contexts per artifact for load timing, then 20 independent empty-KV generations each immediately followed by the identical warm-KV request. All use the configured context, batch, thread count, repetition penalty, output reserve and model-specific stop/KV settings; seed42 and greedy decoding define same-build reproducibility. Report median, nearest-rank p95, maximum and minimum, with all observations retained. Fresh-context timing does not claim a cold disk cache. RSS is the test process high-water mark, not isolated model RAM or a mobile measurement.

**Prompt fixture:** the production `PatientRoleplayFrame` and real tokenizer/chat template, every implemented typed simulation-state field, nonempty medication with maximum dosage/tolerance/dependency, all enumerated lasting complications, 999999 prior sessions, mandatory clues, and the manifest's four conversation turns. Normal turns contain 15 repeated sentences each; a second stress fixture uses 300 each. Assertions enforce the configured input cap and output reserve, intact clues, removal of the oldest overloaded turn, and rejection when immutable Tier1 plus reserve cannot fit. The assembler currently subtracts the reserve inside `maxInputTokens` as well, so its effective input allowance is more conservative than the configuration comment. This is not proof of the unimplemented full nine-axis manifest schema, nor a globally maximal prose/digest bound.

**Dialogue evidence:** raw first-person voice, frame leaks, listicles, advice, brevity, clue compliance and refusal markers are reported separately. The three mature probes execute the production `ResponsePlanner` with real generation retries, then its deterministic fallback. Delivered dialogue must be nonempty, non-refusal, free of frame/control markers. A clue-omitting raw model can therefore fail the raw rubric while the product returns its safe fixed line; these outcomes must not be conflated. Synthetic dialogue is not written into the structured benchmark result: only counts, measurements and response hashes are retained.

**Cache regression repaired during measurement:** the expanded Phi fixture (1209 input tokens, seed42, batch512, four threads) exposed a warm-cache mismatch: two fresh evaluations produced the same 789-character/226-token response, while re-evaluating the last prompt KV row in a single-token batch produced a different 325-character/97-token response. Caching the exact prompt-end logits and retaining every matching prompt KV row restored byte identity across both cold runs and the warm run. The warm path now evaluates zero prompt tokens; `prompt_tokens` still reports total input size, with additive `evaluated_prompt_tokens` and `reused_prompt_tokens` counters recording work. A shorter prompt that is a strict prefix of the previous input is fully re-evaluated; separate regressions cover partial prefixes, reset, seeded stochastic sampling, and cancellation. These are correctness checks, not minimum-device performance acceptance.

**Measurement review repairs before the matrix:** `generated_tokens` now counts sampled non-EOG model tokens, including empty pieces and tokens that collectively form one UTF-8 character. Complete-text callbacks and final partial-byte flushes do not determine token throughput. A three-token euro-sign fixture produces one complete callback and reports three samples; a two-token limit preserves an incomplete flush while reporting two. The harness rejects missing, fractional, nonfinite or nonpositive token/time measurements.

`repetition_penalty` is now applied by the pinned llama.cpp penalties sampler before greedy or stochastic selection. The history contains the last 64 prompt/generated tokens and starts fresh for each generation; prompt priming only touches the penalties sampler. The accepted factor is finite in `[0, 2]`, with the existing config value zero normalized to llama.cpp's neutral factor one. Synthetic positive/negative logits prove penalty application and bounded history; real-model regressions retain exact output bytes across warm/cold cache reuse, reset and cancellation with factor 1.2. These repairs require the pending matrix to run against the corrected build; this scoped repair does not supply new benchmark distributions.

**Implementation and validation plan:**

- [x] Implement strict artifact, sample-count, percentile and context-budget checks; prove invalid/missing inputs fail.
- [x] Replace the two single-shot measurement tests with a three-artifact production-path matrix; retain the older independent acting/injection checks.
- [ ] Run the matrix, record measured distributions and target misses, then run scoped analyzer and review.
- [ ] Physical device release/profile, sustained thermal/battery/OS-memory-pressure and frame-time tests.
- [ ] Alternate quantizations, model-download acceptance study and current per-ABI package sizes.

Harness: [model_acceptance.dart](../../app/tools/model_acceptance.dart). Real matrix: [poc_gate_measurements_test.dart](../../app/test/poc_gate_measurements_test.dart). Model-free contract regressions: [model_acceptance_harness_test.dart](../../app/test/model_acceptance_harness_test.dart).

---

# Historical July 2026 report (not current acceptance)

# Phase 1 (PoC) — Exit Report (canonical)

**Date**: 2026-07-13
**Scope**: `phase-1` — Minimal Cross-Platform Runtime PoC.
**Status**: ✅ **Exit gates cleared. Proceed to Phase 2.**

> This is the single authoritative Phase 1 report. It supersedes and replaces the
> earlier overlapping drafts (`PoC_EXIT_REPORT.md`, `phase-1-independent-assessment.md`,
> `2026-07-13-phase-1-poc-audit.md`, `2026-07-13-phase-1-verification.md`), which
> were consolidated here to remove report sprawl.

---

## Executive summary

The PoC works as an end-to-end vertical slice **and** the product bet now holds:
a quantized local model loads and generates off the UI isolate behind a
deterministic core, the prompt assembler enforces a token budget with the
model's real tokenizer + chat template, and — after adding a proper roleplay
frame — the model **acts in character** instead of analysing the case file.

The earlier concern (both candidates emitted clinical analysis, and a keyword
rubric falsely green-lit Phi) was root-caused and fixed: the model was never
given an instruction to act. With a versioned roleplay system prompt + few-shot
exemplars, **both Qwen2.5-1.5B and Phi-3.5-mini pass an acting rubric that
judges acting** (first-person voice, no frame-token leak, no listicle, no
clinical advice), under greedy decode so the sample is reproducible.

**Verdict: 🟢 CONTINUE to Phase 2.** Remaining items are physical-device
measurements gated on human sign-off, not blockers.

---

## Sub-phase completion

| Sub-phase | Done | Status |
|---|---|---|
| 1.1 Flutter + llama.cpp FFI | 22/22 | ✅ (Android verified; Linux desktop runtime verified by tests, `flutter build linux` bundle blocked by missing `clang++`/`ninja`/`pkg-config`) |
| 1.2 Manifest schema + loader | 15/15 | ✅ |
| 1.3 Prompt assembler | 14/14 | ✅ (now emits the versioned roleplay frame) |
| 1.4 Simulation core split | 11/11 | ✅ |
| 1.5 End-to-end session loop | 12/12 | ✅ |
| 1.6 Exit-gate measurement | 15/18 | 🟢 core gates cleared; 3 physical-device items pending sign-off |

---

## The acting-quality fix (the one that mattered)

**Root cause.** The model's system frame was a machine-readable key-value dump
(`ruleset_version=…`, `case_id=…`, `clue_tokens=…`, `HISTORY_DIGEST turn=1
agitation=44 …`) plus a patient *description* — with **no instruction to act**.
An instruction-tuned model handed structured fields analyses them, so both
candidates returned clinical listicles/meta-analysis, and Phi even echoed the
frame tokens (`BASED_ANALYSIS`, `HISTORY_DIGEST`).

**Fix (escalation-ladder rung 0).** Added a versioned `RoleplayFrame`
([`packages/psycore/lib/src/roleplay_frame.dart`](../../packages/psycore/lib/src/roleplay_frame.dart)):

- A **roleplay system instruction** prepended to Tier-1: *voice the patient in
  first person, never analyse/list/advise, never repeat the metadata, weave the
  clue token in naturally.*
- **Few-shot exemplars** (in-character user/patient turns) so a small model has
  a concrete template of *how the patient speaks*.
- Sim-state axes rendered as **natural-language feeling words** (no raw numbers),
  and the turn-0 history digest dropped, so nothing reads as a data table.

The pin block (`ruleset_version=` etc.) is retained for reproducibility and
injection isolation; the frame is injected via config so the pure core stays
testable at tiny budgets. GBNF grammar-constrained decoding was **not needed** —
rung 0 was sufficient.

### Firsthand output (greedy decode, this build)

| Model | Before (naive frame) | After (roleplay frame) |
|---|---|---|
| Qwen2.5-1.5B | *"Agitation: 44 (Highly Agitated)… 3. Consider providing sedation… 4. Consult with a healthcare provider…"* (listicle) | *"That's how I feel. I'm trying my best to stay focused and calm, but it's hard when my mind keeps going in a million different directions."* |
| Phi-3.5-mini | *"BASED_ANALYSIS turn=1 … In the generated HISTORY_DIGEST, the patient's current psychological state is quantified…"* (leaks frame) | *"I guess that's true. I'm just worried about getting it right, you know? And this ferve-axine thing, it's all over my head."* |

### Rubric (now judges acting)

Pass requires **all** of: first-person voice · **no frame-token leak** · no
numbered listicle · no clinical advice. Clue-token survival and brevity are
reported signals. Measured under greedy decode + fixed seed for reproducibility.

| Model | Score | Honours clue | Verdict |
|---|---|---|---|
| Qwen2.5-1.5B `Q4_K_M` | 5/5 | no (this turn) | ✅ acts |
| Phi-3.5-mini `Q4_K_M` | 5/5 | yes | ✅ acts |

Harness + rubric: [`app/test/poc_gate_exit_report_test.dart`](../../app/test/poc_gate_exit_report_test.dart).

---

## Other measured gates

| Gate | Result |
|---|---|
| Prompt token budget (C-7) | 77 input tokens vs 1792 usable (2048 `n_ctx` − 256 reserve). Ample headroom, roleplay frame included. |
| Warm/cold first-token latency | cold ~541 ms, warm ~0 ms (prefix-cache reuse). |
| Greedy-decode reproducibility | byte-identical across two runs on the same build; cross-arch divergence expected (float matmul) and documented. |
| Refusal / safety-boilerplate (Qwen) | 3/3 on mature probes — a real risk for dark cases; the sim core owning mechanics is the safety net. |
| Prompt-injection / template isolation | hostile manifest/history string stays data; T1 frame and clue tokens intact; output does not leak the frame. |
| Native memory-safety | ASan/LSan gate (full `-fsanitize=address,leak` build, `LD_PRELOAD` libasan, `detect_leaks=1`) passes over load→generate→cancel→unload cycles. |

---

## Platform verification

- **Android**: multi-arch APK (`arm64-v8a`, `armeabi-v7a`, `x86_64`, ~62 MB)
  builds with native libs bundled and launches on the x86 emulator (~887 ms).
- **Linux desktop**: runtime proven by `flutter test` loading
  `native/build/libpsychosims_native.so`; the `flutter build linux` *bundle* is
  blocked in this environment by missing `clang++`/`ninja`/`pkg-config` (system
  packages, not a code defect).
- **Vendored llama.cpp patch**: the ARM FP16 scalar-fallback edit is now a
  tracked patch ([`native/patches/0001-sgemm-arm-fp16-scalar-fallback.patch`](../../native/patches/0001-sgemm-arm-fp16-scalar-fallback.patch))
  applied idempotently by [`scripts/native_build.sh`](../../scripts/native_build.sh),
  so arm64 reproducibility no longer depends on an unrecorded working-tree edit.

---

## Remaining (pending physical hardware — not blockers)

| Item | Why pending |
|---|---|
| Device viability (peak RAM, tokens/sec, thermal, sustained throughput, battery) | Needs a real arm64 device; emulator/desktop numbers aren't representative. Desktop peak RSS during a Qwen turn was ~3.75 GB (incl. test harness) against a 4 GB floor — a yellow flag to confirm on hardware. |
| Download-acceptance path instrumentation | Fetch UI exists; acceptance-rate/metered-connection behaviour not user-tested. |
| Quantization tradeoff | Only `Q4_K_M` weights are on disk; alternate quants not benchmarked. |

These are the three open 1.6 bullets, all explicitly gated on human sign-off.

---

## Decision gate

- Acting quality: **green for both models** under the roleplay frame.
- Recommendation: proceed to Phase 2. Either candidate is viable; Phi-3.5-mini
  weaves clue tokens more readily, Qwen is smaller and cheaper on RAM — the final
  Tier A pick can ride the pending device-viability numbers.
- Condition: capture physical-device viability before significant Phase 2 spend.

**🟢 Phase 1 exit gates cleared.**
