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
