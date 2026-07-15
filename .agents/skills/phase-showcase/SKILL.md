---
name: phase-showcase
description: "Phase capability showcase. A roadmap phase's bullets are all done and verified — before you call the phase finished, ship a headless, human-readable showcase that demonstrates what the phase can actually do."
---

# 🎬 Phase capability showcase

## When to use

A ROADMAP phase's bullets are all `[x]`, the reviewer has no open blockers, and
the verifier returns PASS. **Before declaring the phase finished**, produce (or
refresh) its capability showcase. This is a per-phase Definition-of-Done step
(see [ROADMAP Appendix B](../../../docs/planning/ROADMAP.md#appendix-b--definition-of-done)).

## What a showcase is — and is not

- **Is:** a set of small scripts that drive the *real* shipped code paths of the
  phase and emit **human-readable Markdown** a non-technical reader can follow.
  It answers "what can this phase do, and does it visibly work?"
- **Is not:** the verification of record. The **test suite** (`make verify`) is
  what proves correctness. A green showcase never substitutes for a passing
  test; if the two ever disagree, the tests win and the showcase has a bug.

## Procedure

1. **Headless.** Scripts run with no UI, no network, and no heavy binary
   (no Flutter, no model). They drive the pure core / library APIs directly so
   they run in seconds in CI and on any dev machine.
2. **One script per capability area**, named and numbered to match the phase's
   sub-phases, under `tools/showcase/`. A shared report helper keeps output
   format consistent.
3. **A runner** (`scripts/showcase.sh`) runs them all, writes each report to
   `docs/reports/showcase/`, and regenerates an `INDEX.md`.
4. **Every report is self-explaining:** a title, a one-line subtitle, and — for
   each demonstrated claim — a table or a ✅/❌ line a non-technical reader can
   read. Prefer showing real values (state trajectories, distributions) over
   prose.
5. **Assertions must exercise the real claim.** A ✅ that is trivially true is a
   false positive. Watch especially for **units / scale artifacts** (a value
   divided by the wrong factor prints `0.0` and looks "fine") — cross-check a
   couple of numbers against the actual test suite or a second script.
6. **Surface, don't hide, bad signals.** If a demonstration reveals a real gap
   (a dead currency, a lopsided win-rate, an unbalanced constant), report it as
   ❌/a flag in the Markdown. The showcase earns its keep by making such signals
   discussable, not by always being green.
7. **Regenerate on change.** When the phase's code changes, re-run the runner so
   the committed reports stay honest. Commit the scripts *and* a generated
   snapshot so a reader can open them without running anything.

## Reference example (Phase 2)

- Scripts: [`tools/showcase/`](../../../tools/showcase/) (a `report.dart` helper +
  `showcase_0..9_*.dart`).
- Runner: [`scripts/showcase.sh`](../../../scripts/showcase.sh).
- Reports: [`docs/reports/showcase/`](../../../docs/reports/showcase/) — start at
  `INDEX.md`.

Run it with `bash scripts/showcase.sh`.

## Anti-patterns

- ❌ Treating the showcase as proof of correctness instead of the test suite.
- ❌ A script that needs the model / a device / the network — it won't run in CI
  and won't run for a reviewer.
- ❌ A wall of raw JSON logs. The audience includes non-technical readers; format
  for them.
- ❌ Leaving a stale report after the code changed.
- ❌ A demonstration whose ✅ is trivially true (asserts nothing) or hidden behind
  a units bug.
