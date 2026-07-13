# 📊 Phase 1 (PoC) audit — is the project worth continuing?

- **Date:** 2026-07-13
- **Scope:** Phase 1 — Minimal Cross-Platform Runtime (PoC)
- **Question asked:** Phase 1 is "supposed to be completed" — run the PoC
  thoroughly and give an honest go / revisit recommendation before expanding
  the roadmap.
- **Method:** Static audit of the codebase + live execution of every build and
  test gate on this machine (Flutter 3.38.5, Dart 3.10.4, CMake 3.28.3, g++
  13.3.0).

---

## TL;DR

**Phase 1 is _not_ complete, and the PoC has _not_ passed its own exit gate.**

The engineering that *does* exist is genuinely high quality — clean module
boundaries, a deterministic core with property tests, a token-budgeted prompt
assembler with injection isolation, a checksum-verified resumable model-fetch,
and a passing Dart/server test suite. That is real, well-disciplined work.

But the **one existential question the PoC exists to answer has not been tested
at all**: *can a small LLM actually run on-device and act convincingly as a
patient?* Every test and the entire "end-to-end loop" run against a **hardcoded
stub** that returns the literal string `deterministic stub response`. No real
`llama.cpp` is linked, no GGUF model is present, and **none of the four
falsifiable exit gates (§1 / 1.6) have been measured.**

The roadmap's own words apply: *"'it produced text' is not a pass."* Here it
does not even produce model text — it produces a canned placeholder.

**Recommendation: CONTINUE the project, but do NOT expand the roadmap into
Phase 2+.** The correct and only sensible next step is to finish sub-phase 1.1
(wire the real `llama.cpp` backend) and execute sub-phase 1.6 (the four
measurement gates) with a real model. Until acting-quality and device-viability
are measured on real weights, expanding scope means building the entire tower on
the single unproven assumption the plan was explicitly designed to de-risk
*first*.

---

## 1. Claimed vs. actual completion

The ROADMAP status snapshot says Phase 1 is `51/93 🟡 in progress`. A live
`make roadmap.status` says **58/93 (≈62%)**. Neither says "complete" — the
premise that Phase 1 is "supposed to be completed" is itself incorrect.

| Sub-phase | Done | Reality |
|---|---|---|
| 1.1 — Flutter app + llama.cpp FFI | **9/22 (40%)** | FFI *seam* built; real inference **not** wired — backend is a stub |
| 1.2 — Manifest schema + loader | 17/17 (100%) | Genuinely complete and tested |
| 1.3 — Prompt assembler | 10/13 (76%) | Pure/tiered/tested; **real tokenizer + chat template unchecked** (uses stub) |
| 1.4 — Sim core vs dialogue split | 11/11 (100%) | Genuinely complete, property-tested |
| 1.5 — End-to-end session loop | 8/12 (66%) | Wires against the stub; off-isolate streaming + crash-recovery unchecked |
| 1.6 — PoC exit-gate measurement | **3/18 (16%)** | Harness exists; **all four falsifiable gates unmeasured** |

The unchecked bullets are not incidental — they are precisely the load-bearing
ones: real mmap/KV-cache lifecycle, off-UI-isolate worker, UTF-8-safe streaming,
runtime context guard, deterministic decode on real weights, the full
generation-parameter set, native memory-safety (ASan) gate, and "confirm build +
verified model load + one streaming inference on Linux + Android emulator."

---

## 2. Gate execution results (run live today)

| Gate | Result | Notes |
|---|---|---|
| `make doctor` | ✅ pass | Framework wiring only — not the product |
| Dart tests (config, psychemas, psycore, app) | ✅ 44 pass | **All exercise the stub backend** |
| Server tests (pytest) | ✅ 3 pass | Health-check stub |
| Native C++ smoke test | ❌ **FAIL (abort/core dump)** | Asserts version `psychosims-native-0.1.0`; stub returns `...-0.1.0-stub` |
| `make verify` (cold) | ❌ **would FAIL** | `native.test` aborts, so the verifier gate is red |

So the "completed" work ships a **genuinely red test gate**: the C++ smoke test
was never updated when the real backend was swapped for a stub. `make verify`
does not pass cold today.

---

## 3. The core finding: the PoC proves nothing about its own thesis

Evidence gathered:

- `native/src/psychosims_native.cpp` is explicitly *"the g++/host-compatible
  stub backend used while the real llama.cpp … placeholder outputs"*. It streams
  a fixed phrase word-by-word and reports version `psychosims-native-0.1.0-stub`.
- `native/third_party/llama.cpp` is a **declared-but-uninitialized submodule**
  (empty directory; `-` prefix in `git submodule status`). The real inference
  engine source is not even checked out.
- **No `.gguf` model exists** anywhere in the tree. `loadModel(...)` in the
  headless harness points at `/tmp/psychosims_poc_model.gguf`, which the stub
  never actually reads.
- `native_build.sh` is a plain `g++ -shared` compile of the stub — no CMake, no
  NDK, no llama.cpp. So "the native library builds and loads" is true only of
  the placeholder.
- `docs/reports/` contains **no PoC exit-report** — the 1.6 deliverable that was
  supposed to record acting quality, token budget, download acceptance, and
  device viability does not exist.

The project's three existential bets — **(a) the model can act, (b) the device
can run it, (c) users accept the ~1–2 GB download** — remain **100% unvalidated**.
These are exactly the three risks §1 says the PoC exists to retire before any
further spend.

---

## 4. What is genuinely good (and de-risks the *engineering*, not the *thesis*)

This is worth stating plainly, because it shapes the recommendation:

- **Deterministic core** (`packages/psycore`) with seeded PRNG, injected clock,
  fixed-point money, and **property-based determinism tests** — the receipt-replay
  foundation is real and tested.
- **Prompt assembler** is pure, tiered, token-budgeted, with an **adversarial
  injection-isolation test** — the hardest correctness contract is in place.
- **Manifest schema/loader** (`packages/psychemas`) enforces schema-version +
  content-checksum + field caps + content-integrity lint, with golden fixtures.
- **Model-fetch service** implements resumable HTTP-range download, checksum
  verify, atomic rename, metered-connection deferral, cancellation — all tested.
- **Config authority, cross-stack logging, metrics, response-planner
  (regeneration → templated fallback), dialogue sanitizer** all exist and pass.

Translation: the *scaffolding* is excellent. The team clearly can execute. What
is missing is the single most important experiment.

---

## 5. Recommendation

**Verdict: worth continuing — conditionally.** The quality of the foundations
justifies continued investment. But **expanding the roadmap (Phase 2+) now would
be a mistake**, because every downstream phase assumes the PoC thesis is proven,
and it is not.

### Do this before any Phase 2 work (in order)

1. **Fix the red gate.** Reconcile the native smoke-test version assertion with
   the stub, or gate it behind a "real backend" flag — `make verify` must pass
   cold. (Cheap; do it first so the tree is honest.)
2. **Finish 1.1 for real.** Initialize the `llama.cpp` submodule, build via CMake
   (not the g++ stub), and wire the real load / tokenize / chat-template /
   generate / cancel path off the UI isolate.
3. **Fetch a real Tier-A GGUF** (Qwen2.5 1.5B `Q4_K_M`) and run the headless
   harness against it on Linux desktop.
4. **Execute 1.6's four gates** and write the PoC exit report:
   acting quality (rubric, Tier A vs Phi-3.5-mini comparator), prompt token
   budget on the *real* tokenizer, download acceptance, device viability
   (peak RAM / tokens-per-sec; physical-device measurement can stay human-gated).
5. **Only then** decide go / revisit on evidence. If acting quality fails the
   rubric, the roadmap already defines the escalation ladder (few-shot → GBNF →
   LoRA → tier bump) — run it *before* Phase 2 spend.

### The honest risk

The stub has let the project *feel* like it has a working game loop while the
riskiest assumption sits completely untested. That is the classic PoC failure
mode the roadmap explicitly warned against. The danger is not the code quality —
it is declaring victory on a loop whose only "AI" is a hardcoded string, then
building an economy, a server, and a UGC pipeline on top of it.

**Bottom line:** green-light finishing the PoC (1.1 + 1.6 on a real model);
red-light expanding into Phase 2 until the four exit gates are measured and
recorded.
