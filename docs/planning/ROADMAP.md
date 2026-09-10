# 🗺 Psychosims — Technical Roadmap

> **Single source of truth for sequenced work.** Agents implement against this
> file phase-by-phase, drain every `[ ]` bullet in scope, append a tracking row,
> then stage. Humans push via `make git`.
>
> **Source blueprint:** [`STARTER.md`](../design/STARTER.md) (§1–§24). Every phase
> below cites the blueprint sections it realizes — see
> [Appendix C](#appendix-c--blueprint-cross-reference-map).
>
> **How to read a phase.** Each phase and sub-phase states four things on
> purpose, so any contributor (or a low-context model) can pick it up cold:
> **What** it covers · **Why** it matters · **How** it contributes to the whole ·
> and a short **Validation** line that says when it is done.
>
> **This plan is a living document.** Phases may be re-ordered, split, or
> rewritten as reality lands. Treat the sequence as the current best plan, not a
> contract carved in stone.

## 📊 Status snapshot

Update with `make roadmap.status` (parses the `[ ]` / `[x]` boxes below).
Counts are per major phase.

| Phase | Items | Done | Status |
|---|---|---|---|
| 0 — Foundations & Conceptual Corrections | 92 | 89 | 🟡 local foundation gates pass; bootstrap/matrix pending |
| 1 — Minimal Cross-Platform Runtime (PoC) | 93 | 78 | 🟡 runtime repaired; app/device acceptance pending |
| 2 — Deterministic Game Core (offline) | 87 | 85 | 🟡 offline integration passes; corpus/exit evidence pending |
| 3 — Server Control Plane & Authoritative State | 92 | 52 | 🟡 finite authoritative cure passes; full lifecycle pending |
| 4 — Content Pipeline & Distribution | 15 | 0 | ⚪ planned; cloud delivery pending |
| 5 — Networked Social & Economy Systems | 18 | 0 | ⚪ planned |
| 6 — Institutional Endgame & UGC | 19 | 0 | ⚪ planned; public portal/staffing pending |
| 7 — Presentation, Monetization & Launch | 22 | 0 | ⚪ planned; local preparation authorized, release excluded |
| **Total** | **438** | **304** | |


**Reassessment and current authorization (2026-09-10).** The
[project assessment](../reports/2026-09-10-project-assessment.md) disproved
previously checked build/runtime, application recovery, transcript protection,
solvability and authoritative-service acceptance criteria. Those specific
bullets are reopened without weakening their wording. Historical italic notes
inside bullets record earlier claims, not current passing evidence. Other
checked items retain their existing component/documentation status; they do not
prove a complete player journey or a passed phase validation. Counts are task
bookkeeping, not effort or a finished-product percentage.

The user authorized completing all assessment repairs and the remaining roadmap
**without cloud deployment, public hosting, publishing, release or distribution**.
The [execution plan](EXECUTION-2026-09-10.md) maps the repair waves and acceptance
tests; this roadmap remains canonical. Implement and validate local adapters,
workflows, build definitions and dry runs. Physical-device/live-provider tests,
cloud operations, staffed public moderation and actual platform release gates
remain **pending** when their input is unavailable or their action is excluded.
Do not tick a combined implementation/validation bullet from mocks or local
evidence alone when it also requires that external gate; keep completing
independent authorized work.

**Current repair acceptance:** the [remediation checkpoint](../reports/2026-09-10-remediation-progress.md) records 442 Dart/Flutter tests, actual held/certified Dart–Go–PostgreSQL sessions, encrypted restart/replay, balanced rewards, privacy/erasure recovery and current scanner results. Newly rechecked bullets use that evidence. Finite certified paths do not establish general outcome coverage, global individual ownership, full social transitions or a finished economy.

**Latest instruction fulfilled:** the already-started retry-configuration fix is
complete and verified; implementation has stopped. The broader goal is paused;
unchecked items remain pending
for an explicit future continuation. No deployment or release has occurred.

---

## 🧭 Guiding principles

These five principles govern every phase. They are the "why" behind the plan's
shape, not decoration.

1. **Centralized configuration, without exception.** All shared configuration
   lives in one authoritative layer (`config/`), is loaded once, validated
   against a typed schema at startup, and injected into everything else. No
   module reads raw environment variables or holds its own scattered constants.
   Balance numbers, feature flags, endpoints, and model parameters all resolve
   through this single source. See
   [`docs/design/DESIGN-centralized-configuration.md`](../design/DESIGN-centralized-configuration.md).

2. **Strong separation of concerns.** Each domain lives in its own module
   directory; reusable logic lives in a shared/common layer; the deterministic
   game rules never mix with UI or I/O. The directory layout in
   [`docs/code/ARCHITECTURE.md`](../code/ARCHITECTURE.md) is the contract.

3. **Correct the concept before building on it.** Known design flaws are
   resolved *early* (Phase 0), not carried forward. The blueprint's deferred
   entry-gate decisions and the residual audit items are a first-class,
   scheduled workstream — see the
   [Conceptual corrections register](#-conceptual-corrections-register).

4. **Speed, clarity, working software.** We prioritize a running end-to-end
   loop over ceremony. Documentation stays clear and current; code stays clean
   and concise. Automated tests are a **safety net for load-bearing logic** —
   the deterministic simulation core, the economy math, the prompt assembler,
   and server receipt validation — not a bureaucratic gate on every UI tweak or
   content edit. We favor reversible, iteratable changes over big-bang
   perfection.

5. **Crystal-clear, phased delivery.** Work is broken into phases and
   sub-phases, each with an explicit What / Why / How / Validation, so the plan
   is executable by any contributor without tribal knowledge.

---

## 🏛 Cross-cutting foundations

Two foundations are established in Phase 0 and then honored by **every**
subsequent phase. They are called out here because a violation anywhere is a
defect everywhere.

- **The configuration authority** (`config/`): one typed, validated, centrally
  loaded configuration surface for the whole monorepo. Environment differences
  are expressed as validated overlays on one schema — never as ad-hoc files
  scattered per module. (Principle 1.)
- **The module boundary map** ([`docs/code/ARCHITECTURE.md`](../code/ARCHITECTURE.md)):
  `core/` (pure deterministic rules, no I/O), `features/` (one directory per
  domain), `shared/` (reusable utilities, models, services), `server/`,
  `content/`, and `tools/`. (Principle 2.)

---

## 🔧 Conceptual corrections register

Principle 3 in concrete form. The blueprint and its three readiness audits left
a bounded set of decisions and fixes that must be resolved **before** the
systems that depend on them are built. Each item names the phase that closes it.
Nothing here requires new design exploration — these are commissioned artifacts
and bounded edits, not open research.

**All eleven artifacts now exist under [`docs/specs/`](../specs/README.md)** (see the
Artifact column). C-1…C-6 (the Phase 0.3 documentation deliverables) are complete;
C-7…C-11 have authoritative specs their implementation phases build against.

| # | Item | Ref | Artifact | Closed in |
|---|---|---|---|---|
| C-1 | Written **minimum device spec** (RAM, SoC class, OS floor) | §1 | [DEVICE-SPEC](../specs/DEVICE-SPEC.md) | Phase 0.3 ✅ |
| C-2 | **Base-model license shortlist** (redistribution terms compared) | §1 | [MODEL-LICENSE-SHORTLIST](../specs/MODEL-LICENSE-SHORTLIST.md) | Phase 0.3 ✅ |
| C-3 | **Infrastructure cost model** at 1k/10k/100k/1M MAU (full dataset) | §3 | [INFRA-COST-MODEL](../specs/INFRA-COST-MODEL.md) | Phase 0.3 ✅ |
| C-4 | **Multi-currency balance spec** — the one owner of every constant | §9 | [BALANCE-SPEC](../specs/BALANCE-SPEC.md) | Phase 0.3 ✅ → tuned Phase 2.8 |
| C-5 | **Desktop distribution + auth channels** | §3 | [ADR-0002](../design/ADR-0002-desktop-distribution-and-auth.md) | Phase 0.3 ✅ → built Phase 3.1 |
| C-6 | **Age-rating & content strategy** (mature band, tone guidelines) | §8 | [AGE-RATING-AND-CONTENT-STRATEGY](../specs/AGE-RATING-AND-CONTENT-STRATEGY.md) | Phase 0.3 ✅ → finalized Phase 7.5 |
| C-7 | **Prompt token-budget** vs the chosen model's usable context | §1/§6 | [PROMPT-TOKEN-BUDGET](../specs/PROMPT-TOKEN-BUDGET.md) | Phase 1.6 (measured) |
| C-8 | **Case lifecycle state machine** (corrected §18 states) | §18 (GM-1) | [PATIENT-LIFECYCLE](../specs/PATIENT-LIFECYCLE.md) | Phase 3.6 (implemented) |
| C-9 | **Server-derived hidden quantities** (Doubt, pressure, Trauma Severity) | §12/§17/§23 (GM-2) | [SERVER-DERIVED-QUANTITIES](../specs/SERVER-DERIVED-QUANTITIES.md) | Phase 5.3 / 5.5 (implemented) |
| C-10 | **UGC moderation staffing & SLA** before the portal opens | §2.4 (G-6) | [UGC-MODERATION-SLA](../specs/UGC-MODERATION-SLA.md) | Phase 6.4 (before open) |
| C-11 | **Session rule model** — card resolution, outcome engine, pharmacology, curve *shapes* (the rule-design owner; numbers stay in C-4) | §4/§11/§16 | [GAME-RULES](../specs/GAME-RULES.md) | Phase 2.1 / 2.3 (implemented against) |

> When an item is closed, tick it in its owning phase and add a
> [`DECISION_LOG`](../project/DECISION_LOG.md) row if it settled a meta-decision.

---

## 📑 Table of contents

- [Phase 0 — Foundations & Conceptual Corrections](#phase-0--foundations--conceptual-corrections)
- [Phase 1 — Minimal Cross-Platform Runtime (PoC)](#phase-1--minimal-cross-platform-runtime-poc)
- [Phase 2 — Deterministic Game Core (offline)](#phase-2--deterministic-game-core-offline)
- [Phase 3 — Server Control Plane & Authoritative State](#phase-3--server-control-plane--authoritative-state)
- [Phase 4 — Content Pipeline & Distribution](#phase-4--content-pipeline--distribution)
- [Phase 5 — Networked Social & Economy Systems](#phase-5--networked-social--economy-systems)
- [Phase 6 — Institutional Endgame & UGC](#phase-6--institutional-endgame--ugc)
- [Phase 7 — Presentation, Monetization & Launch](#phase-7--presentation-monetization--launch)
- [Appendix A — Tracking conventions](#appendix-a--tracking-conventions)
- [Appendix B — Definition of done](#appendix-b--definition-of-done)
- [Appendix C — Blueprint cross-reference map](#appendix-c--blueprint-cross-reference-map)

---

## Phase 0 — Foundations & Conceptual Corrections

**Goal.** Lock the foundations everything else stands on — the centralized
configuration authority, the separated directory structure, the automated
quality/security gates, the observability and versioning conventions, and the
core project docs — and resolve the deferred design decisions the blueprint
flagged as entry gates. No feature code ships here; this phase makes the rest of
the roadmap safe, fast, and reliable to execute.

**Scope id.** `phase-0`

**Why this is first.** Principles 1, 2, and 3 are all foundational. Building a
config system, a module boundary, a CI gate, or a cost model *after* features
exist means retrofitting them into scattered code — the exact failure this plan
is designed to avoid. Sub-phases 0.5–0.12 are **cross-cutting foundations
established alongside** 0.1–0.4 (not strictly after them): every later phase
inherits the CI gate, the security + server-integrity posture (abuse throttling,
an append-only audit trail, and a backup/disaster-recovery plan for the
authoritative store), the logging/versioning/identity conventions, the
determinism/serialization contract (including deterministic fixed-point money and
a single authoritative-time seam), the client application + persistence
architecture, the offline-first transport conventions, the
accessibility/localization baseline, and the content-integrity + prompt-injection
defenses from day one rather than bolting them on — each is cheap as a convention
and ruinously expensive as a retrofit.

**Validation.** `make verify` (project + framework test suites + `make doctor`)
exits 0 cold; the repo builds an empty `app/` skeleton (blank Flutter screen), a
native/FFI stub, and a minimal server health-check stub on the pinned toolchains;
the config authority loads + validates a sample config and rejects a malformed
one; the ~1.8 GB base model is fetched out-of-band and checksum-verified rather
than committed; the deterministic `core/` produces an identical outcome for a
fixed state + action + seed; the same log event renders identically across the
Dart, native, and server stacks; CI runs build/lint/format/test on every push
(the security-enforcement gates — secret-scan, SBOM, and vulnerability/license
scanning — are documented as conventions but deferred to Phase 2 pre-work per
[DECISION 0017](../project/DECISION_LOG.md), so the PoC runs without them); the
six Phase 0.3 correction
artifacts (C-1…C-6) are committed, with authoritative specs also produced for
C-7…C-10; the client's state-management, dependency-injection, local-persistence
and concurrency conventions are declared and exercised by a trivial slice; a
remote call degrades to offline-first and replays without data loss or double
application; every user-facing string is externalized behind an
accessibility- and locale-aware presentation layer with no hard-coded copy;
economy math resolves through a deterministic fixed-point money type (no
platform-dependent floating point in `core/`) and every time-dependent rule reads
one injected, server-reconcilable clock; the audit-trail schema, the
abuse-prevention baseline, and the backup/DR posture are documented as
conventions (executed in Phases 3.1–3.3 once the store and server exist); the
performance-budget targets and the memory-pressure rule are declared (measured at
the Phase 1.6 device-viability gate); and a planted real diagnostic label
(DSM/ICD) or a hostile untrusted string routed at the prompt is rejected by the
content-integrity and injection-defense gates.

### 0.1 — Repository, workspace structure, toolchain & reproducible dev environment (separation of concerns)

**What.** Stand up the monorepo skeleton with the module boundaries defined in
[`ARCHITECTURE.md`](../code/ARCHITECTURE.md) — `app/` (Flutter client),
`server/`, `packages/`, `content/`, `config/`, `tools/`, `docs/` — settle the
server runtime/toolchain question the config design left open, and pin a
**reproducible dev environment** (client, native/FFI, and server toolchains)
plus the policy for the large model binary that never belongs in git.

**Why.** A clean boundary from day one is cheaper than any later refactor and
makes every subsequent phase drop into an obvious home (Principle 2). The server
runtime must be decided here because it determines whether the shared schema in
`packages/` is one package or two — a choice that ripples into Phase 0.2 (config),
Phase 0.8 (serialization), and Phase 3 (server). The native/FFI toolchain and the
~1.8 GB model-delivery policy must be settled now because Phase 1.1 and the
Phase 0.7 C++ logging shim both assume they already exist — discovering "where
does the native code live and how do we ship the model?" mid-PoC is a retrofit.

**How.** Establishes the physical shape all later code fills, pins the
languages/versions the CI gate (0.5) enforces, and makes "it compiles on Linux"
reproducible on any machine and in CI instead of "works on mine"; nothing lands
outside a declared module.

**Validation.** Empty skeleton compiles on Linux from a clean one-command
bootstrap; `app/` runs a blank Flutter screen; the native/FFI stub and the
server stub build + answer a health check; the ~1.8 GB model is fetched
out-of-band (not committed) and checksum-verified; the folder layout, build
matrix, and pinned toolchain versions match `ARCHITECTURE.md`.

- [x] Create the monorepo skeleton (`app/`, `server/`, `packages/`, `content/`, `config/`, `tools/`) with a top-level `README` in each, matching `ARCHITECTURE.md`.
- [x] Decide + record (ADR) the **server runtime/language** so `packages/` sharing (one schema vs two) and the toolchain are unambiguous; stand up a minimal server health-check stub rather than leaving the shape deferred.
- [x] Define the Flutter client layout (`app/lib/core/` pure, `app/lib/features/`, `app/lib/shared/`) and codify the "core has no I/O, no model calls" boundary.
- [x] **Settle the physical home of the pure deterministic core** so the `app/` client and the headless `tools/` bots + sandbox import **one** implementation — resolve `app/lib/core/` vs a shared `packages/` package now (and update [`ARCHITECTURE.md`](../code/ARCHITECTURE.md) if it moves), because Phase 2.8 solvability bots and Phase 4.3 validation both run the core outside the app and a duplicated core would silently drift from the shipped rules.
- [x] **Declare the native/FFI module home** — the llama.cpp C/C++ binding layer and its build inputs — so Phase 1.1's inference path and Phase 0.7's C++ logging shim land in a declared module, not ad-hoc under `app/`.
- [x] Declare the **cross-platform build matrix** (the five target platforms) and which are validated when — Linux desktop + x86 Android emulator in Phase 1; the rest deferred.
- [x] Add the language toolchains with **pinned versions** — Flutter/Dart, the chosen server runtime, **and the native C/C++ toolchain (clang/NDK) for llama.cpp** — plus a `make`-level build/lint/format gate wired into `make doctor`.
- [ ] Establish a **reproducible dev-environment bootstrap** (a pinned SDK/version manifest + a one-command setup such as a devcontainer or bootstrap script) so "compiles on Linux" holds identically on any dev machine and in CI, not just locally.
- [x] Provide a **single monorepo task orchestrator** (one `make`/workspace entry point that builds, tests, lints, and formats every module the same way locally and in CI) so no module invents its own commands and the 0.5 gate wraps one interface, not five.
- [x] **Pin and record build inputs** as a convention from day one (deterministic toolchain + dependency hashes, a lockfile-backed build manifest), so the reproducible/verifiable signed-release build and provenance audit can be *implemented* at Phase 7.6 without a retrofit — the build-side complement to the signing-key custody plan (0.6) and [ADR-0002](../design/ADR-0002-desktop-distribution-and-auth.md).
- [x] **Declare where generated code lands** (schema/serialization codegen from `packages/`, FFI bindings) — a committed-vs-generated boundary + a "generated is never hand-edited" rule — so the 0.8 shared-schema contract has an unambiguous, reviewable output home.
- [x] Define the **large-binary policy**: the ~1.8 GB GGUF model and build artifacts are **never committed** — declare `.gitignore` + `.gitattributes` (LFS or, preferably, out-of-band fetch-on-first-run) and a checksum-verified fetch step that Phase 1 consumes (integrity closed in 0.6).
- [x] Document the structure, the "where does new code go?" rule, and add a `CODEOWNERS` map for the module boundaries.

### 0.2 — Centralized configuration authority

**What.** Build the single authoritative configuration layer: one typed schema,
one loader, validation at startup, environment overlays, dependency-injected
access, and an enforced ban on raw environment reads. No secrets in the repo —
only variable *names* and validated shapes.

**Why.** Principle 1 is absolute. Every later system (endpoints, model params,
balance constants, feature flags) resolves through this one surface, so config
can never drift or scatter. Enforcement (a lint/CI rule) is what keeps the
invariant true as the codebase grows, rather than trusting review alone.

**How.** Becomes the backbone all modules read from; kills environment-specific
and module-specific config before it can start, and binds every balance constant
to the C-4 spec so §9 has exactly one owner.

**Validation.** A sample config loads, validates, and rejects a malformed config
with a clear error; a raw-env read anywhere outside `config/` fails the gate;
balance constants resolve only through config; loader/validator unit tests pass
(load-bearing logic per Principle 4).

- [x] Design + implement the typed config schema + loader (see [`DESIGN-centralized-configuration.md`](../design/DESIGN-centralized-configuration.md)), grouped `network` / `model` / `promptBudget` / `balance` / `featureFlags` / `secretsRefs`.
- [x] Add startup validation with actionable errors; fail fast; reject unknown keys and out-of-range values.
- [x] Implement environment overlays (dev / staging / prod **plus a `test`/CI overlay**) as validated layers over one base schema, so tests and CI run against deterministic, validated config rather than ad-hoc values.
- [x] Provide DI access and add a **lint/CI rule that fails the build on any raw environment read** outside `config/` (closes the DESIGN doc's open enforcement item).
- [x] Bind **all balance constants** to the config `balance` group sourced from the C-4 balance spec — no constant duplicated in a feature (Principle 1 + §9).
- [x] **Define how validated config crosses module boundaries** — injected into the native/FFI layer (model params), the `server/` runtime, and the `tools/` sandboxes as validated values, so no consumer (native, server, or bot) reads raw env or holds its own copy.
- [x] Add config **schema versioning** + secret-by-reference handling (`.env.example`, names only); **guarantee secrets are never logged** and emit the effective *non-secret* config at startup for reproducibility; unit-test the loader/validator.
- [x] Establish the **feature-flag & kill-switch discipline** behind the same DI interface — flags resolve through the config authority (never ad-hoc booleans), support progressive rollout, and give server-authoritative systems (receipt validation, matchmaking, the economy) and the `ruleset_version` sunset a documented off-switch — so a bad release degrades safely instead of requiring an emergency app-store push.
- [x] Define **config precedence + typed numeric bounds** explicitly (base → environment overlay → secret refs → runtime flags), so every value has a documented resolution order and out-of-range balance/model/network numbers fail validation at startup rather than surfacing as gameplay or cost bugs later.

### 0.3 — Conceptual correction pass (close the entry gates)

**What.** Produce the deferred artifacts and settle the open decisions from the
[corrections register](#-conceptual-corrections-register): C-1 device spec, C-2
model-license shortlist, C-3 cost model, C-4 balance-spec skeleton, C-5 desktop
distribution/auth decision, C-6 age-rating direction — plus author the C-7…C-10
authoritative specs early so their owning phases build against a fixed reference.
Also apply any residual blueprint wording fixes flagged by the audits.

**Why.** Principle 3: resolve foundational flaws before they are encoded into
code. These gate content, networking, and economy work downstream.

**How.** Each artifact unblocks a specific later phase and prevents building on
an unproven assumption.

**Validation.** Each artifact is a committed doc under `docs/specs/` (or an ADR);
each closes its register row; meta-decisions are logged in `DECISION_LOG.md`.

- [x] Write the **minimum device spec** (C-1) — concrete RAM/SoC/OS floor the PoC measures against. → [DEVICE-SPEC](../specs/DEVICE-SPEC.md)
- [x] Write the **base-model license shortlist** (C-2) — candidate models with redistribution terms compared. → [MODEL-LICENSE-SHORTLIST](../specs/MODEL-LICENSE-SHORTLIST.md)
- [x] Draft the **infrastructure cost model** (C-3) at 1k/10k/100k/1M MAU covering the full server dataset, not just profile rows. → [INFRA-COST-MODEL](../specs/INFRA-COST-MODEL.md)
- [x] Draft the **multi-currency balance spec skeleton** (C-4) — every currency's sources and sinks, all constants owned here. → [BALANCE-SPEC](../specs/BALANCE-SPEC.md)
- [x] Decide **desktop distribution + auth channels** (C-5) and record the decision. → [ADR-0002](../design/ADR-0002-desktop-distribution-and-auth.md)
- [x] Set the **age-rating direction + Manipulative-card tone guidelines** (C-6) to be finalized pre-submission. → [AGE-RATING-AND-CONTENT-STRATEGY](../specs/AGE-RATING-AND-CONTENT-STRATEGY.md)
- [x] Author the **C-7…C-10 authoritative specs early** (implementation stays in the owning phases): prompt token budget, patient lifecycle, server-derived quantities, UGC moderation SLA. → [PROMPT-TOKEN-BUDGET](../specs/PROMPT-TOKEN-BUDGET.md), [PATIENT-LIFECYCLE](../specs/PATIENT-LIFECYCLE.md), [SERVER-DERIVED-QUANTITIES](../specs/SERVER-DERIVED-QUANTITIES.md), [UGC-MODERATION-SLA](../specs/UGC-MODERATION-SLA.md)

### 0.4 — Core documentation baseline

**What.** Establish the human-and-agent-readable project docs: charter,
architecture, glossary, decision log, and the first ADRs.

**Why.** Clear docs are Principle 4's other half. New contributors and low-context
models must orient without reverse-engineering intent.

**How.** Gives every later phase a stable place to record architecture, terms,
and decisions instead of scattering them.

**Validation.** `docs/project/`, `docs/code/`, and `docs/design/` contain filled
(non-template) documents; `docs/README.md` links resolve.

- [x] Fill `docs/project/CHARTER.md`, `GLOSSARY.md`, `DECISION_LOG.md`.
- [x] Fill `docs/code/ARCHITECTURE.md` with the system context + module map.
- [x] Record foundational decisions as ADRs in `docs/design/` (server-authoritative model; centralized config).
- [x] Fill the project identity block in `docs/tracking/context.md` and the root `README.md` one-liner.

### 0.5 — Quality gates: CI/CD, pre-commit & the test harness

**What.** Stand up the automated gates the whole plan assumes: continuous
integration (build + lint + format + `make verify`), local pre-commit hooks that
mirror CI, and the test harness that Phase 1.3 and Phase 2's load-bearing tests
plug into.

**Why.** Principle 4 (working software, protected core) and the tracking model
in [`AGENTS.md`](../../AGENTS.md) both assume gates that actually run. Without
CI, "green" is an unverified claim; without a harness, the first unit test in
Phase 1.3 has nowhere to live. Reliability and integrity start here.

**How.** Every subsequent phase's Definition of Done ("`make doctor` exits 0",
"tests move with code") is enforced mechanically instead of by convention.

**Validation.** A red build blocks merge; `core/` unit tests run headlessly in
CI across the initial build matrix; secret-scan + lint run both pre-commit and
in CI; the gate stays under its time budget.

- [ ] Stand up **CI** running build + lint + format + `make verify` on every push/PR across the initial build matrix (Linux + Android emulator), with **required status checks + branch protection** so a red build cannot merge. Record the chosen CI provider (e.g. GitHub Actions) in a short ADR rather than hard-coding a vendor assumption.
- [x] **Extend `make verify` / `make test`** beyond the xops framework suite to run the project test suites (Dart `core/`, native/FFI, server) so "verify" means the *product* is green, not just the agent framework.
- [x] Wire pre-commit/local hooks mirroring CI (format, lint, secret-scan) so failures surface before push, never after.
- [x] Establish the **test harness + conventions for every stack** — unit runner + fixtures + headless mode (Dart), a **native/FFI test path**, and an **integration harness** — that Phase 1.3 (assembler), the FFI boundary (1.1/1.4), and Phase 2/3 load-bearing tests build against.
- [x] Establish **test-data / fixture management + deterministic CI seeds** — a shared home for golden fixtures and sample manifests/receipts, a fixed RNG seed convention in CI (ties to the 0.8 determinism contract), and a rule that fixtures move with the code they pin — so tests are reproducible run-to-run and machine-to-machine.
- [x] Add a **build/dependency caching strategy** (pub, native compile artifacts, cached model fetch) plus a CI-time/build-time budget and a **fail-on-flaky** policy so the gate stays fast and trustworthy.
- [x] Wire the **content-integrity gate (0.12) into CI** — the no-real-clinical-label lint and the untrusted-input schema checks run on every push, so a banned DSM/ICD term or a free-text field that could reach the prompt fails the build, not review.
- [x] Add **contract tests across the client/server trust boundary** — the shared receipt/manifest schema (0.8) round-trips byte-identically on both sides — so the Phase 3 boundary cannot silently fork; a schema change breaks the contract test, not production.
- [x] Adopt **property-based / fuzz testing for the deterministic core and the canonical serializer** (seeded generators exploring the state×action space) so determinism and round-trip integrity are proven across the input space, not just hand-picked examples (Principle 4 — load-bearing logic).
- [x] Add coverage reporting for load-bearing modules (`core/`, economy, prompt assembler, receipt validation) — reported to inform, not a blanket gate (Principle 4 + [DECISION 0011](../project/DECISION_LOG.md)).

### 0.6 — Security, secrets & supply-chain integrity

**What.** Establish the baseline security **and server-integrity** posture for a
server-authoritative system: secret handling, dependency integrity, license
compliance, a written trust-boundary threat model, and the operational integrity
foundations the "ironclad progress preservation" promise (§3) rests on — abuse
throttling, an append-only audit trail for authoritative actions, a
backup/disaster-recovery plan, and a data-lifecycle/erasure model that keeps
moderation (§2.5, §17) and PII separation (§8) enforceable.

**Why.** The whole design rests on "a client-computed number is a claim, not a
fact" ([`ARCHITECTURE.md`](../code/ARCHITECTURE.md) §4–§5). Secrets, vulnerable
dependencies, or incompatible licenses (especially around the C-2 base model)
are integrity risks that are far cheaper to fence off now than to retrofit. The
authoritative store is the single source of truth for progression and the
economy, so losing it, corrupting it, or being unable to audit *who changed what*
is an existential failure — a backup/restore drill, an audit trail, and abuse
throttling are foundations, not Phase-3 afterthoughts. This grounds Phase 3
(auth/PKI/receipts), Phase 5 (anti-collusion), Phase 6 (creator royalties), and
Phase 7.3 (moderation backdoor).

**How.** Turns the trust boundary from prose into enforced gates and gives every
later security-sensitive phase a documented threat model to extend.

**Validation.** A committed secret is caught by the gate; a vulnerable or
license-incompatible dependency fails CI; `SECURITY.md` + a threat-model stub
exist and are referenced from the architecture doc; the audit-trail, abuse-limit,
backup/restore, and data-erasure conventions are documented (schemas + drills
defined, wired for real in the owning server phases).

> ⚠️ **Deferred to post-PoC ([DECISION 0017](../project/DECISION_LOG.md)):** No
> security implementation work starts until the Phase 1 PoC is up and running.
> All bullets below are picked up as Phase 2 pre-work once the PoC exit gates
> (Phase 1.6) pass.

- [x] Add `SECURITY.md` + a lightweight threat-model stub anchored on the server-authoritative trust boundary and the "no transcripts durable" invariant.
- [x] Implement secret handling end-to-end: `.env.example`, CI + pre-commit secret-scanning, and the enforced "names not values" rule.
- [x] Add dependency **lockfiles + a pinned-version policy** and **generate an SBOM**; fail CI on unreviewed drift.
- [x] Add dependency **vulnerability + license-compliance** scanning (ties to C-2 model redistribution terms + third-party deps).
- [x] **Establish the signing-key custody plan** for every signature the design relies on — mobile/desktop app signing ([ADR-0002](../design/ADR-0002-desktop-distribution-and-auth.md)) and server-signed presence/receipts/manifests (Phases 3/4) — locations, rotation, and access only; no keys in-repo.
- [x] **Establish the client-side data-at-rest posture**: the durable offline receipt queue (Phase 3.4), the cached primitive profile (3.2), auth tokens, and any device-held signing keys live in platform secure storage (Keychain / Keystore / OS credential store), never plaintext on disk — the client half of the key-custody plan above.
- [x] **Design the server-side abuse-prevention baseline** (policy + shapes only): the authenticated-request rule, per-account/per-endpoint rate-limit + throttle conventions, and request-quota shapes every anti-farming and anomaly-detection system (§3, §17, §21) will plug into — so the enforcement built in Phase 3.1 rides a documented convention rather than being re-invented per feature.
- [x] **Define the append-only audit-trail schema + convention** for authoritative actions (moderation, ownership transfers, receipt acceptance/rejection, royalty payouts) — tamper-evident, correlation-id–stamped (0.7), transcript-free — so the trail *implemented* in Phase 3.3 makes integrity incidents forensically reconstructable and gives the Phase 7.3 moderation backdoor an accountable record.
- [x] **Define the backup / disaster-recovery posture** for the authoritative profile + ledger store — backup cadence and point-in-time-recovery target — plus the server data-migration + transactional-integrity conventions the Phase 3 ownership arbitration (the double-spend analog) depends on; the documented restore drill that *proves* "ironclad progress preservation" (§3) runs in Phase 3.2 once the store exists.
- [x] **Turn "no transcripts durable" into an enforced gate** (a test/lint that fails if a raw dialogue transcript can reach a durable store or server log) and write a short **data-classification & privacy baseline** the later PII work extends.
- [x] **Define the data-lifecycle & erasure model** — pseudonymous IDs only in the ledger (§17), and a right-to-erasure / revocation data path that feeds the §17 revocation list, honours §8 PII separation, and covers the C-6 mature-rating age-gate/consent data — so deletion and moderation obligations are designed in, not bolted on.
- [x] Document the responsible-disclosure path + the moderation-backdoor access-control principles that Phase 7.3 implements.

### 0.7 — Observability, versioning & performance baselines

**What.** Establish the conventions every later phase must adopt from its first
line of code: a single **cross-stack logging convention** (one structured
log-line schema, a balanced-emoji formatting style, and identical output across
the C++ FFI layer, the Flutter/Dart client, and the server), error
classification, the versioning registry for `ruleset_version` and the manifest
schema, performance budgets, and the privacy-scrubbed telemetry contract.

**Why.** These are cheap as conventions and expensive as retrofits. A logging
pattern only pays off if it is *one* pattern — the same event must look and parse
the same whether it comes from llama.cpp over FFI, Dart, or the server, or logs
become unfollowable and ungreppable across the stack (Principle 1). `ruleset_version`
pinning (Phase 3.3) and manifest schema versioning (Phase 4.1) need a single
source of truth *before* the first version exists; performance budgets feed the
Phase 1.6 device-viability gate; the telemetry scrub contract is what lets the
Phase 6.6 balance oracle exist without leaking player data. (Principles 1, 4;
readability + efficiency + integrity.)

**How.** Gives features a shared logger per stack that emits an identical line, a
shared error taxonomy, an authoritative version registry, and recorded perf
baselines instead of each module inventing its own — preventing drift across the
whole system.

**Validation.** Logging/error/versioning conventions are documented in
[`docs/code/`](../code/) and referenced from `ARCHITECTURE.md`; the **same log
event renders identically** from the Dart client, the C++ FFI layer, and the
server; a raw `print` / `std::cout` / `stdout` write that bypasses the logger
fails the gate; a performance-budget baseline file exists; the telemetry scrub
contract is defined (schema + rules only, no collection yet).

- [x] Author a single **cross-stack logging convention** (`docs/code/LOGGING.md`): one canonical structured log-line schema — timestamp, level, scope/module, event name, structured key–values, and a correlation/session id — reused verbatim by the C++ FFI layer, the Flutter/Dart client, and the server (one convention, not three).
- [x] Define the **formatting + balanced-emoji style**: exactly one leading emoji per line mapped to level/severity (e.g. debug 🔍, info ℹ️, success ✅, warn ⚠️, error ❌, fatal 🛑), aligned/padded columns for scannability, and a hard rule of *no decorative emoji spam and no emoji inside machine-parsed fields* — so logs stay both human-readable and `grep`-able.
- [x] Provide a **shared logger per stack with identical output**: a Dart logger in `app/lib/shared/`, a thin C++ logging shim across the llama.cpp FFI boundary, and the server logger — all emitting the same rendered line and the same structured payload (human-readable in dev, JSON in staging/prod, selected via the config authority in 0.2), never raw transcripts server-side (§17); add a lint/CI check that fails direct `print` / `std::cout` / `stdout` writes bypassing the logger.
- [x] Establish the **versioning registry/conventions** for `ruleset_version` (Phase 3.3) and the manifest schema version (Phase 4.1) as a single source of truth from day one.
- [x] Define the **error-classification** convention (user / system / external; offline as a first-class state, not an error) that all features adopt, carried on the shared log schema.
- [x] Define **correlation/session-id propagation across the trust boundary** so one session's client, native/FFI, and server log lines — and its eventual receipt — share a single id end-to-end, making the receipt flow debuggable without ever persisting a transcript.
- [x] Establish the **identifier & idempotency-key strategy** as a single convention: how entity ids, the client-generated receipt idempotency keys (§3, Phase 3.4), and the pseudonymous therapist ids (§17) are generated (collision-resistant, non-PII, non-enumerable), so dedupe, provenance, and privacy all rely on one documented id scheme rather than ad-hoc formats per feature.
- [x] Define the **metrics contract** (counters / timers / gauges) as a concern distinct from logs — the minimal signal set the C-3 cost model and the Phase 6.6 balance oracle consume — schema only, no collection yet.
- [x] Define the **per-stack performance-budget targets** + the file they live in — app cold-start, inference tokens/sec + latency target, peak-RAM ceiling anchored to the [DEVICE-SPEC](../specs/DEVICE-SPEC.md) floor, UI frame budget, and binary size incl. the ~1.8 GB model delivery — so every later feature has a numeric budget to regress against, not a vibe; the actual baselines are *measured* against these targets at the Phase 1.6 device-viability gate.
- [x] Define the **privacy-scrubbed telemetry + crash/error-reporting contract** the Phase 6.6 balance oracle consumes — schema, scrubbing rules, opt-in posture ([DECISION 0006](../project/DECISION_LOG.md)), and server-log **retention/redaction** so raw transcripts are never persisted (§17); no collection yet.

### 0.8 — Determinism, serialization & shared-schema foundations

**What.** Establish the integrity foundations the trustworthy systems stand on:
a **determinism contract** for the pure `core/` (seeded RNG + injected clock),
a **canonical, stable serialization** for the `packages/` schemas (manifest,
receipt, structured deltas), the **shared-schema strategy** across the client and
the (0.1-decided) server runtime, and the golden-fixture discipline that keeps
all three from drifting.

**Why.** The entire design rests on determinism and stable contracts:
§4 requires a deterministic core (fixed state + action → fixed outcome), §3
validates receipts against a pinned `ruleset_version`, and §2.2 runs
mechanical-solvability bots that only work if replay is exact. If randomness,
wall-clock time, or non-canonical serialization leak in, receipts stop being
replayable, signatures/checksums (0.6, Phases 4/5) stop being reproducible, and
the client/server contract silently forks across the trust boundary. These are
foundations, not features — retrofitting determinism after the core exists is a
rewrite (Principles 2, 4; integrity + reliability).

**How.** Gives the sim core a single seam for all nondeterminism, gives every
signed/validated payload one byte-stable encoding, and binds the schemas to the
`ruleset_version` registry (0.7) so a contract-breaking change fails a test
instead of reaching production.

**Validation.** A fixed (state, action, seed) yields a byte-identical outcome and
serialized delta across two runs and two machines; the manifest/receipt schemas
round-trip through canonical encoding with stable ordering; a deliberate ruleset
or schema change flips a golden/snapshot fixture red.

- [x] Establish the **determinism contract for `core/`**: one seeded PRNG and an injected clock (no wall-clock, no ambient randomness in pure rules) so a fixed state + action + seed always yields the identical outcome — the precondition for Phase 2 determinism, Phase 4 solvability bots, and receipt replay.
- [x] **Ban platform-dependent floating point from `core/` and the economy**: define a deterministic **fixed-point / integer money + ratio representation** for every currency, multiplier, and percentage (§9, §14, §17, §19, §24), so the same receipt replays byte-identically across x86/ARM and client/server, and rounding can never mint or destroy currency — a cross-platform determinism *and* economy-integrity foundation.
- [x] **Define the authoritative-time seam**: the injected clock reconciles to *server* time for every time-dependent rule — ownership lease TTL (§3, Phase 3.4), cooldowns and recovery windows (§23), daily-reset cycles, tax weeks and audits (§22), and macro-event timing (§22) — while the device clock is treated as untrusted and only a monotonic source is used for local durations, so a player cannot gain advantage by changing their clock and offline replay stays consistent.
- [x] Define **canonical, stable serialization** for the `packages/` schemas (manifest, receipt, structured deltas) — deterministic field ordering + encoding — so checksums/signatures (0.6, Phases 4/5) and cross-version diffs are reproducible.
- [x] Settle the **shared-schema strategy** implied by the 0.1 server-runtime decision: one schema package vs two aligned ones, and the **language-neutral contract** (e.g. JSON Schema) if the server is not Dart, so the receipt/manifest contract cannot drift across the trust boundary.
- [x] Bind the schemas to the **`ruleset_version` registry** (0.7) and add **golden/snapshot fixtures** so a ruleset or schema change that alters a serialized outcome is caught by a failing test, not discovered in production.
- [x] Define the **wire-schema compatibility contract** — additive-only evolution and explicit unknown-field handling — so a newer client against an older server (and vice versa) degrades safely across the trust boundary; the 0.7 registry records *which* versions exist, this rule governs how they interoperate.

### 0.9 — Client application, state & persistence architecture

**What.** Settle the Flutter client's load-bearing architecture decisions before
any feature is written: the state-management approach, the dependency-injection
mechanism config and services flow through, the navigation/routing convention,
the local-persistence/offline-first storage seam, the on-device concurrency
model, and the internal shape every `features/` module repeats.

**Why.** These are the choices every screen and service silently assumes. Picking
them per-feature is how a codebase forks into three state patterns and four
storage layers. DI is also the concrete mechanism Principle 1 depends on — the
[config authority](#02--centralized-configuration-authority) is only injectable
if there is one declared way to inject it. The concurrency model is a hard
**performance** foundation: llama.cpp inference over FFI (Phase 1.1) must run off
the UI isolate or every turn stalls the frame loop.

**How.** Gives every later feature one obvious skeleton to drop into (Principle 2),
one seam for durable local state, and one rule for keeping heavy work off the UI
thread — so features add behaviour, not architecture.

**Validation.** A trivial vertical slice wires UI → injected service → persisted
state and back; a heavy task runs off the UI isolate without dropping frames;
local state survives a simulated app upgrade via the migration path.

- [x] Implement **GetX** as the state-management + dependency-injection layer ([DECISION 0016](../project/DECISION_LOG.md)), and make the [config authority](#02--centralized-configuration-authority) + shared services injectable through it (no globals, no ad-hoc singletons); document the choice in an ADR.
- [x] Establish the **navigation/routing convention** (typed routes + deep-link readiness for the C-5 desktop OAuth callback) so `session/` / `clinic/` / `progression/` flows compose predictably.
- [x] Define the **local-persistence & offline-first storage abstraction** — one seam for durable local state (the Phase 3.4 receipt queue, cached primitive profile, settings) with an explicit **local cache schema-migration** policy so state survives app upgrades and never scatters into per-feature stores.
- [x] Declare the **on-device concurrency model**: inference (llama.cpp/FFI), serialization, and fetch run off the UI isolate so the frame loop never stalls — a performance rule Phase 1.1 builds against.
- [x] Define the **app-lifecycle & crash-recovery convention**: state is durably checkpointed so a backgrounded, OS-killed, or crashed app relaunches into a consistent state with no lost or double-applied session progress — the client-side reliability complement to the 0.10 offline queue and the 0.6 backup posture.
- [x] Declare the **memory-pressure & asset-lifecycle rule** (convention + budget): the ~1.8 GB model stays resident while only compact manifests swap (§5 zero-overhead swap) and heavy presentation assets (the Phase 7.1 ink-wash layers) load/evict against a budget — so features are written to it from the start; that the app actually degrades gracefully under OS memory pressure on minimum-spec devices ([DEVICE-SPEC](../specs/DEVICE-SPEC.md)) is *verified* at the Phase 1.6 device-viability gate.
- [x] Codify the **feature-module skeleton** (the internal shape of `app/lib/features/<domain>/`: state, services, UI, tests) so every later feature lands in an identical, reviewable structure.

### 0.10 — Networking & offline-first transport conventions

**What.** Establish the client's transport conventions — one typed API-client
seam bound to the shared schema, a resilience policy for every remote call,
offline as a first-class state, and one verified large-asset fetch path — so no
feature ever hand-rolls HTTP.

**Why.** The design is explicitly local-first and offline-tolerant
([ARCHITECTURE.md](../code/ARCHITECTURE.md) §4): reconnects, timeouts, and
partial fetches are normal, not exceptional. Deciding retry/backoff, token
refresh, and offline queue-and-replay once — before Phase 3 (server) and Phase
3.4 (offline receipts) — prevents each caller inventing its own **reliability**
story. It also gives Phase 1 (the ~1.8 GB model) and Phase 4.4 (signed
manifests) one retryable, signature-verifying fetch path instead of two.

**How.** Turns "the network is unreliable" from a per-feature hazard into a
single, tested transport contract every server/CDN call rides on.

**Validation.** A remote call transparently degrades to offline-first and
replays on reconnect without data loss or double application; a large-asset
fetch resumes after an interruption and verifies its signature/checksum before use.

- [x] Establish the **typed API-client seam** bound to the shared `packages/` schema (0.8) — no ad-hoc HTTP in features — with auth-token injection + refresh routed through secure storage (0.6/0.9), and every mutating request carrying its idempotency key (0.7) so the server-side dedupe (Phase 3.4) has a client contract to rely on.
- [x] Define the **resilience policy for every remote call**: timeouts, bounded exponential backoff + jitter, idempotent-retry rules, honouring server rate-limit / `429` / `Retry-After` signals (the client half of the 0.6 abuse-prevention baseline), and a circuit-breaker / degrade-to-offline path that feeds the Phase 3.4 offline receipt protocol.
- [x] Make **offline a first-class transport state** (detection + queue-and-replay), consistent with the 0.7 error-classification convention, so the client degrades to local-first play without data loss and reconciles on reconnect.
- [x] Establish the **verified, bandwidth-aware large-asset fetch convention** (resumable/chunked fetch + signature/checksum verify before load, plus a metered-/cellular-connection posture) shared by the Phase 1 model download and the Phase 4.4 signed-manifest delivery — directly serving the §1 download-acceptance gate so the ~1.8 GB first-run fetch is deferrable and never silently burns a data cap.

### 0.11 — Accessibility & internationalization foundations

**What.** Externalize all user-facing text and set the accessibility baseline
from the first screen, so a text-heavy game on five platforms is localizable and
accessible by construction rather than by a painful late retrofit.

**Why.** String externalization, locale-aware formatting, and a11y (semantics,
scalable text, contrast, input alternatives) are the canonical "cheap now,
ruinous later" foundations. The economy display (§9), the ink-wash presentation
layer (Phase 7.1), and store-submission requirements (Phase 7.5) all assume this
was done from day one. Doing it now also protects the §4 core purity: the
deterministic core must emit stable **tokens/keys**, never localized prose.

**How.** Gives every feature one place to resolve copy and one accessibility
contract, and keeps localization/presentation strictly out of `core/`.

**Validation.** No hard-coded user-facing string exists (a lint/gate catches
one); the initial build matrix passes a basic a11y check (semantic labels,
scalable text, contrast); the core emits keys that the presentation layer
resolves to localized, accessible strings.

- [x] Externalize **all user-facing strings** behind a localization layer wired through the config-selected locale (0.2) — no hard-coded UI/dialogue-chrome copy — and add a gate that fails on a planted hard-coded string.
- [x] Establish **locale-aware formatting** (numbers, the §9 economy currencies, dates, pluralization) and **RTL-readiness** as a shared convention in `app/lib/shared/`.
- [x] Set the **accessibility baseline** — semantic labels, scalable text, sufficient contrast, and input alternatives — validated on the initial build matrix so Phase 7.1's presentation layer is built a11y-aware, not corrected after.
- [x] Define the **input & motion accessibility contract** for the card-driven interface (§11) and the ink-wash motion (§20): keyboard/switch/pointer alternatives to the focus wheel and sliders, honour OS reduce-motion / high-contrast settings (the chromatic-fracture and shader motion must be dampenable), and keep hit-targets and dynamic-type reflow within platform guidelines — so the game's most distinctive UI stays reachable.
- [x] Keep localization/a11y **out of the deterministic core**: `core/` emits stable tokens/keys, the presentation layer resolves them to localized, accessible strings — preserving §4 core purity and the 0.8 determinism contract.

### 0.12 — Content integrity, fictional-taxonomy discipline & untrusted-input safety

**What.** Establish the content-safety foundations every case-bearing system
inherits: an enforced ban on real diagnostic labels in game content, the
"evocative-not-alien" fictional-naming convention, and the untrusted-input /
prompt-injection defense contract for the strings that reach the local model.

**Why.** Two blueprint-named hazards have no home in the plan otherwise, and both
are ruinous as retrofits. First, §8 makes it *authoritative* that no real
diagnostic label or manual (DSM/ICD) may appear anywhere in content — manifests,
the nine-axis synthesis (§12), study fields, or the in-game encyclopedia (§15);
this is legal-safety and store-review survival, not a style preference, so it must
be a gate from the first authored string. Second, §11 is explicit that card-only
input closes the *direct* injection channel but **not** two indirect ones: peer-
authored case history (§17) and community-authored manifests (§21) are attacker-
controlled strings that reach the prompt. Deciding schema whitelisting, enums-over-
free-text, sanitization at signing, and template isolation *before* the content
pipeline (Phase 4), the living history (Phase 5), and the UGC portal (Phase 6)
exist is the only way the guarantee is "defended in depth" rather than patched
after an exploit. (Principles 2, 3; integrity + security + legal safety.)

**How.** Gives the `content/` pipeline, the receipt/history schemas, and the prompt
assembler one shared set of content rules and one untrusted-string handling
contract, so every downstream content system enforces the same invariants instead
of re-deriving them.

**Validation.** A planted real diagnostic label (e.g. a DSM/ICD term) in a
manifest, study field, or encyclopedia entry fails the content lint; a fictional
name that near-clones a real drug brand or diagnosis is flagged; a hostile string
in a case-history or manifest field is schema-rejected or neutralised so it can
never be read by the model as instructions; the disclaimer-string hooks exist for
Phase 7.5 to finalise.

- [ ] Implement the **no-real-clinical-label content-integrity gate** (§8): a lint/check over `content/` manifests, the nine-axis synthesis fields (§12), study-field definitions, and the fictional encyclopedia (§15) that fails the build on any real DSM/ICD term or real drug brand — authoritative across the whole content pipeline, wired into CI (0.5).
- [x] Establish the **fictional-taxonomy naming convention + registry** (§8 "evocative, not alien"): documented rules and a checkable registry for disorder, medication, and study-field names — familiar roots + plausible clinical/pharma suffixes, never a near-homophone of a real trademark or a reskinned real label — so names stay legible yet legally fictional.
- [x] Define the **untrusted-input / prompt-injection defense contract** (§11): treat peer-authored case history (§17) and community-authored manifests (§21) as untrusted — strict schema whitelisting (enums + numbers over free text wherever possible), server-side sanitization + length caps applied at signing time (§2.2), and template-level isolation so an untrusted string can never be interpreted as instructions by the local model.
- [x] Add the **disclaimer & fictional-framing string hooks** (§8): reserved, externalized (0.11) presentation slots for the "fictional simulation, not real care" disclaimer and entertainment-focused framing, wired from day one so Phase 7.5 finalises copy rather than retrofitting placement.

---

## Phase 1 — Minimal Cross-Platform Runtime (PoC)

**Goal.** Prove the core promise — a small local model + a compact patient
manifest + a Flutter game loop runs on **both** an Android emulator and a Linux
desktop — and clear the blueprint's falsifiable exit gates. This is also the
**first end-to-end exercise of the Phase 0 foundations** (config authority,
determinism seam, cross-stack logging, client/concurrency architecture, verified
large-asset fetch, content-integrity gate): the PoC must prove the *conventions*
hold under a real workload, not merely that inference emits text.

**Scope id.** `phase-1`

**Why this is the first real build.** §1 names this the true first milestone.
It de-risks the project's three existential bets (model can act, device can run
it, users accept the download) before any content, networking, or economy spend.

**Model under test (from Phase 0).** The candidate weights are already chosen
([DECISION 0015](../project/DECISION_LOG.md), [C-2](../specs/MODEL-LICENSE-SHORTLIST.md)):
**Tier A — Qwen2.5 1.5B (Apache-2.0)** primary with **Phi-3.5-mini (MIT)** as the
acting-quality comparator, **Tier B — SmolLM2 1.7B (Apache-2.0)** fallback for
4 GB-class devices ([DEVICE-SPEC](../specs/DEVICE-SPEC.md)). The bundled quantized
GGUF is therefore **~1–2 GB depending on the tier**, not a fixed 1.8 GB; the shipped
footprint is an *outcome* measured at 1.6, and the primary-vs-comparator pick is
confirmed there against the acting-quality gate — not assumed now.

> 🔒 **Security posture for the PoC (deferred hardening).** Per
> [DECISION 0017](../project/DECISION_LOG.md), no security *implementation* work
> (secret management, signing-key custody, backup/DR, secret-scan gate, SBOM)
> starts until the PoC is running — those land in their owning Phase 2/3 slices.
> Phase 1 exercises only the **model-integrity verification** already defined in
> 0.1/0.10 (checksum / signature checked *before* load) and the **"no durable raw
> transcript"** rule (0.6). Where a bullet below touches a signature, durable local
> state, the model file at rest, or telemetry, it *uses* the convention without
> standing up the full custody, secure-storage, backup, or opt-in-collection
> machinery; each such point is tagged **⏭ hardened later** with its owning phase.

> 🧩 **Build order & dependencies (read before picking up a sub-phase).** The
> sub-phases are numbered by topic, not by strict build order. The prompt
> assembler (1.3) consumes three things it does not own: the model's real
> tokenizer + chat template (1.1), the typed manifest (1.2), and the `SimState` +
> mandatory clue tokens the deterministic core (1.4) produces. Implement the 1.2
> schema and the 1.4 turn-resolver + clue-token contract *before or alongside*
> 1.3, and stand up the 1.1 inference service's tokenizer path early — otherwise
> 1.3 is tested against a stand-in and reworked. 1.5 wires the pieces; 1.6 only
> measures what the first five built.

> 🎯 **Determinism scope (a corrected assumption).** There are **two different
> guarantees, not one**. The pure `core/` is **byte-identical across
> architectures** (fixed-point + seeded RNG + injected clock, 0.8) — this is the
> receipt-replay contract. Model **inference is *not* byte-identical across
> architectures**: llama.cpp's floating-point matmul diverges between the x86
> emulator and an arm64 device, and even across thread counts and batch splits.
> So greedy / temperature-0 decode is only reproducible on the **same build +
> same architecture + pinned thread count + batch size**; that scoped guarantee
> is what the 1.6 token-budget and acting-quality samples rely on, and the
> cross-architecture divergence is *expected*, not a defect to chase.

**Validation.** The end-to-end loop runs on the x86 Android emulator + Linux
desktop and the four PoC exit artifacts (acting quality, device viability,
download acceptance, prompt token budget) are measured and recorded for **both
the Tier A primary and the comparator**; the loop accepts **only structured
(card/choice) actions — no free-text prompt box** (§4), runs inference **off the
UI isolate** without frame stalls or sustained-throughput collapse, emits a
single **correlation-id–stamped** log line spanning the Dart client and the C++
FFI layer, resolves every model/prompt parameter through the **config
authority**, produces a **byte-identical `core/` outcome** for a fixed state +
action + seed *across architectures* and a **greedy-decode inference reproducible
on the same build + pinned thread count** (see the Determinism-scope note),
applies each turn **transactionally** (a cancelled turn leaves no partial state
and no orphaned native call), keeps a hostile manifest string isolated as data
(**template-level injection isolation**), ships the model's **license/NOTICE**
with the build, and persists **no raw transcript**.

### 1.1 — Flutter app + llama.cpp FFI integration

**What.** Stand up the on-device inference path: preflight and fetch/verify the
GGUF model, load it through llama.cpp via Flutter FFI behind a narrow `shared/`
inference service (load / tokenize / chat-template / generate / cancel / unload),
and run streaming, cancellable inference **off the UI isolate** with an explicit
KV-cache lifecycle, a single-flight generation guard, and a runtime Tier A/B
model choice — packaged so the native library not only *links* in CI but *loads*
on Linux and the Android emulator.

**Why.** Local inference is the load-bearing technical unknown; everything else
assumes it works — and *how* it runs (off-isolate, resident, cancellable,
mmap-loaded, KV-cache-aware, leak-free, logged) determines whether the game loop
is *usable* and whether it clears the 1.6 device-viability budget, not just
whether a token appears.

**How.** Establishes the inference seam the whole session loop rides on, and is
the first consumer of the 0.1 native module + pinned build inputs, the 0.7 C++
logging shim, the 0.9 concurrency + memory-pressure rules, and the 0.10
verified-fetch convention.

**Validation.** The app preflights disk, fetches + verifies the model (promoting
it atomically only on a passing checksum), selects the correct tier for the
device, runs one streaming inference off the UI isolate after a warm-up pass,
and renders raw output on Linux + Android emulator; a cancelled/backgrounded
generation leaves no orphaned native call and no partial KV state; a second
concurrent request is serialized, never raced; repeated
load→generate→cancel→unload cycles leak no native memory under a sanitizer;
greedy-decode reproduces byte-identical output for a fixed seed **on the same
build + pinned thread count**.

- [x] Integrate llama.cpp via Flutter FFI behind a **narrow, typed `shared/` inference service** (load / tokenize / detokenize / **apply chat template** / generate / cancel / unload / **model-metadata query**) so no other module touches raw FFI; the binding lives in the 0.1-declared native module, not ad-hoc under `app/`. Embeddings/fine-tuning surfaces are explicitly out of scope (§18).
- [x] **Generate the Dart FFI bindings** with a pinned tool (`ffigen`) from a committed C header, and wire the native build into each platform's build system (CMake on Linux, Gradle `externalNativeBuild`/NDK on Android) so a normal `flutter build` produces and packages the `.so` — no manual native-build step — with the generated bindings honouring the 0.1 generated-code boundary (never hand-edited).
- [ ] **Pin the llama.cpp commit + the exact GGUF quantization (e.g. `Q4_K_M`) and its rationale** as recorded build inputs (0.1) so inference behaviour is reproducible across machines and CI; the native shared library **builds, links, and bundles** for Linux desktop and the x86 Android emulator — **and declares the `arm64-v8a` device target** (built, not perf-validated on the emulator) so the physical-device gate (1.6) is a rebuild, not a fresh integration. *Pinned in `native/PINNED_BUILDS.md`; Linux g++ stub build passes; CMake/Android NDK builds require `cmake` and `ANDROID_HOME` which are not installed in this environment.*
- [x] **Make the native library actually *load* on each target, not just link**: per-ABI JNI packaging on Android (`arm64-v8a` for devices, `x86_64` for the emulator) with 16 KB-page-size-aligned `.so`s, and the desktop `.so`/`.dll` shipped alongside the executable on a config-resolved load path — closing the silent gap between "compiles in CI" and "runs on device".
- [x] Implement the **first-run verified model fetch** on the 0.10 resumable-fetch convention — a **free-disk-space preflight**, chunked/resumable HTTP-range download, **checksum/signature verified before load with an atomic temp→final rename** (0.1 fetch policy + 0.6 verify-before-load) so a corrupt partial can never be loaded, and a re-fetch-on-corruption path — closing the supply-chain gap for the largest untracked asset. *(⏭ hardened later: signing-key custody + the model file at rest in platform secure storage move to 0.6/Phase 3; here we verify against the pinned checksum and store under a config-resolved path.)*
- [x] **Pin the exact model artifact source URL + checksum** for the first-run fetch (a mismatch fails closed and re-fetches); the third-party model host is consumed as-is for the PoC and the production distribution host is deferred. *(⏭ hardened later: the production CDN host + a cryptographically signed model manifest move to Phase 4.4.)*
- [x] **Bundle the model's license + NOTICE/attribution** text (Apache-2.0 / MIT per [DECISION 0015](../project/DECISION_LOG.md) / [C-2](../specs/MODEL-LICENSE-SHORTLIST.md)) with the app so the redistributed weights are compliant from the first build — a legal-integrity requirement, not a launch-time afterthought.
- [ ] Implement **runtime Tier A/B selection**: a first-run device-capability check (RAM/SoC/ABI vs the [DEVICE-SPEC](../specs/DEVICE-SPEC.md) floor) chooses the Tier A primary or the Tier B fallback, resolved through the **config authority** (0.2) — so 4 GB-class devices never attempt a model they cannot hold.
- [x] Load weights via **memory mapping (mmap)** and manage an **explicit KV-cache lifecycle** — allocate per session, **reset (not reallocate) between cases**, and reuse the stable Tier-1 prompt prefix across turns (1.3) instead of re-encoding it — cutting cold-start, peak RAM, and per-turn latency (the 1.6 budget); a case switch frees what it allocated and leaks nothing.
- [x] **Size `n_ctx` deliberately** as the smallest context window that holds the C-7 worst-case input budget + generation reserve — context size directly drives KV-cache RAM against the [DEVICE-SPEC](../specs/DEVICE-SPEC.md) floor — and expose it plus an optional **KV-cache quantization** (k/v cache type) knob through config as a peak-RAM lever for Tier B devices.
- [x] **Ingest the prompt as a batched decode** (`n_batch`), not token-by-token, since prompt evaluation dominates first-turn latency; expose `n_batch` through config and reuse the batched path for the T1-prefix warm-up so the 1.6 latency numbers reflect the shipped ingestion path.
- [ ] Run **all inference off the UI isolate** (0.9) with a **streaming token callback**, a **single-flight generation guard** (a second request is queued or rejected, never raced against the native context), and a **cancellation path** (session abandoned / app backgrounded mid-generation) that **frees/resets the native context** so a cancelled turn leaves no orphaned call and no partial KV state; a foreground resume re-arms cleanly.
- [x] **Respect the FFI/threading reality**: an FFI call blocks its calling isolate and a llama.cpp context is **not** safe for concurrent access, so generation runs on a **dedicated worker isolate/thread owning the single context**, and streamed tokens are marshalled back to the UI isolate over a port / `NativeCallable` — never by calling Dart from an arbitrary native thread (0.9).
- [x] **Stream detokenized output UTF-8-safely**: buffer raw token bytes and emit only **complete codepoints**, holding a partial multibyte sequence until the next token, so streamed dialogue never renders mojibake or splits a grapheme — a correctness bug that only surfaces on non-ASCII output.
- [x] **Guard the runtime context window**: verify prompt tokens + max output ≤ `n_ctx` **before** decoding and define the over-context behaviour (reject or stop, surfaced on the 0.7 taxonomy) so an oversized turn degrades gracefully and never trips a native llama.cpp assertion that would abort the whole process (reliability).
- [x] Provide a **deterministic decode mode** (fixed seed + temperature-0 / greedy, **pinned thread count + batch size**) selectable via config, distinct from the shipped sampling profile — reproducible **on the same build + architecture** (cross-architecture byte-identity is deliberately *not* claimed for float matmul; see the Determinism-scope note) so the 1.6 samples are a fixed target rather than a moving one.
- [x] **Expose a grammar / constrained-decoding seam (llama.cpp GBNF)** from day one — unused by the baseline sampling profile, but wired so the 1.6 acting-quality escalation ladder ([DECISION 0018](../project/DECISION_LOG.md)) is a config flip, not an FFI rewrite.
- [x] Expose the full **generation-parameter set** through the **central config authority** (0.2) — tier, context window, thread count / CPU-affinity, batch size, seed, sampling temperature, top-p / top-k, repetition penalty, max output tokens, and stop / EOS tokens; no hard-coded model constants, and run a **warm-up (first-token) pass at load** so the first real turn is not a latency outlier in measurement.
- [x] Add the **C++ logging shim across the FFI boundary** (0.7) so native load/inference events emit the same structured, correlation-id–stamped line as Dart — no raw `std::cout` / `stdout` bypass.
- [ ] Keep the model **resident** per the 0.9 memory-pressure rule (loaded once, reused across turns, explicit unload on shutdown / memory-pressure signal); classify inference failures on the 0.7 error taxonomy (**missing / corrupt / unsupported-ABI model, load failure, OOM, cancellation, generation error**) and **degrade an OOM to an actionable error or a Tier B retry**, never a hard crash.
- [x] **Add a native memory-safety gate**: repeated `load → generate → cancel → unload` cycles leak no memory and trigger no use-after-free under a sanitizer (ASan/LSan) on the Linux CI build — the hand-managed FFI boundary is load-bearing and the cheapest place to catch a leak is here.
- [ ] Confirm build + verified model load + warm-up + one streaming inference on **Linux desktop and the x86 Android emulator** from the 0.1 one-command bootstrap. *Android: `flutter build apk` produces a multi-arch APK (arm64-v8a, armeabi-v7a, x86_64) with `libpsychosims_native.so` bundled; the APK installs and `MainActivity` displays on the x86 emulator in ~887 ms. Linux desktop: inference runtime is verified by `flutter test` loading `libpsychosims_native.so`, but `flutter build linux` is blocked in this environment because `clang++`, `ninja`, and `pkg-config` are not installed (system packages require explicit user confirmation).*

### 1.2 — Minimal patient manifest schema + loader

**What.** Define a compact first-pass manifest (identity, style archetype,
initial pressure/sim state, available interaction patterns), load and
integrity-check it from a bundled asset, and establish the versioning,
initial-state, content-safety, and untrusted-input disciplines the production
schema (Phase 4.1) will extend.

**Why.** The manifest is the content atom; the loop needs one concrete case to
run against — and getting the *contract* right now (versioned, checksummed,
initial-state-typed, content-safe, injection-aware) is what lets Phase 4.1 extend
it **additively** instead of reshaping it, and what lets the Phase 4.4 signed-
manifest trust seam slot in without a redesign.

**How.** Gives the prompt assembler (1.3) and the sim core (1.4) their typed
input contract, on the 0.8 serialization rules, the 0.12 content-integrity +
injection contract, and the 0.2 config authority.

**Validation.** A sample manifest parses into typed models and **round-trips
byte-identically** through canonical serialization; a malformed, unknown-version,
or **checksum-mismatched** manifest fails loudly; the sample passes the
content-integrity lint and draws only from the fictional-taxonomy registry.

- [x] Define the minimal manifest schema in `packages/` (identity, style archetype, initial pressure/sim state, available interaction patterns) shared by app + tools, using the **canonical serialization + additive-only evolution** contract (0.8) with **`schema_version` + `content_checksum` fields from day one** and **field-level length/size caps**, so the untrusted-input *shape* (0.12) exists before Phase 4/6 accept external manifests.
- [x] **Publish the schema as a language-neutral contract** (e.g. JSON Schema, per the 0.8 shared-schema strategy) as the single source of truth, with the Dart typed models generated/derived from it — so `tools/` and a future non-Dart server (0.1) validate the *same* shape and the manifest contract cannot fork across the trust boundary.
- [x] **Set a total manifest byte budget + per-field caps** sized so a fully-populated worst-case manifest still fits the Tier-1 token budget ([C-7](../specs/PROMPT-TOKEN-BUDGET.md)) — so the 1.6 gate never discovers an inherently over-budget content shape after the fact.
- [x] Define the **initial-state contract**: the manifest's pressure/sim-state fields are exactly the typed inputs the deterministic core (1.4) consumes, and the interaction-pattern enum foreshadows the Phase 2.1 card taxonomy — so Phase 2/4 extend the contract rather than reshaping it.
- [x] **Define the clue-token vocabulary + interaction-pattern enum as typed, whitelisted contracts** (not free strings) shared with 1.3/1.4 — so mandatory clue tokens and available actions are enumerated values the assembler and core bind to, keeping them deterministic and injection-safe rather than stringly-typed.
- [x] Implement the loader + typed models in `shared/`; **malformed, unknown-`schema_version`, or checksum-mismatched manifests fail fast** with an actionable error on the 0.7 error taxonomy, never loading partially.
- [x] **Decode untrusted input defensively**: enforce total-size, nesting-depth, and per-field caps *before* typing, and reject anything over budget — so the resource-exhaustion guard the Phase 4/6 external-manifest path needs exists from the first loader, even though the PoC content is bundled and trusted.
- [x] Apply the **0.8 wire-compatibility rule to unknown fields**: a known-`schema_version` manifest carrying an unrecognised additive field loads (ignoring the unknown field) rather than failing, so a newer bundled case degrades safely on an older build — the compatibility contract Phase 4.1 relies on.
- [x] **Verify the `content_checksum` on load** (integrity) and reject on mismatch — the local, unsigned precursor to the Phase 4.4 signed-manifest verify path, so the trust seam exists before the network does. *(Cryptographic signing + key custody are deferred to Phase 3/4; here we verify against the embedded checksum only.)*
- [x] Resolve the **bundled-sample location + any tunable caps through the config authority** (0.2) — the PoC case ships as a small committed asset (0.1 large-binary policy: JSON is fine to commit; only the model is fetched), its path and limits never hard-coded.
- [x] Seed the **`memory_class` field** (stateless vs persistent) now — the PoC case is **stateless** (no history envelope) — so the discipline exists before Phase 4.1 / 5.2 depend on it.
- [x] Keep the schema **whitelisted (enums + bounded numbers over free text)** and insert any model-facing prose through a **template-isolation seam** (0.12): the PoC manifest is trusted/bundled, but the injection-defense *shape* is established now, not retrofitted at Phase 6.
- [x] Split **core-facing tokens from player-facing copy**: `core/` consumes stable tokens/keys only (0.11 core-purity + 0.8 determinism); player-facing manifest text (case title, display name) carries localization keys the presentation layer resolves, never raw localized prose.
- [x] **Validate that every player-facing localization key resolves** against the 0.11 string catalog at load (a missing key fails the loader test), so the token/copy split is enforced mechanically, not merely declared.
- [x] Author one hand-authored sample case drawn from the **fictional-taxonomy registry** (0.12) that **passes the content-integrity gate** (no real DSM/ICD label or drug brand) — the first real content the CI lint checks.
- [x] Provide a small **`tools/` manifest validator** that runs the same loader + content-integrity lint headlessly, so a case author (and CI) gets the identical accept/reject verdict without launching the app — reusing the single loader implementation (0.1), not a second copy of the rules.
- [x] **Unit-test the loader + schema** (tests move with code): canonical round-trip is byte-identical, a malformed / unknown-version / checksum-mismatch manifest is rejected, and a **golden fixture** (0.5 / 0.8) pins the sample so a schema change flips it red.

### 1.3 — Prompt assembler (pure, token-budgeted, tiered)

**What.** Implement the §6 prompt assembler as a pure function
`assemblePrompt(SimState, Manifest, ConversationWindow, tokenBudget) → String`
with the C-7 tiered structure (Tier 1 never truncated, Tier 2 capped, Tier 3 reserved).

**Why.** The token budget is a PoC exit gate (C-7); the assembler must be
verifiable without running the model, and it is the enforcement point for both
the budget and the prompt-injection isolation contract.

**How.** Guarantees the model never receives an over-budget prompt and that clue
tokens survive — the spine of the sim-core/dialogue contract.

**Validation.** Golden-fixture unit tests prove tier truncation order, that the
budget is never exceeded for the worst-case manifest, and that clue tokens
survive (load-bearing logic per Principle 4).

- [x] Implement the tiered assembler as a **pure, deterministic** function in `core/` (0.8 — no wall-clock, no ambient randomness), matching the C-7 signature.
- [x] Source the **model's real tokenizer** through the `shared/` inference service so token counting matches llama.cpp exactly — a budget enforced against an approximate counter is not enforced; **cache the tokenizer handle** and count off the UI isolate so per-turn budgeting is cheap (0.9).
- [x] **Apply the model's chat template** (from the GGUF metadata or a config-pinned template) inside the assembler so the roleplay frame is emitted in the exact turn format the instruction-tuned model expects — a wrong or missing chat template silently wrecks the 1.6 acting-quality gate even when the token count is within budget.
- [x] **Treat the tokenizer + chat template + stop tokens as model-specific**: Qwen2.5, Phi-3.5-mini and SmolLM2 tokenize differently and expect different chat frames, so the assembler resolves the *active* model's tokenizer/template/stop set through config and never hard-codes one — and the 1.6 worst-case budget is therefore measured **per candidate model**, not once (correcting a single-tokenizer assumption).
- [x] **Version the system / roleplay-frame template with the `ruleset_version`** (0.7): it is model-facing content, not user-facing copy, so it is pinned and reproducible rather than localized — a frame change is a tracked ruleset change, not an invisible tweak.
- [x] Emit a **byte-stable Tier-1 prefix** (deterministic field ordering, T1 assembled before T2/T3) so the fixed prefix is identical turn-to-turn — enabling the 1.1 KV-cache/prefix reuse rather than re-encoding the frame every turn (performance contract, not just correctness).
- [x] **Own the sliding conversation-window structure** and its length `N` (resolved through config): the assembler *consumes* it and the session loop (1.5) *maintains* it, and the assembler never mutates it — preserving the pure-function contract.
- [x] Enforce `tokenBudget` with the C-7 tier-ordered truncation (T2 conversation window → T2 digest; **never** T1 or T3) and reserve generation headroom; the budget value resolves through the **config authority** (0.2), not a literal. If **T1 alone exceeds budget**, fail loudly (a manifest-schema defect, per C-7) rather than silently dropping clue tokens.
- [x] Implement the **history-digest compiler** — a fixed-token structured summary (prior style, trust trajectory, medication history, key outcomes), never raw deltas — deterministic for a fixed input.
- [x] Establish **template-level isolation** so manifest/history strings are inserted as data and can never be read as instructions (0.12) — the assembler is the injection-contract enforcement point.
- [x] **Prove injection isolation with an adversarial test**: a hostile manifest/history string (an injection payload) is emitted strictly as T2/T3 *data* and cannot alter or displace the T1 frame or the clue tokens (0.12) — the guarantee is tested at the enforcement point, not assumed.
- [x] Unit-test with **golden fixtures** (0.5 / 0.8): budget compliance for the worst-case full manifest, T1 integrity, clue-token survival, and truncation order — all independent of the model.
- [x] Add a **property-based / fuzz test** (0.5) over randomized manifests + conversation-window lengths proving `output ≤ input_budget` and T1 integrity hold across the input space, not just the hand-picked golden examples.

### 1.4 — Simulation core vs dialogue layer split

**What.** Implement the deterministic core that resolves one turn (approves
context, emits mandatory clue tokens) and hands only approved content to the model.

**Why.** §4: the model voices dialogue, it never decides outcomes. This split is
what makes the game fair, testable, and — via structured deltas — the shape the
Phase 3.3 receipt later validates.

**How.** Cements the authority boundary the entire design depends on, and is the
first real exercise of the 0.8 determinism contract.

**Validation.** Given a fixed state + action + seed, the core produces a
byte-identical outcome and prompt context across two runs; the model output
changes nothing mechanical.

- [x] Implement the deterministic turn resolver in `core/` (no I/O, no model calls) on the **0.8 seeded-RNG + injected-clock seam** — fixed state + action + seed → identical outcome.
- [x] **Define the minimal PoC action set** the resolver handles — a small fixed set drawn from the manifest's interaction-pattern enum (1.2) — so there is a concrete turn to resolve and score, foreshadowing the Phase 2.1 card taxonomy without building it.
- [x] Define the **structured-delta schema in `packages/`** (0.8 canonical serialization) as the local, pre-server precursor of the Phase 3.3 receipt shape, so Phase 3 extends it additively; deltas carry the **0.8 fixed-point money/ratio type** even in the PoC so no platform float leaks into `core/`.
- [x] **Tag each resolved turn's delta with the `ruleset_version`** (0.7) so an outcome is replayable against the exact rules that produced it — the local, pre-server precursor of the Phase 3.3 receipt's `ruleset_version` pin, and distinct from the manifest's `schema_version` (1.2).
- [x] Emit outcomes as **structured deltas** (never transcripts) and enforce the 0.6 **"no raw transcript reaches a durable store"** rule even in the local-only PoC. *(⏭ hardened later: the transcript-blocking test/lint becomes a CI gate in 0.6/Phase 2.)*
- [x] Apply each turn **transactionally**: a cancelled or failed generation (1.1) rolls the turn back so core state is never half-applied — the reliability guarantee the streaming/cancellation path depends on.
- [x] Route mandatory clue tokens into the prompt and **validate their survival post-generation with a bounded regeneration loop then a templated fallback** (§4): retry at most `K` (config) times, then emit the deterministic templated line — so a forgetful model degrades to fixed text instead of looping or silently losing a clue.
- [x] **Treat refusal / empty / safety-boilerplate output as a first-class outcome**: the core detects an empty generation, a model refusal, or a canned safety disclaimer (small instruct models balk at mature/manipulative content, tied to [C-6](../specs/AGE-RATING-AND-CONTENT-STRATEGY.md)) and routes it through the same bounded-regeneration → deterministic templated-fallback path as a missing clue — so a turn degrades to fixed text, never a blank or broken exchange (reliability).
- [x] **Sanitize model output before it reaches the UI**: enforce a max length and reject/strip any echoed system-frame text or clue-token control markers, so the model can never leak the prompt frame or inject control tokens into displayed dialogue (integrity of what is shown).
- [x] Keep **all** model interaction behind the `shared/` inference service; `core/` never imports the FFI layer (Principle 2 + the 0.2/0.9 boundary).
- [x] Unit-test the split, including a **property-based determinism test** (0.5) across seeds/states: a fixed state + action yields a byte-identical outcome and prompt context, and no model output alters anything mechanical.

### 1.5 — End-to-end session loop

**What.** Wire the full path: Flutter UI → load case → compose prompt from sim
state → local inference → render dialogue back into the session view — the first
playable vertical slice.

**Why.** §1's explicit PoC definition; a single connected flow is the milestone,
and it is where the 0.9 client architecture (GetX DI, off-isolate concurrency,
crash recovery) and the 0.11 a11y/i18n baseline first prove out.

**How.** Produces the vertical slice the exit gates measure, on the shipped
conventions rather than throwaway wiring.

**Validation.** A player opens a case and exchanges several turns on Linux +
Android emulator; the UI streams tokens without frame stalls, and a
backgrounded/killed session relaunches into a consistent state.

- [x] Build the minimal session UI (case view, **structured card/choice action selector — never a free-text prompt box (§4, 0.12)**, **streaming** dialogue render) with **no hard-coded strings** (0.11 externalization) and the **a11y baseline** (semantic labels, scalable text, contrast) — keeping the direct prompt-injection channel closed from the first slice.
- [x] Establish the **typed navigation/routing** convention (0.9) for the launch → case-select → session flow, with the deep-link seam stubbed for the C-5 desktop OAuth callback (no server in Phase 1).
- [x] Wire UI → sim core → prompt assembler → inference → render through **GetX dependency injection** (0.9 / [DECISION 0016](../project/DECISION_LOG.md)) — the config authority and inference service are injected, never global singletons.
- [ ] Keep inference **off the UI isolate** and **stream tokens** into the view so perceived latency stays low and the frame loop never stalls (0.9).
- [x] **Lock the action selector during generation and expose a user stop/cancel control** wired to the 1.1 cancellation path — so a player cannot race two turns (double-submit) and can abort a slow generation without killing the app (reliability + UX).
- [x] **Own the sliding conversation-window + delta-log accumulation** across turns, and **reset the KV cache + sim state on new-case / session reset** (1.1) so a fresh case never inherits stale context — the client-side half of the 1.1 KV lifecycle.
- [ ] **Surface the 0.7 error taxonomy in the UI**: model load / OOM / cancellation / generation errors render as actionable, localized states, and offline is shown as a first-class state — never a silent hang.
- [x] Give the first-run model fetch a **progress + deferrable UI** (pause/resume, metered-connection posture per 0.10) so the download-acceptance gate (1.6) measures a real user path, not a blocking spinner.
- [x] Honour **reduce-motion and input alternatives** (0.11) for the streaming render and action input, so the distinctive UI stays reachable from the first slice.
- [x] Propagate a **single correlation/session id** across the Dart client and the C++ FFI layer for the whole turn (0.7) so the loop is debuggable without persisting any transcript.
- [ ] Implement **app-lifecycle / crash-recovery** (0.9): the full session — **sim state + conversation window + delta log + correlation id** — is durably checkpointed at each turn boundary so a backgrounded, OS-killed, or crashed session relaunches into a consistent state with **no lost or double-applied turn**, exercising the durable local-state seam (no server yet).
- [ ] Confirm the loop is **fully local/offline** (no server dependency in Phase 1) and that the same build path runs on Linux desktop and the x86 Android emulator. *The Android multi-arch APK builds and launches on the x86 emulator with no server calls; the Linux desktop runtime is exercised by `flutter test` loading the native `.so`. The `flutter build linux` packaging step is blocked by missing `clang++`, `ninja`, and `pkg-config` in this environment.*

### 1.6 — PoC exit-gate measurement

> **Current execution boundary:** Physical minimum-spec testing needs available hardware and the human device-testing gate. Full-context, quantization and download harness work continues locally; emulator/desktop numbers do not complete mobile thermal, battery or memory-pressure acceptance.

**What.** Instrument, measure, and record the four falsifiable gates — acting
quality, prompt token budget, download acceptance, device viability — and state
the go/revisit decision before any Phase 2 spend.

**Why.** §1 is explicit: "it produced text" is not a pass. A gate that is not
instrumented cannot be measured, and a red gate means the architecture (or the
model tier) is revisited *before* further spend.

**How.** Converts the PoC from a demo into a recorded, reproducible de-risking
decision point.

**Validation.** All four artifacts are recorded in `docs/reports/` under a PoC
exit-report template with the decision stated; device viability is explicitly
marked **pending** until the human opens physical-device testing.

- [x] Wire **local measurement instrumentation** on the 0.7 metrics contract (timers/gauges: tokens/sec, inference latency, peak RAM, cold-start, frame budget) into the FFI layer and the loop — you cannot measure a gate you did not instrument.
- [x] Build a **headless reproducibility harness** that runs the core → assembler → inference path with no UI under the fixed seed + greedy decode, so the token-budget and determinism artifacts are reproducible in CI and the harness is reusable by the Phase 2.8 solvability bots and Phase 4.3 validation (0.1 single-core-implementation rule).
- [x] **Take N samples per metric and report the distribution (median + p95), never a single shot** — a one-shot number hides warm-up outliers and thermal variance and is not a defensible gate.
- [x] Measure **acting quality for both the Tier A primary and the Phi-3.5-mini comparator** ([DECISION 0015](../project/DECISION_LOG.md)) under a worst-case full-manifest prompt against a **written rubric** (in-character, honours clue tokens, respects style archetype, no rule-breaking), recorded with the fixed seed (0.8) so the sample is reproducible and the final pick is evidence-based. *Measured in `app/test/poc_gate_exit_report_test.dart` under greedy decode: with the versioned roleplay frame (system instruction + few-shot exemplars, `packages/psycore/lib/src/roleplay_frame.dart`) **both Qwen2.5-1.5B and Phi-3.5-mini pass 5/5** on a rubric that judges acting (first-person voice, no frame-token leak, no listicle, no clinical advice). Before the frame both failed (Qwen emitted a listicle; Phi leaked frame tokens).*
- [x] If acting quality **fails the rubric**, escalate along the fixed ladder — **prompt/few-shot exemplars → grammar-constrained decoding (llama.cpp GBNF) → one-time offline LoRA fine-tune (merged to fixed shipped weights) → model-tier bump** — *before* Phase 2 spend, per [DECISION 0018](../project/DECISION_LOG.md); runtime/continuous training stays out of scope (§18, [ARCHITECTURE](../code/ARCHITECTURE.md) §7). The sim core owning all mechanics (1.4) is the safety net that lets prompting-first be the baseline. *Exercised: rung 0 (roleplay system prompt + few-shot exemplars, `packages/psycore/lib/src/roleplay_frame.dart`) was sufficient — both models pass the acting rubric with no GBNF/LoRA/tier bump needed. The GBNF seam remains wired (1.1) as the next rung if a future case regresses.*
- [x] **Measure each candidate model's refusal / safety-boilerplate rate** on the mature-content prompts against the acting rubric (1.4) — a real failure mode for small instruct models — feeding the [DECISION 0018](../project/DECISION_LOG.md) escalation ladder before Phase 2 spend. *Measured in `app/test/poc_gate_exit_report_test.dart`: Qwen2.5-1.5B refuses 3/3 mature probes.*
- [ ] Record the **prompt token budget** (C-7): chosen model's advertised max, measured usable factor, and worst-case token count vs `input_budget` with reserve — feeding back to the manifest schema (Phase 4.1) if T1 overflows. *Measured: 77 input tokens vs 1792 usable (2048 `n_ctx` − 256 output reserve).*
- [ ] **Record the quantization tradeoff** (e.g. `Q4_K_M` vs a smaller/larger alternative): quality-vs-size-vs-speed for the chosen quant, so the shipped quantization is an evidence-based pick rather than an assumption (feeds the 0.1 pinned build input). *Only `Q4_K_M` weights are present on disk; other quants were not downloaded.*
- [x] **Measure the prompt-prefix KV-cache reuse benefit** — per-turn latency and tokens processed *with* vs *without* T1-prefix reuse (1.1/1.3) — so the performance contract is validated rather than assumed and a regression here is visible. *Measured: cold first-token latency ~585 ms, warm (prefix-cache-reuse) first-token latency ~0 ms.*
- [ ] Implement + measure the **download-acceptance** path: the 0.10 resumable, deferrable, metered-connection-aware first-run fetch of the bundled GGUF, with its retry strategy and a recorded acceptance method. *The fetch UI exists but was not instrumented or user-tested in this pass.*
- [x] **Record packaged binary + model-download size per platform/ABI** (`arm64-v8a`, `x86_64`, desktop) so the download-acceptance and binary-size budgets are real per-target numbers, not a single blended figure. *Multi-arch APK is 62.0 MB (includes `arm64-v8a`, `armeabi-v7a`, `x86_64`). Model download sizes: Qwen 1.1 GB, Phi 2.3 GB, SmolLM2 1.0 GB. Linux desktop binary-size packaging is blocked by missing toolchain.*
- [x] Record the **device-viability** method + the Tier B (SmolLM2 1.7B) fallback plan against the [DEVICE-SPEC](../specs/DEVICE-SPEC.md) floor — peak RAM within budget and tokens/sec above the playability threshold — **physical-device measurement gated on human sign-off** (kept explicitly *pending* until then). *Method documented in `docs/reports/phase-1-exit-report.md`; desktop peak RSS ~3.75 GB. Physical-device measurement remains pending.*
- [ ] Measure **sustained throughput under thermal load**: a multi-turn run on mobile (not a single cold shot), recording whether tokens/sec collapses under throttling — the real playability risk on minimum-spec devices. *Requires physical device; not measured.*
- [ ] Record **warm vs cold first-token latency** separately (the 1.1 warm-up pass) and a **rough per-turn energy/battery draw** on mobile against a budget, so playability accounts for the second turn and the battery cost, not just the first token. *Cold/warm first-token latency measured on Linux desktop; mobile energy/battery draw requires physical device.*
- [x] **Record the greedy-decode reproducibility scope explicitly**: byte-identical on the same build + architecture + pinned thread count, with the expected x86-emulator-vs-arm64-device divergence (float matmul) documented — so the determinism artifact is not misread as a bug and Phase 2/3 replay expectations are correctly scoped. *Verified byte-identical on same Linux build; cross-architecture divergence documented.*
- [ ] Record the **0.7 performance-budget baselines** vs their targets (cold-start, tokens/sec + latency, peak RAM vs the DEVICE-SPEC ceiling, frame budget, binary size incl. model delivery) and confirm the app **survives OS memory pressure** on a minimum-spec device (the 0.9 rule). *(⏭ hardened later: any telemetry/crash collection stays local-only here; the opt-in, privacy-scrubbed pipeline is built in 0.7/Phase 6.6.)* *Partial: cold-start, first-token latency, prefix-cache reuse, and APK size recorded; peak RAM ~3.75 GB on desktop is above the 4 GB floor before model delivery and needs physical-device validation.*
- [x] **Run a prompt-injection / template-isolation smoke test as a recorded gate**: feed a hostile manifest/history string end-to-end and confirm it neither alters model behaviour nor leaks the T1 frame (0.12 / 1.3) — the injection-defense contract validated through the running loop, not only in unit tests (integrity). *Passed in `app/test/poc_gate_exit_report_test.dart`.*
- [x] Record all artifacts in `docs/reports/` under a **PoC exit-report template** and state the **decision gate explicitly**: any red gate revisits the architecture (or drops to Tier B) before Phase 2 spend — "it produced text" is not a pass (§1). *Recorded in `docs/reports/phase-1-exit-report.md`.*

---

## Phase 2 — Deterministic Game Core (offline)

**Goal.** Build the real, offline, single-player game — the "Lane A" mechanics
the audit found ready today: the four-type card taxonomy, the capped loadout,
deterministic session resolution with a typed state model and fictional
pharmacology, the multi-session siege and clinical grading, progression and the
multi-currency economy, financial recovery, the clinic-operations layer with a
local case router, a durable offline career save, and the accelerated balance
sandbox that tunes it all.

**Scope id.** `phase-2`

**Why now.** These systems are client-only and depend on nothing server-side, so
proving the game is *fun* offline validates the product before any networking
spend. This is also the **first heavy exercise of the Phase 0 integrity
foundations under real game logic**: deterministic fixed-point economy math
(0.8), the seeded-RNG + injected-clock seam (0.8), the config authority as the
single owner of every balance constant (0.2 + [C-4](../specs/BALANCE-SPEC.md)),
the local-persistence seam (0.9), the module-boundary map (Principle 2), the
content-integrity gate over a much larger case pool (0.12), and the **session
rule model** ([C-11](../specs/GAME-RULES.md)) authored up front so the mechanics
are a reviewable design before they become `psycore` code.

> 🧩 **Build order & dependencies (read before picking up a sub-phase).** The
> sub-phases are numbered by topic, not by strict build order (as in Phase 1).
> **The determinism substrate (2.0) goes first, before any game rule** — the
> Phase 1 PoC shipped a *stand-in* PRNG and seed derivation that are **not**
> byte-identical across architectures (see the determinism note below), so 2.0
> replaces them and every later rule is built on the hardened substrate. The
> deterministic spine follows: the typed session state + outcome engine (2.3)
> and the offline persistence/profile seam (2.9) are **foundational and stood up
> early**, because the card taxonomy (2.1), loadout (2.2), progression (2.5),
> recovery (2.6), and clinic economy (2.7) all mutate state that must resolve
> deterministically and survive a restart. The balance sandbox (2.8) is numbered
> last but is **infrastructure that depends on 2.1–2.7 existing** — it cannot
> tune constants for systems that are not built — and it runs on the **2.0
> core-only run path**, *not* the LLM-coupled Phase 1.6 app harness
> ([`app/lib/shared/headless_harness.dart`](../../app/lib/shared/headless_harness.dart),
> which imports `dart:io` + the inference service): the single deterministic
> core is reused (0.1 single-core rule), but the headless *driver* is extracted
> so bots run with no Flutter, no I/O, and no model binary present. Suggested
> order: **2.0 → 2.3 + 2.9 → 2.1 → 2.2 → 2.4 → 2.5 → 2.6 → 2.7 → 2.8 → 2.10** —
> with the **2.10 offline case corpus authored up *alongside* 2.3–2.7** (2.4's
> siege loop and 2.8's balance tuning both need real cases to run on), and the
> **Phase 2 exit report (2.10) closing the phase** the way 1.6 closed the PoC.

> 🎯 **Determinism & economy integrity (carried from 0.8).** Every rule in this
> phase lives in the pure `packages/psycore` core: **no wall-clock, no ambient
> randomness, no platform float**. ⚠️ **The Phase 1 PoC does not yet satisfy
> this**: its `SeededPrng` wraps `dart:math`'s `Random` (an implementation-
> defined sequence that is *not* stable across architectures or SDK versions),
> its per-turn seed mixes in `Clock.nowMillis()` and per-isolate-randomized
> `String.hashCode` (so a replay at a different time or on a different isolate
> diverges), and it exposes a float `nextDouble()`. **2.0 replaces all three**
> with a specified, portable integer PRNG (fixed-width wrapping arithmetic,
> pinned to `ruleset_version`) and a pure seed-derivation function over stable
> fields only — *this is the precondition for the "byte-identical across
> architectures" claim, not something the PoC already delivers.* After 2.0, all
> randomness flows through that PRNG using **integer draws only**; every
> time-dependent rule (Postponing multi-session decay §16, recovery-window
> cooldowns §23, tax weeks and audit cadence §22, reputation recency-weighting
> §10) reads the **injected, server-reconcilable clock** (0.8 authoritative-time
> seam), and the device clock is treated as untrusted so a player cannot advance
> a cooldown or dodge a tax by changing it. Every currency, multiplier, and
> percentage (§9, §14, §22, §24) is the **deterministic fixed-point money/ratio
> type** (0.8) with a **single documented rounding mode**, so rounding can never
> mint or destroy currency (a ledger-conservation invariant, property-tested);
> config percentages arrive as `double` at the config boundary and are converted
> to fixed-point ratios **once, at the config→core seam** — no float
> multiplication ever happens inside a deterministic rule. Each balance constant
> resolves through the **config authority** (0.2) sourced from
> [C-4](../specs/BALANCE-SPEC.md), never hard-coded in a feature.

> 🔗 **Everything here is the local precursor to a server system — build the
> shape now.** The offline game is single-player and trusted, but it must be
> *shaped* so Phase 3 wraps it additively rather than reshaping it: the
> structured deltas (2.3) carry the start state + ordered actions + claimed
> deltas + `ruleset_version` the Phase 3.3 receipt validator will bound-check;
> the offline career profile (2.9) is the atomic-metric precursor to the Phase
> 3.2 authoritative profile; the local case lifecycle (2.3) is the offline
> stand-in for the C-8 / Phase 3.6 server-arbitrated state machine; and
> operational pressure and Doubt (2.6/2.7) are computed locally now but are the
> client-visible half of the server-derived quantities ([C-9](../specs/SERVER-DERIVED-QUANTITIES.md)
> / Phase 5.5). **No raw transcript is ever persisted** (0.6), even offline.

> 🔒 **Security posture (convention now, enforced at prod).** Per
> [DECISION 0017](../project/DECISION_LOG.md), Phase 2 *uses* the security
> conventions without standing up the enforcement machinery. Where a bullet
> touches the offline save at rest or a backup/export path it **declares** the
> posture (platform secure-storage for the save, a local backup/export policy,
> save-file integrity checks) so Phase 3/7 add custody, server-side backup/DR,
> and secret management without a retrofit; none of it blocks the offline build.

**Validation.** A full offline career loop is playable end-to-end — curate a
loadout, run multi-session cases with the four card types and fictional
pharmacology, earn XP/study/reputation, buy and operate a clinic, recover from
near-bankruptcy — and **survives an app restart** (and a simulated mid-write
kill) from the durable save with no lost or double-applied progress; every
outcome is a **byte-identical deterministic replay** for a fixed state + action
+ seed *across architectures* on the hardened 2.0 substrate, pinned by a
checked-in golden replay fixture (0.8); the economy runs entirely on
**fixed-point money** with no float in `core/`, and a **ledger-conservation**
property test proves rounding never mints or destroys currency; every balance
constant loads from **config** (a hard-coded balance literal in a feature fails
review); the balance **sandbox runs thousands of bot sessions headlessly on the
2.0 core-only run path — no LLM, no Flutter, no model binary present** (§2.2) —
and reports sources/sinks/inflation/dead-currency plus mechanical-solvability
metrics as distributions (median/p95); load-bearing logic (the PRNG + seed
derivation, card resolution, economy math, reputation, the resolver) is covered
by unit + property-based tests that move with the code; every offline case,
fictional drug, encyclopedia entry, and study field passes the
**content-integrity gate** (no real DSM/ICD label or drug brand, 0.12); and the
phase closes on a **recorded balance/solvability exit report** (2.10, the offline
analog of 1.6) that states an explicit go/revisit decision before any Phase 3
spend — "the systems compile" is not a pass.

### 2.0 — Deterministic core substrate hardening

**What.** Replace the Phase 1 PoC's stand-in determinism primitives with the
production substrate every Phase 2 rule depends on: a specified portable PRNG, a
pure seed-derivation function, the extended fixed-point money/ratio type with a
documented rounding mode, an enforced float ban in `core/`, **one shared
canonical serializer** every `packages/` schema encodes through, a
**fully-injected clock seam** (authoritative time + a real advancing monotonic
source), and an extracted **core-only run path** (no I/O, no inference) that the
sandbox (2.8) and Phase 4.3 drive.

**Why.** Phase 2's entire validation rests on "byte-identical replay across
architectures", but the PoC cannot deliver it: `dart:math`'s `Random` is
implementation-defined, the per-turn seed mixes in the clock and
per-isolate-randomized `String.hashCode`, and the economy type lacks the
ratio/division math taxes and multipliers require. **A code audit surfaced two
more holes the "0.8 done" checkbox hides.** First, the canonical-serialization
contract is only actually implemented for `PatientManifest`: `SessionReceipt`,
`StructuredDelta`, `SimState`, and `TurnOutput` mix `snake_case` and `camelCase`
*within the same serialized tree*, carry no canonical byte encoder, and the
key-sorting helper is copy-pasted in three places — so the golden replay fixture
and the Phase 3.3 cross-boundary receipt check would be validating
non-canonical bytes. Second, the PoC `InjectedClock` **reads `DateTime.now()` in
its constructor** (a wall-clock leak the purity gate must catch) and its
`monotonicMillis()` returns a **constant that never advances** (so the 2.6
recovery cooldowns cannot measure elapsed time). Fixing all of this *after* card,
economy, and save logic exist would invalidate every golden fixture and every
persisted receipt. It is cheapest — and only correct — to harden the substrate
first.

**How.** Turns the determinism / economy-integrity contract from an aspiration
into a mechanically enforced foundation the other eight sub-phases build on
without re-deriving it.

**Validation.** A fixed (state, action, seed) replays byte-identically across
x86 + arm64 and two SDK versions; **every `packages/` schema round-trips through
the one shared canonical serializer with a single key-casing convention and
byte-identical output**; a property test proves ratio math conserves currency; a
lint fails any `double` / `Random` / `DateTime` / wall-clock read, any
output-affecting unordered-collection iteration, or any mutable static on a
`core/` path (so the same code fans out safely across sandbox isolates); the
core-only harness runs a full case with no Flutter, no `dart:io`, and no model
binary present.

- [x] Replace `SeededPrng` with a **specified, portable integer PRNG** (a documented algorithm — e.g. SplitMix64 / PCG — using explicit fixed-width wrapping arithmetic, not `dart:math`'s implementation-defined `Random`), exposing **integer draws only** (no `nextDouble` on the core path); pin the algorithm + its constants to the `ruleset_version` registry (0.7) so any change is a tracked ruleset bump, not a silent replay break.
- [x] Define a **pure, deterministic per-turn seed-derivation function** over *stable* inputs only (case id, turn index, ordered action, root session seed) via a stable content hash — **never** `Clock.nowMillis()` and **never** `String.hashCode` (which Dart randomizes per isolate) — so a replay at any time, on any isolate, on any architecture reproduces the identical stream. This corrects the PoC `TurnResolver` seed (`state.seed ^ action.name.hashCode ^ manifest.id.hashCode ^ clock.nowMillis()`).
- [x] Extend the **fixed-point money/ratio type** (`FixedPoint`) with the operations the economy needs — multiply-by-ratio, divide, and percentage application — each with a **single documented rounding mode** (e.g. round-half-to-even) and a **saturating / overflow-checked** backing so a large tax or multiplier can never silently wrap; unit-prove the **ledger-conservation invariant** (no value minted or destroyed by rounding).
- [x] Establish the **config→core numeric seam**: the percentages and rates that live as `double` in `BalanceConfig` (e.g. `misfortuneRollPercent`, `doubtTransferBasePercent`, `discountPracticeXpPenaltyPercent`) become **integer basis points** (or a documented exact decimal→fixed-point conversion) resolved to fixed-point ratios **once, at the boundary** — closing the `FixedPoint.fromDouble` float-multiply hole (`value * scale`), so no `double` and no float multiplication ever enters a deterministic rule and a non-representable config value like `0.1` cannot perturb a replay.
- [x] Establish **one shared canonical JSON serializer** in `packages/` (deterministic key sorting, a **single `snake_case` convention**, and stable number/string/enum encoding) and migrate **every** schema onto it — `PatientManifest` (folding in its private `_sortedIntMap`), `SessionReceipt`, `StructuredDelta`, `SimState`, `TurnOutput` — deleting the **three duplicated** sort helpers (`manifest_loader._sortedJson`, `manifest._sortedIntMap`, and the in-test copy); add a **contract test** that every schema shares the one casing convention and round-trips byte-identically, because the golden replay fixture below and the Phase 3.3 cross-boundary receipt check are only trustworthy if `core/`'s serialized output is genuinely canonical (today only the manifest is).
- [x] Add a **`core/` purity gate** wired into CI (0.5): fail the build if `dart:math` `Random`, a `double` literal/type, any `DateTime` / wall-clock call, **output-affecting unordered `Map`/`Set` iteration**, or **mutable top-level/static state** appears on a deterministic code path in `packages/psycore` — closing the holes the PoC left open by convention only and guaranteeing the core is **isolate-safe** so the 2.8 sandbox can fan it across isolates without shared-state races.
- [x] Harden the **clock seam**: replace the PoC `InjectedClock` — which **reads `DateTime.now()` in its constructor** (a wall-clock leak the purity gate would flag) and whose `monotonicMillis()` returns a **constant that never advances** — with a fully-injected authoritative clock plus a **real, advancing monotonic source** the harness and app drive explicitly, so replay stays time-independent and the 2.6 cooldowns can actually measure elapsed local time (the device clock stays untrusted, 0.8).
- [x] Extract a **pure core-only run path** — a headless driver in `packages/psycore` (or a thin `tools/` entry) that resolves a full case from (manifest, loadout, seed, scripted actions) with **no inference, no `dart:io`, no Flutter** — distinct from the LLM-coupled [`headless_harness.dart`](../../app/lib/shared/headless_harness.dart); both drive the *same* single core (0.1), but only this path is usable by 2.8 bots and Phase 4.3 solvability in CI without the model binary.
- [x] Commit a **cross-architecture golden replay fixture** (0.5 / 0.8): a canonical (state, action, seed) → serialized outcome vector that CI verifies byte-for-byte, so any accidental reintroduction of nondeterminism (float, unstable hash, clock leak) flips a test red rather than surfacing as a rejected receipt in Phase 3.

### 2.1 — Card taxonomy & signature principle

**What.** Implement the four card types (Disclosing, Relatable, Postponing,
Manipulative) with context-dependent, signature-biased effects (§16), replacing
the Phase 1 PoC `InteractionPattern` stand-in with the production taxonomy.

**Why.** The card system is the tactical heart of the game, and the signature
principle — a card is strong and predictable in-context, weaker and less stable
out-of-context — is what makes reading the scene matter more than memorizing a
deck.

**How.** Everything in the session loop is expressed as card plays against
deterministic state; the four types are the vocabulary every later mechanic
(loadout, siege, grading, sandbox) speaks.

**Validation.** Each type produces its signature effect in-context and a
measurably weaker/less-stable effect out-of-context; Manipulative resolves
three-way by trust state; a fixed state + card + seed replays byte-identically.

- [x] **Design the card-resolution rule model in [C-11 GAME-RULES](../specs/GAME-RULES.md) before implementing** — pin the context-fit inputs, the signature-biased band-function *shape*, and the Manipulative three-way partition (all numbers deferred to C-4), so the taxonomy is reviewed as a written design, not reverse-engineered from `psycore` code (documentation-first).
- [x] **Reconcile the PoC `InteractionPattern` enum with the four card types**: define the production card model in `psychemas`/`psycore` so the six PoC patterns (1.2/1.4) become card *instances* tagged with their type + signature, and evolve the manifest `interactionPatterns` contract **additively** (0.8 wire-compat) so PoC content still loads and the transition is not a schema break.
- [x] Implement the four card types and their **context-bias resolution** in pure `packages/psycore` using the **2.0 portable PRNG (integer draws only, no float)**: a signature-aligned play resolves strongly and predictably; a mismatched play still functions but with a wider, less favourable outcome band drawn deterministically from the seed.
- [x] Implement **Manipulative three-outcome resolution** (success / partial / derangement) keyed to trust state, thresholds from config (C-4); a low-trust failure proposes the **derangement mutation as a bounded, *enumerated/whitelisted* structured delta** (§16) — a selection from a fixed catalogue of secondary-pathology states, **never free text and never an in-place manifest rewrite** — so it stays injection-safe (0.12) and the Phase 3.3 receipt / Phase 5.3 trauma multiplier can bound-check it later.
- [x] **Type each resolved play into the structured delta** (2.3): record the card type, signature, and computed context-fit as enumerated fields so the receipt's ordered-action list is machine-checkable by the Phase 3.3 validator and readable by the 2.4 grading report — never a free-text move log.
- [x] Implement **Postponing tempo control**: the config-tuned 1–2 turn freeze, plus the **multi-session decay modifier** (§16) that raises baseline starting agitation across sessions — **accrued per Postponing play and carried in the case-history envelope** (bounded by a config cap so cases stay winnable), not clock-driven — so a stalling player pays a growing, deterministic price.
- [x] Implement the **Transference Spike** reclassification (§16): in high-trauma states, Relatable plays resolve programmatically as Manipulative failures, flipping the required tactic — driven by core state, never the model.
- [x] Expose the **Linguistic Vector / style-filter hook** (§16 AI-fatigue countermeasure): the resolved card + patient `styleArchetype` shift the prompt-assembler frame (1.3) so identical mechanics sound distinct, without letting the dialogue layer change any outcome (§4 boundary).
- [x] Implement the **card aesthetic-variety presentation hook** (§16): a card's surface form (full-sentence prompt, compact phrase, symbolic/coded cue) is resolved in the presentation layer from its type token and honours the 0.11 a11y contract — the deterministic core resolves on **type + signature only**, so visual variety never shifts an outcome (§4 boundary).
- [x] Bind every card constant (trust bumps, freeze turns, decay rate, Manipulative thresholds) to the config `balance` group (0.2 + C-4) through the **2.0 config→core fixed-point ratio seam** for any percentage-like value; no card-number literal in a feature.
- [x] **Unit- + property-test** the taxonomy (0.5): signature-in-context beats mismatched-out-of-context across seeds; Manipulative's three outcomes partition cleanly by trust; determinism is byte-identical for fixed inputs.

### 2.2 — Therapy deck & loadout system

**What.** Implement the pre-session loadout with a hard active-slot cap, the
clinical preparation phase, and the focus/emotional-delivery controllers (§11).

**Why.** The slot constraint is what turns card collection into tactical choice —
equipping the wrong loadout must leave a measurable, readable gap, not a hidden
penalty.

**How.** Gates which cards enter a session, shaping every encounter; the prep
phase is where the player reads intake and commits to an approach before the
first turn.

**Validation.** Players curate a capped loadout from their library; a mismatched
loadout demonstrably fails a case the right loadout solves; the slot count comes
from config.

- [x] Implement the **card library + capped active loadout** in `app/lib/features/` (0.9 feature-module skeleton), slot count from config (C-4, 5–6); the cap **and card ownership** (only owned/unlocked cards are equippable) are enforced in the deterministic core, not only the UI.
- [x] Implement the **clinical preparation phase** (intake review → deck curation) so the player evaluates the initial manifest profile before committing a loadout.
- [x] Implement the **focus and emotional-delivery controllers** (§11 sliders: Childhood↔Workspace, Warm↔Objective) as typed core inputs feeding `SimState` — never free text, keeping the direct injection channel closed (0.12).
- [x] Make loadout gaps **measurable and readable**: a case whose defenses require an un-equipped card type is resolvable-with vs stuck-without, surfaced as a visible tactical gap (this feeds the §13 strategic-exit choices in 2.7).
- [x] **Capture the equipped loadout + controller settings in the session start-state** (the 2.3 receipt precursor) so the core rejects a play whose card is not in the loadout, and the Phase 3.3 validator can later reject any receipt whose ordered actions reference un-equipped cards — closing a receipt-forgery vector before the server exists.
- [x] Wire the loadout + controllers through **GetX DI** (0.9) and the **a11y / input-alternative contract** (0.11) so the card interface is reachable by keyboard/switch/pointer and honours reduce-motion.
- [x] **Unit-test** loadout enforcement (over-cap rejected; the core honours the cap) and that controller settings deterministically alter resolution inputs.

### 2.3 — Session resolution, state model & fictional pharmacology

**What.** Implement the typed deterministic state model (trustScore,
agitationLevel, activeDefense, medication effects, session progress), the
outcome engine (succeed / fail / stabilize / crisis), the local case lifecycle,
and the fictional pharmacology layer (§4, §16) — evolving the Phase 1 generic
`axes` map into the production shape.

**Why.** This is the authoritative outcome owner the model never touches; getting
the state shape, the delta/receipt precursor, and the money type right *here* is
what lets Phase 3.3 validate receipts and Phase 3.6 arbitrate the lifecycle
without reshaping the core.

**How.** Produces the structured deltas and case-state transitions every later
server system validates; it is the deepest exercise of the 0.8 determinism +
fixed-point contract.

**Validation.** Fixed inputs yield deterministic, byte-identical outcomes across
architectures; unit tests cover success/fail/stabilize/crisis and each lifecycle
transition; no float or transcript touches `core/`.

- [x] **Design the state model, outcome engine, and pharmacology model in [C-11 GAME-RULES](../specs/GAME-RULES.md) before implementing** — pin `SimState`'s typed variables + ranges, the succeed/fail/stabilize/crisis threshold *shape*, and the tolerance/dependency/side-effect model (all numbers deferred to C-4), so the authoritative outcome owner is a reviewable design before it becomes code (documentation-first).
- [x] **Evolve `SimState` from the PoC generic `Map<String,int> axes` to the typed model** (trustScore, agitationLevel, activeDefense, session progress, plus a **typed medication state** — prescribed fictional-drug tokens, dosage, accrued tolerance, dependency) while preserving the 0.8 determinism contract (bounded integers / fixed-point, the 2.0 PRNG, injected clock) and byte-stable canonical serialization; evolve the manifest's `initialState` map into the same typed shape **additively** (0.8 wire-compat) so PoC content still loads. The state is consumed by the 2.9 save and the Phase 3 receipt.
- [x] Implement **outcome resolution** (succeed / fail / stabilize / crisis) with structured deltas, using the **2.0 deterministic seed derivation + portable PRNG**; each delta carries `ruleset_version` and fixed-point values (0.8) and is applied **transactionally** — a cancelled or failed generation rolls the turn back with no half-applied state (carried from 1.4).
- [x] Implement the **local case lifecycle** (open → in-treatment → cured / abandoned / hard-failed → archived, plus crisis, walkout, and the §16 derangement branch) as the **offline, single-owner precursor to the [C-8](../specs/PATIENT-LIFECYCLE.md) / Phase 3.6 server-arbitrated state machine** — the same transitions, locally trusted for now.
- [x] Implement **fictional pharmacology** (§16, §22): prescribe from an invented formulary (its drug names **extend the 0.12 fictional-taxonomy registry** and pass the CI no-real-label lint), model tolerance / side-effects and their effect on case pressure, record medication history as typed deltas, and let medication shift only **dialogue delivery via the style-filter — never the mechanical outcome** (§4 boundary); a persistent-`memory_class` case can **inherit chemical dependency from its history** (§17), wiring 2.3 pharmacology to the 2.4 carry-over and the 2.7 over-medication audit.
- [x] **Evolve the existing `SessionReceipt` + `StructuredDelta` (already in `packages/psychemas`) into the full precursor shape** rather than inventing new types: the receipt gains the **start state + ordered card actions** alongside the `turnCount` / `ruleset_version` it already carries, and its `deltas` — **today an untyped `List<Map<String,Object?>>`** — become a **typed `List<StructuredDelta>`** so the receipt is type-checked end-to-end, not raw maps; the delta gains a **typed axis enum** and a **distinct economy/currency delta variant carrying fixed-point money** (today it is a generic string `axis` + `deltaMillis`). Shape it so **Phase 3.3 adds only per-tier plausibility bounds + anomaly detection, not a new schema** (0.8 wire-compat) — the receipt shape stops forking between Phase 2 and Phase 3.
- [x] **Stamp each receipt with its idempotency key + correlation/session id** (0.7) so the 2.5 event keying, the 2.9 receipt-queue shape, and the Phase 3.4 server dedupe all bind to a field **on the receipt** rather than a side channel — the local precursor to the exactly-once submission contract, established before the server exists.
- [x] Define the **local `ruleset_version`-change policy** for persisted career state: deltas and receipts tagged with a superseded `ruleset_version` stay **replayable against that version's pinned PRNG constants** (2.0) or are **migrated forward** under a documented rule, never silently reinterpreted — the offline analog of the Phase 3.3 sunset schedule, so an app update that bumps the ruleset can never corrupt or double-apply an in-progress save.
- [x] Enforce the **no-raw-transcript-durable rule** (0.6) in the core even offline: outcomes are structured deltas, never dialogue text.
- [x] **Carry the 1.4 degrade-to-fixed-text safety net into the production resolver**: missing clue tokens, an empty generation, a model refusal, or safety-boilerplate (small instruct models balk at mature / Manipulative content, [C-6](../specs/AGE-RATING-AND-CONTENT-STRATEGY.md)) all route through the same bounded-regeneration → deterministic templated-fallback path, so the turn still resolves to fixed text — never a blank or broken exchange (reliability).
- [x] Keep **all** model interaction behind the `shared/` inference service; `core/` never imports the FFI layer (Principle 2 boundary), and model output still cannot alter anything mechanical (§4).
- [x] **Unit- + property-test** the resolver across representative scenarios and seeds (0.5): the four outcome paths, every lifecycle transition, pharmacology effects, and byte-identical determinism; a golden fixture pins a full multi-turn case.

### 2.4 — Multi-session siege, clue ownership & clinical grading

**What.** Implement the cross-session research loop (§15) — exit to analyze
clues, study to acquire target cards, return for the breakthrough — plus the
compiled history digest and the advanced "Attending Physician" grading report.

**Why.** This is the depth mechanic that carries mid-to-late game and the payoff
for reading a case over multiple sessions; the grading report is what makes
mastery legible.

**How.** Ties progression (study) to session tactics, closing the core loop, and
reuses the 1.3 history-digest compiler so long cases stay within the token
budget.

**Validation.** A layered case requires ≥2 sessions + a study step to resolve;
the history digest stays within its fixed token envelope regardless of session
count; the grading report scores a completed case.

- [x] Implement **clue collection + the fictional clinical encyclopedia** lookup (§15) — a fully invented reference whose entries **extend the 0.12 fictional-taxonomy registry** and pass the CI no-real-label lint, never a real diagnostic manual — matching collected clue tokens (1.2 vocabulary) to fictional field notes.
- [x] Implement **multi-session case carry-over** via structured deltas (never transcripts), persisted through the 0.9 storage seam (2.9), and reuse the **1.3 history-digest compiler** so the prompt stays budget-bound (C-7) no matter how many sessions accumulate; the digest is a **bounded structured summary of whitelisted enums + numbers** (0.12 injection isolation) and its fixed token envelope is a **tested invariant regardless of session count** (perf + integrity).
- [x] Keep **accumulated carry-over injection-safe**: derangement mutations (2.1) and inherited medication/dependency (2.3) persist only as the bounded, enumerated delta catalogue — never free text — so when Phase 5.2 wraps this in a *server-signed, peer-authored* history envelope the untrusted-input shape (0.12) is already correct and needs no reshaping.
- [x] Implement the **study → target-card acquisition path** (spend study/subspecialty points to unlock the "Bull's Eye" counter card), linking §15 to the 2.5 progression economy.
- [x] Implement the **"Attending Physician" clinical grading report** (§15): **deterministically** score the locally-tracked card-sequence on Therapeutic Alliance Maintenance, Diagnostic Path Efficiency, and Pharmacological Safety, gated to unlock at the config-defined advanced tier (a basic outcome line before, the full matrix after) — a pure function of the receipt's ordered actions, so it is unit-testable and replay-stable.
- [x] Enforce **`memory_class` discipline** (1.2): stateless / social-chronic cases carry no history envelope and never accumulate carry-over — the offline precursor to the §17 ledger rule.
- [x] **Unit-test** the siege loop (a two-session case is unsolvable in one, solvable after study), digest-envelope boundedness, and grading determinism.

### 2.5 — Progression, multi-currency economy & the attraction vector

**What.** Implement difficulty-scaled XP, study/subspecialty points and the
field-training tree, event-sourced reputation, the offline multi-currency ledger,
the patient-attraction vector (§9, §10), and the early-career onboarding track.

**Why.** Progression is the spine that sequences role unlocks and case access; a
multi-currency economy without modelled sources and sinks inflates or dead-ends,
so the currency shapes must be right before the sandbox tunes them.

**How.** Feeds the recovery systems (2.6), the clinic economy (2.7), and the
attraction/matchmaking inputs the Phase 4.5 server router later owns.

**Validation.** Harder cases yield proportionally more XP; reputation decays, is
floored by credentials, and responds to event shocks; every currency has a
modelled source and sink; the attraction vector computes from
reputation/pricing/study-fields.

- [x] Implement the **difficulty→XP curve** (harder cases worth proportionally more; trivial grinding diminishes), curve owned by config (C-4); the §17 trauma multiplier stays a Phase 5.3 server-side amplifier hook, not implemented offline.
- [x] Implement **study + subspecialty points and the field-training tree** (foundational cheap → advanced expensive), with all **field names drawn from the fictional-taxonomy registry** (0.12), feeding §10 study-field coverage and the §14 sabbatical floor.
- [x] Implement **event-sourced, recency-weighted reputation** (not a lifetime ratio) with decay and a credential-based floor, using the **injected clock** (0.8) for recency-weighting so it cannot be gamed by the device clock; the decay is computed in **fixed-point (an integer decay table, no float `exp`)** so reputation replays byte-identically (2.0).
- [x] Implement the **offline multi-currency ledger** (clinic currency, study points, subspecialty points, XP, reputation, prestige) as an **append-only, event-sourced log of fixed-point transactions** (0.8), each event carrying an **idempotency key** so a retried or interrupted mutation applies **exactly once**; every currency has a modelled source and sink from C-4, and a **conservation invariant** (balances == replayed events) is property-tested. Royalties and UGC-prestige stay Phase 5/6 hooks.
- [x] Shape the ledger as the **local precursor to the Phase 5.1 server economy + the 0.6 append-only audit trail**: because every balance is a replay of keyed events, the same event stream later feeds server-side validation and the tamper-evident audit log without reshaping — high-value payouts become server-computed in Phase 5.1 by validating this exact stream.
- [x] Add **ledger snapshotting + compaction**: periodically checkpoint the replayed balances and **truncate the consumed event tail** so replay time and on-disk save size stay **bounded over a long career** (not O(lifetime events)); the snapshot is checksum-guarded (2.9) and the **conservation invariant holds across every snapshot boundary** (property-tested), and the snapshot+tail shape is the local precursor to the Phase 5.1 server-side ledger checkpoint — efficiency, reliability, and a small save at once.
- [x] Implement the **patient-attraction vector** (§10) — reputation + price-accessibility + study-field coverage — as the local input the offline case seed (2.7) reads and the Phase 4.5 server router later subsumes; the three-factor mean is a **UI readout**, not the routing algorithm.
- [x] Implement the **New Clinician onboarding track** (§9): a low-consequence "safe practice" mode and teach-don't-punish early failures, so early cases build competence without death-spiralling a new player.
- [x] Persist all progression + currency balances via the **offline career profile** (2.9); **unit-test** the curves, reputation decay/floor/shock, and that no currency can be minted or destroyed by rounding (fixed-point integrity).

### 2.6 — Financial stabilizers, operational pressure & recovery

**What.** Implement the anti-bankruptcy paths (§14) and the visible
operational-pressure / recovery-window model (§23), with no hidden well-being
stat.

**Why.** Failure states need designed exits or the game becomes a death spiral;
pressure must be visible and player-legible, and recovery must never be a
pay-to-win shortcut.

**How.** Keeps struggling players in the loop; operational pressure computed here
is the client-visible precursor to the server-derived quantity
([C-9](../specs/SERVER-DERIVED-QUANTITIES.md) / Phase 5.5) that later feeds
routing.

**Validation.** Both recovery strategies restore a playable state; pressure is a
visible state with cooldowns, not a hidden number; recovery windows advance on
the injected clock.

- [x] Implement the **Discount Practice recovery** (§14): the pricing slider dropped past a critical reputation threshold floods the local seed (2.7) with casual, cooperative cases, at the config **50% XP penalty** — a high-volume path back that slows leveling.
- [x] Implement the **Academic Sabbatical recovery** (§14): a clinic-closed mode pauses the case router; study points restore reputation to `total_study_fields × base_competency_constant` (config), with zero currency earned during downtime.
- [x] Implement **visible operational pressure** (§23): accrued from session cadence + case tier, computed **locally from the same accepted-delta inputs the C-9 / Phase 5.5 server derivation will use**, so Phase 5.5 swaps the *source* (server-derived from accepted receipts) without reshaping the routing/recovery consumers; surfaced as clear healthy / strained / at-risk UI states — never a hidden well-being stat.
- [x] Implement **recovery windows + capacity limits** (§23) as cooldowns gated on the **injected authoritative clock** (0.8) with a **monotonic source for local elapsed time**, so a cooldown cannot be skipped by winding the device clock forward — **unit-tested with a device-clock-tamper scenario**; peer-healer co-op (§23) stays a Phase 5 server hook (offline stub only).
- [x] Make **recovery-mode transitions transactional and resumable**: entering or exiting Discount Practice or Academic Sabbatical is a single atomic state change (2.9) so an app kill mid-toggle relaunches in a consistent mode, never a half-applied recovery (reliability).
- [x] Bind every recovery constant (critical reputation threshold, XP penalty, floor constant, pressure accrual/decay, cooldown lengths) to config (C-4); **unit-test** that both recovery paths return a bankrupt profile to a playable state and that pressure is deterministic.

### 2.7 — Clinic operations, economy & the offline case router

**What.** Implement the clinic business layer (§22) — rent/buy/sell offices with
overhead, progressive taxes and randomized audits — and the pricing slider's
effect on a deterministic local case router, the offline precursor to the Phase
4.5 server matchmaker.

**Why.** The clinic economy is the strategy layer around the session loop and
establishes the owned-clinic asset that later gates hiring (Phase 6); the local
router is what supplies cases offline before the server exists.

**How.** Turns pricing, reputation, and study-field coverage into the case stream
the player faces; every money movement is a fixed-point, atomic transaction.

**Validation.** A player can rent, earn, buy, and sell a clinic; overhead,
progressive taxes, and audits apply on the authoritative-time cadence; the
pricing slider measurably shifts the local case seed.

- [x] Implement **office rent / buy / sell + overhead upkeep** as **keyed, idempotent events on the 2.5 event-sourced ledger** (fixed-point, 0.8) so an interrupted purchase applies **exactly once** — never zero, never twice, never a half-applied ledger (reliability); an owned clinic of sufficient tier is recorded as the asset Phase 6.3 hiring later requires.
- [x] Implement **progressive taxes + randomized audits** keyed to the pricing slider: taxes computed as **fixed-point ratios** (2.0 config→core seam, no float), tax weeks and audit cadence advancing on the **injected clock** (0.8), and audits deterministically reading the medication/outcome history from the deltas (§22) — over-medication histories penalize reputation.
- [x] Implement the **deterministic, resumable offline case router** (§10 / §13 local precursor to Phase 4.5): pricing + reputation + study-field coverage weight the incoming case stream in **fixed-point** (no float), drawn from the **2.0 PRNG**, with the **social-chronic bias** for early-career / sub-recovery players and the **tenure-gated chaos "Misfortune Roll"** (config ~5%, never fires below the tenure gate); the router seed + cursor persist (2.9) so an app restart **regenerates the identical stream** rather than re-rolling it.
- [x] Implement the **§13 strategic-exit choices** for an over-matched case (reject → returns to pool; refer → +1 XP ethical reward; force → agitation spike / walkout / reputation hit) so a player is never trapped by the chaos roll.
- [x] Leave **macro / environmental events** (§22 sociopolitical + meteorological) as **server-seeded Phase 6 hooks** — offline stubs only — so the offline seed stays deterministic and reproducible.
- [x] Bind all clinic/routing constants (rent, overhead, tax brackets, audit odds, chaos-roll %, tenure gate, social-chronic thresholds) to config (C-4); **unit-test** the atomic economy transactions and that the router seed is deterministic for a fixed profile + seed.

### 2.8 — Balance sandbox, solvability oracle & bot simulation

**What.** Build the accelerated sandbox + bot-driven simulation harness (§3) —
parameter mutation, profile/clinic injection, admin overrides, scenario runs,
structured result logs — plus the per-manifest mechanical-solvability / best-combo
baseline (§11), then tune the C-4 balance spec against it.

**Why.** This is core infrastructure — it shortens every future balance decision
and powers the mechanical-solvability check (§2.2) that Phase 4.3 reuses and the
balance oracle (§11 / Phase 6.6) later grows from.

**How.** Turns the C-4 balance spec from a document into a tuned, tested system,
and runs the deterministic core **without the LLM** (§2.2) so thousands of bot
sessions are cheap and reproducible.

**Validation.** Bots of configurable skill play scenarios headlessly and emit
comparable metrics; the sandbox proves a case mechanically solvable with no model
call; balance constants load only from config; sources/sinks/inflation/
dead-currency checks pass.

- [x] Implement the **accelerated sandbox runtime + parameter-mutation layer** on the **2.0 core-only run path** — reusing the single deterministic core (0.1) but *not* the LLM / Flutter / `dart:io`-coupled Phase 1.6 app harness — running the pure core under accelerated injected-clock time (0.8), **parallelizable across isolates with zero per-run I/O** so thousands of sessions stay cheap.
- [x] Implement **configurable-skill bots + profile/clinic-state injection** and admin overrides, so any career / clinic / case configuration is reproducible from a seed for a scenario run.
- [x] Implement the **mechanical-solvability check with no LLM and no model binary present** (§2.2): a bot proves a manifest winnable purely against the deterministic core — CI-runnable without the ~1–2 GB weights — the reusable check Phase 4.3 runs per generated manifest, and the offline form of the §11 "secret initial cheat sheet" best-combo baseline (the seed the Phase 6.6 oracle later grows from).
- [x] Implement the **scenario runner + structured diagnostics** (§3) emitting comparable metrics (win-rate by skill, currency flow, XP/session, reputation trajectory, dead-currency flags) as **distributions (median / p95, not single-shot)** on the 0.7 metrics contract, every result reproducible from its seed.
- [x] Set + record a **sandbox throughput budget** on the 0.7 metrics contract — a per-bot-session cost ceiling and a sessions/second target across isolates — so "thousands of sessions stay cheap" is a **measured, regression-guarded number** (a change that halves throughput fails the budget), not an assumption.
- [x] Keep the core-only run path **allocation-lean on the hot path**: prefer typed immutable state with structural sharing over per-turn full-`Map` copies (the PoC `SimState.copyWith` clones the whole `axes` map every turn), so a multi-thousand-session sweep is not allocation-bound — the efficiency contract the throughput budget above measures.
- [x] Maintain a **pinned regression scenario corpus** (seed-keyed golden runs) so any balance-constant change surfaces its economy / win-rate delta as a **reviewable diff** — a degenerate dominant deck, runaway inflation, or a newly dead currency fails the corpus before it ships, not after (stability of tuning).
- [x] **Wire all balance constants to the central config** and **tune the C-4 multi-currency spec** against sandbox output — sources-vs-sinks balance, no runaway inflation, no dead currency, no dominant/degenerate deck — recording tuned values back into [C-4](../specs/BALANCE-SPEC.md).
- [x] **Unit-test the sandbox itself** (deterministic scenario replay; a deliberately unsolvable manifest is flagged) so the tool that guards balance is itself trustworthy.

### 2.9 — Offline persistence, career profile & save integrity

**What.** Implement the durable offline save: the career/profile state, clinic
and owned-case state, crash-safe atomic writes, save-schema migration, and the
local receipt-queue shape — the client-side precursor to the Phase 3.2
authoritative profile and the Phase 3.4 offline queue.

**Why.** An offline career that does not survive a restart is broken; getting the
save shape and migration right now is what lets Phase 3.2 promote the local
profile to authoritative and Phase 3.4 drain the queue without reshaping
anything.

**How.** Uses the 0.9 local-persistence seam and app-lifecycle / crash-recovery
convention; the atomic-metric profile is deliberately shaped to match the Phase
3.2 primitive payload (<0.5 KB, no transcripts).

**Validation.** A career survives an app kill / relaunch with no lost or
double-applied progress; a save written by an older schema loads under migration;
the profile carries atomic metrics only.

- [x] Implement the **offline career profile** (atomic metrics only: level/XP, study + subspecialty points, reputation, currency, prestige, owned-clinic tier) via the 0.9 storage seam, shaped as the **precursor to the Phase 3.2 primitive profile** (<0.5 KB, no logs or transcripts).
- [x] Persist **clinic state + owned-case state + multi-session deltas** (2.4/2.7) durably via **write-temp → fsync → atomic-rename** (0.9 app-lifecycle) so a backgrounded / killed app relaunches into a consistent state with no half-applied economy transaction and no double-applied turn.
- [x] Implement the **local save-schema migration policy** (0.9): a save from an older `schema_version` migrates forward (verified against a **golden old-schema save corpus**) or fails loudly, never loading partially; an unrecognised *additive* field is tolerated (0.8 wire-compat) and a corrupt save **falls back to the last-good backup** rather than wiping the career (0.7 error taxonomy).
- [x] Stand up the **local durable receipt-queue shape** as an **append-only, idempotency-keyed** log (0.7, sharing the 2.5 event keying) — the offline stand-in for the Phase 3.4 queue, shape only, no server submission — so Phase 3.4 wraps it additively and a replayed queue never double-applies.
- [x] Enforce **save integrity + the no-durable-transcript rule** (0.6): a content-checksum guards the save, and a test fails if any raw dialogue transcript can reach durable storage, even offline.
- [x] **Declare (convention only, enforced at prod per [DECISION 0017](../project/DECISION_LOG.md)):** the save-at-rest secure-storage posture (0.6 client data-at-rest) and a local backup/export policy — documented now so Phase 3/7 add custody and server-side backup/DR without a retrofit.
- [x] Treat an **imported / restored backup save as untrusted input**: decode it through the same defensive path as the manifest loader (byte-size, nesting-depth, and per-field caps + checksum verify before load, 0.12) so a hand-edited or hostile save file **fails closed** instead of crashing, exhausting memory, or smuggling unvalidated state into the career — the offline precursor to the Phase 3 server trust boundary.
- [x] **Unit-test** the save/restore round-trip, **atomic-write crash recovery via a kill-at-every-write-offset fuzz** (each interruption leaves a loadable last-good state), schema migration against the golden corpus, rejection of an over-budget / corrupt imported save, and the transcript-block gate.

### 2.10 — Offline case corpus & Phase 2 balance/solvability exit report

**What.** Author the representative **offline case corpus** the phase actually
plays on — tier-spanning, multi-session/siege cases exercising all four card
types, fictional pharmacology, and the derangement branch — and record a **Phase
2 exit report** (mirroring the Phase 1.6 template) stating the balance /
solvability / economy findings and the go/revisit decision before any Phase 3
spend.

**Why.** Every other Phase 2 sub-phase builds *machinery*; without content there
is nothing to prove "a full offline career loop is playable end-to-end" against,
nothing for the 2.4 siege loop to layer over, and nothing for the 2.8 sandbox to
tune the C-4 constants against. And, exactly as §1 insists for the PoC, "the
systems compile" is not a pass: the offline game's fun / solvability / economy
claims must be **recorded, reproducible evidence**, so a red result revisits the
design (or the constants) *before* the server spend begins.

**How.** Turns the corpus into the shared fixture the siege loop, the sandbox,
and the content-integrity gate all consume, and converts Phase 2 from a pile of
features into a recorded de-risking decision point — the offline analog of 1.6.

**Validation.** The corpus spans the progression tiers and is authored **only**
from the fictional-taxonomy registry (every case passes the 0.12 no-real-label
lint); every case is proven **mechanically solvable with no LLM** by the 2.8
oracle; the exit report records solvability, economy (sources/sinks / inflation /
dead-currency), and win-rate-by-skill as distributions (median/p95), with the
decision stated.

- [ ] Author a **representative offline case corpus** (small but tier-spanning) exercising the four card types (2.1), the capped loadout (2.2), fictional pharmacology + the lifecycle branches (2.3), and at least one **multi-session siege** case (2.4) — each a typed, checksum-guarded manifest drawn **only** from the 0.12 fictional-taxonomy registry; authored up **alongside 2.3–2.7** and finalized here so 2.4 and 2.8 have real content to run on.
- [x] Run a **corpus-wide integrity + solvability pass**: every case passes the CI content-integrity lint (no real DSM/ICD label or drug brand, 0.12) and is proven **mechanically solvable on the 2.0 core-only path with no model binary present** by the 2.8 oracle — an unsolvable or non-compliant case fails the gate, not playtest.
- [ ] Record the **Phase 2 exit report** in `docs/reports/` under the 1.6 exit-report template: the 2.8 solvability + economy distributions (sources/sinks, inflation, dead-currency, win-rate by skill, median/p95), a byte-identical replay confirmation from the golden fixture (2.0), and an explicit **go / revisit decision** before Phase 3 spend.

Current repair evidence proves both bundled cases at seed 42, but their two-manifest corpus does not yet establish the required tier-spanning coverage. The refreshed sandbox records four dead-currency flags and uneven bot outcomes; no dedicated Phase 2 exit report exists in `docs/reports/`. W5 generation and W6 economy work must supply the missing corpus/evidence and an explicit revisit decision.

---

## Phase 3 — Server Control Plane & Authoritative State

**Goal.** Graduate the Go health-check skeleton ([`server/`](../../server/)) into
the real authoritative control plane the whole trust model rests on
([ADR-0001](../design/ADR-0001-server-authoritative-control-plane.md)): an
observable, deployable service that owns identity, the primitive profile store,
**verify-in-place** session-receipt validation, the offline receipt-reconciliation
protocol, the managed PKI, and the server-arbitrated patient-ownership lifecycle.
The client proposes; the server decides.

**Scope id.** `phase-3`

**Runtime.** Go 1.26 ([ADR-0006](../design/ADR-0006-server-runtime-go.md),
superseding ADR-0003). The server **verifies signatures over the exact received
bytes and enforces cheap, language-neutral invariants** (ledger conservation,
idempotency, ownership state-machine legality, per-tier plausibility bounds) — it
does **not** re-run the Dart sim math (the "fat backend that re-derives outcomes"
ADR-0001 explicitly rejected). Any bounded server-side computation added here
stays on that side of the ADR-0006 line.

**Why now.** The offline core provides implemented mechanics for the
authoritative spine. The 2026-09-10 assessment reopened the integrated offline
flow and found the C-3 cost gate still unvalidated; complete those acceptance
gates alongside local server implementation before claiming online readiness. This is the first phase where the client stops being self-trusted:
identity, the profile, the economy ledger, ownership, and presence all move
behind the server.

**Validation.** A client boots against the server, authenticates on all five
platforms, submits **signature-verified** receipts that mutate authoritative
state exactly once, survives offline/online transitions with exactly-once
reconciliation, and every ownership transition matches the [C-8](../specs/PATIENT-LIFECYCLE.md)
§18 state machine; every accept/reject is on the append-only audit trail; a cold
start meets the C-3 scale-to-zero budget; and the phase closes on a **recorded
Phase 3 exit report** (the server analog of 1.6 / 2.10) stating a go/revisit
decision before Phase 4 spend.

> 🧩 **Build order & dependencies (read before picking up a sub-phase).** 3.0
> (service foundations, data store, API contract, idempotency + verify-in-place +
> server-time seams) goes **first** — every other sub-phase writes against it.
> Then 3.1 (identity) establishes per-account authority; 3.2 (profile store) and
> 3.6 (ownership record) are the two authoritative state stores; 3.3 (receipt
> validation) is the write path that mutates them; 3.4 (offline protocol) wraps
> 3.3 with a durable queue + reconciliation; 3.5 (PKI **+ client signing**)
> provisions the device keys and *produces* the signed envelopes 3.3/3.4 (and the
> later 4.4/5.2) verify — 3.0 stands up the verify-in-place seam + a test key so
> 3.3 can be built before 3.5 formalises provisioning, rotation, and revocation.
> 3.7 (observability/resilience/deploy) is
> stood up **alongside** 3.0 and hardened throughout. 3.8 closes with an
> integration harness + exit report. Suggested order: **3.0 → 3.1 → 3.7 →
> 3.2 + 3.6 → 3.3 → 3.5 → 3.4 → 3.8**.

> 🔗 **Everything wraps a Phase 2 precursor *additively* — do not reshape it.**
> The receipt validated here is the **2.3 `SessionReceipt`**
> ([`packages/psychemas`](../../packages/psychemas/lib/src/receipt.dart), schema
> `0.3.0`: start state + ordered typed `InteractionPattern` actions + typed
> `StructuredDelta`s — the state-axis movements — + `ruleset_version` + idempotency
> key + correlation id); 3.3 adds *only* signature verification, plausibility
> bounds, and anomaly detection — never a new schema (0.8 wire-compat). Two
> **additive** fields are still missing from that shipped shape and are added in
> 3.0, not reshaped: the session's **`LedgerEvent` list** (economy correction
> below) and the **signature envelope** (signature correction below); the receipt's
> `start_state` is also still an **untyped `Map`** even though a typed
> `SessionStartState` (carrying the loadout + card library) exists, so 3.0 binds it
> to the type the 3.3 loadout-membership check needs. The authoritative profile
> (3.2) promotes the **2.9 offline career profile** (<0.5 KB atomic metrics). The
> offline queue (3.4) wraps the **2.9 durable receipt-queue shape**
> ([`app/lib/shared/career_persistence.dart`](../../app/lib/shared/career_persistence.dart)
> — today a JSONL log of *unsigned* receipts). The ownership state machine (3.6)
> makes the **2.3 local case lifecycle** server-arbitrated per
> [C-8](../specs/PATIENT-LIFECYCLE.md) — **but the two are not the same
> vocabulary** (lifecycle correction below), so 3.6 *maps* onto C-8, it does not
> assume identity.

> 🧮 **Economy correction — the ledger is a *separate stream*, not a delta
> variant.** An audit of the shipped Phase 2 code corrected an assumption the
> earlier plan carried: economy mutations are **`LedgerEvent`s** on the 2.5
> append-only, idempotency-keyed, fixed-point-micros ledger (`packages/psycore`
> `Ledger`) — **not** a currency variant of `StructuredDelta` (which stays
> state-axis-only: trust / agitation / defense / trauma / medication). Today those
> events live **only client-side** in the career profile / save and are **never
> submitted**, so the server has nothing to validate. Phase 3 therefore
> **additively extends the receipt to carry the session's `LedgerEvent` list**
> (0.8 wire-compat, same canonical bytes) and stands up the **authoritative
> server-side ledger store** (3.2) that ingests that exact stream and enforces
> conservation (3.3); Phase 5.1 then computes high-value payouts *on this store*
> without reshaping it.

> 🔌 **Contract-fork correction — reconcile the Go schema mirror first.** The Go
> mirror ([`server/internal/schemas/schemas.go`](../../server/internal/schemas/schemas.go))
> currently emits **camelCase** JSON tags (`schemaVersion`, `deltaMillis`) while
> the 2.0 Dart `CanonicalJson` emits **snake_case** (`schema_version`,
> `delta_millis`), and its `SessionReceipt` is **stale** (untyped
> `[]map[string]any` deltas; missing `idempotency_key`, `correlation_id`,
> `start_state`, the ordered actions, and the ledger-event list). The Dart↔Go
> boundary is therefore **already forked for the receipt** — only the manifest
> round-trips today. 3.0 reconciles the mirror to the exact snake_case 2.3 shape
> and makes the contract test fail on any divergence — a prerequisite, not a
> nice-to-have.

> 🔑 **Signature correction — nothing signs a receipt yet; the envelope must be
> *built*, not merely verified.** An audit of the shipped Phase 2 code found the
> `SessionReceipt` carries **no signature, no signing-key id, and no signed
> wrapper**, and the client never signs anything — every "signature" in the code
> today is the *gameplay* `CardSignature`, not cryptography. The verify-in-place
> model (ADR-0006) therefore has **nothing to verify** until the producer side
> exists, so Phase 3 must close this end-to-end, not assume it: **3.0 defines a
> signed transport envelope** (the exact canonical receipt bytes + a detached
> signature + the suite id + the signing-key id, additively — 0.8 wire-compat),
> **3.5 provisions a per-device signing key and signs each envelope client-side**
> (so the 2.9 queue holds *signed* envelopes, not bare receipts), and **3.3
> verifies the signature over the received bytes *and* binds the signer to the
> authenticated account** (a stolen or relayed signed receipt cannot be replayed
> under another account). Verifying a signature nothing produces was the silent
> gap in the earlier plan.

> 🔁 **Lifecycle correction — the local `CaseLifecycle` is a different vocabulary
> from C-8, so 3.6 *maps*, it does not rename.** The shipped offline enum is
> `open → in-treatment → {cured | abandoned | hard-failed} → archived` with a
> `crisis` freeze branch — the *treatment* view of a case the single player always
> owns. The [C-8](../specs/PATIENT-LIFECYCLE.md) §18 machine is the *ownership*
> view — `pool ⇄ owned ⇄ hospitalized → cured → archived` — and introduces a
> `pool` (unowned) state with **no offline single-owner equivalent**. 3.6 must
> therefore define an explicit mapping (`crisis → hospitalized`,
> `open`/`in-treatment → owned`, `abandoned → owned → pool`, `hard-failed → owned
> → archived`) rather than assume the local enum already *is* the C-8 machine.

> 💸 **Cost scope (C-3).** The C-3 model ranks **CDN egress the dominant driver**
> (the ~1–2 GB model + manifest fetches) — that is **Phase 4**, not Phase 3.
> Phase 3's cost budget is scoped to the **#2 driver (receipt write + bounded
> anomaly compute), request/DB concurrency (#3), auth MAU (#4), and cold-start**;
> storage is the *smallest* driver. Every validation path here carries a **bounded
> per-receipt compute budget** so the #2 driver cannot blow the 10k-MAU ship gate.

> ⏱ **Authoritative time & no-drift determinism (0.8).** Every TTL, lease, sunset
> window, and cadence uses the **server clock** as the authoritative source (the
> 0.8 server-reconcilable time seam); the device clock is untrusted. The server
> never needs the Dart PRNG or fixed-point math to *validate* (verify-in-place),
> but where it computes a bounded value it uses the **same canonical byte
> encoding the Dart↔Go contract test pins**, so a value can never fork across the
> trust boundary.

> 🔒 **Security posture — implemented now, custody/ops hardened later.** Per the
> 0.6 baseline (and [DECISION 0017](../project/DECISION_LOG.md), now past its PoC
> gate), Phase 3 *implements* the auth/authorization boundary, receipt integrity,
> the append-only audit trail, single-owner locking, and the PKI — the
> authoritative store now exists, so these are no longer premature. Items that
> need **production custody/ops — secret management, signing-key custody +
> rotation, server-side backup/point-in-time recovery, and DR drills — are
> planned here but tagged ⏭ hardened later**: Phase 3 stands up the *interface +
> stub* (env-referenced secrets via the config authority, a rotation-ready key
> interface, a manual backup/restore procedure) and the full custody/ops
> automation lands in the owning hardening slice (noted per bullet, typically the
> 0.6 implementation / Phase 7.6). **No secret value, private key, or credential
> is ever committed.**

### 3.0 — Server foundations: service skeleton, data store, API contract & runtime shape

**What.** Graduate the Go health-check stub into a real service: the versioned
HTTP/API contract, the authoritative data-store choice + schema migrations, the
server-side config-authority integration, the idempotency + request-context
middleware, the verify-in-place signature seam, the authoritative server-time
seam, and a graceful startup/readiness/shutdown lifecycle sized for the C-3
scale-to-zero cost model.

**Why.** Every other 3.x sub-phase writes against this. Deciding the transport
contract, the store, migrations, idempotency, and the crypto/time seams **once** —
before identity, profiles, or receipts land — is what stops each endpoint from
re-inventing its own persistence, auth-context, and error shape. The Go decision
(ADR-0006) is only *realized* once the service has a real request lifecycle, not
a single `/health` route.

**How.** Turns `server/` from a stub into the deployable spine the authoritative
systems plug into, on the 0.7 logging/metrics/identifier conventions and the 0.8
canonical-serialization contract.

**Validation.** The service boots, connects to its store, runs migrations,
answers readiness/liveness, verifies a signed sample payload over its exact
bytes, and round-trips the 2.3 receipt schema byte-identically against the Dart
contract test; a cold start stays within the C-3 scale-to-zero budget.

- [x] **Record the server data-store choice in an ADR** — a **Go service fronting a managed relational store** (e.g. managed Postgres) sized to the C-3 profile (~0.5 KB profiles, an append-only economy ledger, the audit trail, the ownership record, and the idempotency/dedupe table; scale-to-zero) — **superseding the roadmap's earlier "BaaS ecosystem" assumption**, which predates the Go-runtime + no-BaaS-identity decisions (ADR-0006 / 3.1). Record the transactional + connection-pooling model the store must support.
- [x] Define the **versioned API/transport contract** (route namespace, request/response envelope, an explicit API-version header) as the single seam the **0.10 typed Dart client** binds to — **additive-only evolution** (0.8 wire-compat) so an older client degrades safely against a newer server and vice-versa.
- [x] Define the **structured error taxonomy + response shape** (a stable, machine-readable error body on the 0.7 classification: user / system / external, offline as first-class) so every endpoint fails with one shape the client maps to actionable, localized states (0.11) — never an ad-hoc string per route.
- [x] **Reconcile the Go schema mirror to the exact 2.3 shape (contract-fork fix).** Migrate [`server/internal/schemas`](../../server/internal/schemas/schemas.go) from its **stale `0.1.0` camelCase** `SessionReceipt` (untyped `[]map[string]any` deltas, `deltaMillis`) to the shipped **`0.3.0` snake_case** canonical shape — typed `StructuredDelta`s (`delta_millis`, `axis`, `card_type`, `card_signature`, `context_fit`), `idempotency_key`, `correlation_id`, `start_state`, the ordered `InteractionPattern` actions, and the additive `LedgerEvent` list — matching the 2.0 `CanonicalJson` bytes, and refresh the stale `test_fixtures/receipts/sample_receipt.json` the Go test still pins at `0.1.0`. **A divergence must fail the contract test**, not surface in production.
- [x] **Define the signed transport envelope (additive, 0.8 wire-compat).** The shipped receipt carries *no* signature (signature correction above), so specify a wrapper — `{ canonical_receipt_bytes, signature, suite_id, signing_key_id }` — that travels over the wire and in the 2.9 queue, so the exact bytes signed on the client are the exact bytes 3.3 verifies (**no re-canonicalization**, ADR-0006). The **suite id** keeps the algorithm rotatable (crypto-agility); the **signing-key id** lets 3.3 resolve the signer's published public half without guessing. This is the single producer/consumer contract 3.5 (client signing) and 3.3 (verify) both bind to — defined here so neither invents its own.
- [x] **Bind the receipt's `start_state` to the typed `SessionStartState`** (loadout + card library + controller settings + initial axes + root seed) in both the Dart schema and the Go mirror — it ships as an untyped `Map<String, Object?>`, but the 3.3 loadout-membership check (reject actions referencing un-owned cards) needs the loadout + library as a **typed** contract, not a raw map the validator must re-parse defensively. Doing this in 3.0 keeps the un-owned-card guard a compile-time-typed check rather than a stringly-typed one.
- [ ] Implement **schema migrations + a rollback path** as first-class, ordered, reviewable steps run at deploy, using **backward-compatible / online migrations** (expand-then-contract) so a rolling deploy never breaks an in-flight older instance and a bad migration is revertible (reliability).
- [x] Wire the **config authority server-side** (0.2): endpoints, the store DSN (by secret *reference*), rate-limit constants, per-tier plausibility bounds, and feature flags/kill-switches resolve through one validated config, never raw env. *(⏭ hardened later: production secret resolution/custody → 3.7 / the 0.6 implementation; here the reference + interface exist, values come from the local dev environment.)*
- [ ] Implement the **idempotency + request-context middleware**: every mutating request carries the 0.7 idempotency key + correlation/session id, deduped at the store boundary, so a retried request applies **exactly once** (the server half of the 2.9 / 3.4 contract) — with a **bounded dedupe-key retention + GC policy** so the dedupe table cannot grow without limit.
- [x] Implement a **transactional multi-entity write primitive**: the profile + ledger + ownership + audit-trail mutations for one accepted receipt commit in a **single atomic transaction** (or a durable outbox), so a crash mid-write can never half-apply an outcome or lose an audit row (reliability + integrity).
- [x] Implement **defensive request decoding at the trust boundary** (the server analog of the 0.12 / 2.9 untrusted-input rule): a hard request-body size cap, JSON nesting-depth + per-field length caps, bounded array counts, a decompression-bomb guard, and **reject-before-parse** so a hostile or malformed payload fails closed rather than exhausting memory or CPU (integrity + stability).
- [x] Implement the **verify-in-place signature seam** (ADR-0006): a helper that verifies the envelope signature over the **exact received bytes** and only *parses* the enforced fields — never re-serializing or re-simulating to check — with a **crypto-agility hook** (suite id carried in the envelope) so the algorithm can rotate.
- [x] Implement the **authoritative server-time seam + a time-sync endpoint** (0.8): one injected clock is the source of truth for TTLs / leases / sunsets / cadence, a monotonic source measures server-side durations, and a lightweight **server-time endpoint lets the client reconcile its untrusted device clock** (feeding the 3.4 lease + cooldown logic) rather than trusting local time.
- [ ] Implement **graceful lifecycle + connection pooling**: readiness vs liveness probes, a warmed store connection pool with prepared statements, in-flight-request draining on shutdown, and a **cold-start budget measured against the C-3 scale-to-zero target** — the Go static-binary advantage from ADR-0006 made real, not assumed.
- [x] **Extend the Dart↔Go contract test** (0.5 / 0.8) to the full reconciled 2.3 `SessionReceipt` (typed deltas, the `LedgerEvent` list, idempotency key, correlation id, start state, ordered actions) **and** the profile payload — not just the manifest — so the boundary cannot silently fork; a schema change breaks the contract test, not production.

### 3.1 — Identity, authentication & session tokens

> **Current execution boundary:** Implement and test real provider verification against controlled local JWKS/OAuth fixtures. Live five-platform sign-in remains pending provider registrations, test accounts and target platforms; do not replace it with stub-verifier success.

**What.** Implement server-authoritative identity via **Google/Apple OAuth**
across all five platforms per [ADR-0002](../design/ADR-0002-desktop-distribution-and-auth.md)
(Steam is a *distribution* channel only, never an identity silo), **verified in
the Go service** (no BaaS-identity lock-in), plus the session-token lifecycle,
the per-account authorization / row-level-security model, and the 0.6
abuse-prevention enforcement.

**Why.** Server-authoritative identity is the precondition for every trustworthy
cross-player system (ADR-0001); anchoring profiles, presence, ownership, and
royalties to one portable account is what makes them enforceable. The earlier
"via the BaaS ecosystem" plan predates the Go runtime decision and is corrected
here.

**How.** Anchors every authoritative record to a real account and gives every
later endpoint one authenticated request context to authorize against.

**Validation.** All five platforms resolve to one account via OAuth; a token is
verified server-side, refreshed, and revocable; an unauthenticated or over-quota
request is rejected; profile rows are inaccessible across accounts.

- [ ] Implement **OAuth sign-in (Google + Apple)** producing one server-authoritative account across iOS / Android / Windows / macOS / Linux (ADR-0002), with **server-side token/JWT verification in Go** (issuer, audience, signature, expiry, nonce) — the trust decision lives in our service, not in a BaaS identity SDK.
- [x] Harden the **desktop deep-link OAuth flow** (0.9 / 1.5 callback) with **PKCE + a signed `state` / nonce** so the browser→app redirect cannot be intercepted, replayed, or CSRF'd — the desktop channel's specific attack surface (ADR-0002).
- [ ] Implement **account linking**: multiple providers (Google *and* Apple) resolving to **one** account, so a player who signs in with a different provider on a new platform is not forked into a second profile (ADR-0002 portability).
- [x] Implement the **session-token lifecycle**: short-lived access token + **refresh-token rotation** (a replayed / rotated-out refresh token is rejected), server-side **revocation / logout**, and reissue on reinstall / device-switch (ties to the 3.5 key-recovery path) — so a lost device or a ban takes effect on authoritative state.
- [ ] **Register the client's device signing key to the authenticated account** at first sign-in / device-switch: this account↔key binding is the identity anchor the 3.5 key provisioning and the 3.3 *signer-∈-account* check both resolve against, so a receipt's signature is always traceable to a device key that is traceable to one account (an unregistered signer is rejected). *(⏭ hardened later: device attestation + full key custody are 3.5 / the 0.6 implementation; here the registration + rejection exist.)*
- [ ] Implement the **authorization model + row-level security**: a request can only read or mutate its own account's profile, ledger, owned cases, and receipts — the enforcement, not just a schema note.
- [x] Stand up the **operator/admin authorization seam** — a distinct role claim + separate auth path, no player token can assume it — so the Phase 7.3 moderation backdoor and the 3.7 kill-switches ride a real privilege boundary from day one. *(⏭ hardened later: full admin custody / MFA / audited-access controls are 7.3 / the 0.6 implementation; here the role boundary + rejection exist.)*
- [ ] Bind the **desktop distribution channels** from ADR-0002 (Steam for Windows/macOS; signed direct download for Linux) to the OAuth flow.
- [ ] Implement the **0.6 abuse-prevention enforcement**: authenticated-requests-only, **per-account + per-endpoint + per-IP (pre-auth)** rate limiting + throttling, and request quotas — the shared seam anti-farming / anomaly detection (§3, §17, §21) builds on — emitting **429 / `Retry-After`** honoured by the 0.10 client resilience policy.
- [x] Tie client-held tokens to **platform secure storage** (0.6 / 0.9 data-at-rest): Keychain / Keystore / OS credential store, never plaintext. *(⏭ hardened later: full token-custody + rotation review → the 0.6 implementation / 3.7 hardening pass.)*
- [ ] **Test:** five-platform sign-in resolves to one account; a tampered / expired / wrong-audience token is rejected; a rotated-out refresh token is rejected; a revoked session cannot mutate state; cross-account access is denied; a device signing key registers to exactly one account and an unregistered signer is rejected; an admin-only route rejects a player token; rate-limit + quota trip and then recover.

### 3.2 — Profile store & session handshake

**What.** Implement the primitive-payload authoritative profile (<0.5 KB atomic
metrics — the promoted 2.9 offline career profile), the **authoritative
server-side economy ledger** (the promoted 2.5 event stream), the boot handshake
that hydrates the local game brain, server-accepted-only writes with
optimistic-concurrency versioning under one atomic transaction, the server-side
migration path, and the data-lifecycle / erasure hook.

**Why.** The profile is the authoritative player state the client only caches
(ADR-0001); keeping it a tiny primitive payload is what keeps the C-3 cost model
honest, and getting concurrency + erasure right now avoids a later reshape.

**How.** Establishes the single source of truth for progression balances that
receipt validation (3.3) mutates and the client hydrates at boot.

**Validation.** Boot pulls the profile and hydrates deterministically; only
server-accepted results mutate it; two concurrent writers cannot lose an update;
an erasure request removes PII-linked data while preserving pseudonymous ledger
integrity.

- [x] Implement the **primitive profile schema** (level / XP, study + subspecialty points, reputation, currency, prestige, owned-clinic tier, onboarding flag, unlocked fields — atomic metrics only, **no transcripts or logs**), promoting the 2.9 profile to authoritative and keeping the <0.5 KB payload the C-3 model assumes. **Split the client's bundled `CareerProfile`** — which today carries the snapshot balances *and* the `LedgerEvent` tail in one object — into **two authoritative stores** server-side: this primitive snapshot profile and the append-only ledger below, so the hot boot read stays tiny while the write-heavy ledger scales independently (C-3).
- [x] Stand up the **authoritative server-side economy ledger** (the promoted 2.5 stream): an **append-only, idempotency-keyed, fixed-point-micros `LedgerEvent` log** with **server-side snapshot + compaction** (the 2.5 checkpoint-and-truncate shape) so replay time and row count stay **bounded over a long career** — the store Phase 5.1 computes high-value payouts on, and the source the C-9 Phase 5 quantities later derive from.
- [x] Implement the **session handshake**: boot authenticates (3.1), pulls the authoritative profile, and hydrates the local game brain — a small, cacheable payload with an **ETag / version** so an unchanged profile is a cheap conditional `304` fetch (0.10 efficiency) served off the pooled read path, since the C-3 **#3 driver is DB connections / hot reads, not storage** — a login storm must be connection-bounded, not unbounded.
- [x] Enforce **server-accepted-only writes** through the 3.0 **atomic transaction**: the client never writes the profile or ledger directly; only a validated receipt (3.3) or an arbitrated transition (3.6) mutates them — with **optimistic concurrency (version / compare-and-set)** so concurrent mutations cannot silently clobber (the reliability half of the double-spend guard).
- [x] Implement the **server-side profile + ledger schema-migration path** (mirrors the 2.9 local migration, on the 3.0 online-migration discipline) so stored state evolves forward or fails loudly, never partially.
- [x] Implement the **data-lifecycle & erasure hook** (0.6): a right-to-erasure path that removes account-linked PII while the **ledger retains only pseudonymous IDs and stays conservation-valid** (§17) — designed in now, feeding the §17 revocation path and the C-6 consent data.
- [x] **Stand up backup + point-in-time recovery** for the profile / ledger store against the **0.6 RPO ≤ 1 h / RTO ≤ 4 h** targets, and run a **documented restore drill** proving "ironclad progress preservation" (§3). *(⏭ hardened later: production backup cadence, automated DR drill, and PITR automation are the 0.6 posture's server implementation — the interface + a manual drill land here.)*
- [ ] **Test:** the boot handshake hydrates a known profile; a direct client write is rejected; a concurrent double-write resolves without a lost update; a profile + ledger mutation commits atomically or not at all; migration loads an older stored profile; an erasure request leaves the ledger conservation-valid; a compacted ledger replays to the same balances.

### 3.3 — Session receipt validation (verify-in-place)

**What.** Implement receipt submission + validation: signature verification over
the exact received bytes, per-tier plausibility bounds, statistical anomaly
detection, **`LedgerEvent` ingestion + ledger-conservation enforcement**,
`ruleset_version` pinning + sunset, idempotent dedupe, and the hash-chained
append-only audit trail — enforcing "a client number is a claim, not a fact"
**without** re-implementing the rules (ADR-0006 verify-in-place).

**Why.** This is the write path guarding the entire economy against client
tampering. The corrected model: the server **bounds-checks and detects anomalies**
cheaply and computes only the small set of high-value outputs it can derive
*without the sim engine* — it does not re-simulate the session (the ADR-0001
"fat backend that re-derives outcomes" anti-pattern).

**How.** Validates the 2.3 `SessionReceipt` as-is (0.8 wire-compat), mutating the
profile (3.2) and ledger only on acceptance, and writing every accept/reject to
the audit trail.

**Validation.** Out-of-bounds, bad-signature, replayed, and
unknown/sunset-`ruleset_version` receipts are rejected; accepted receipts mutate
state exactly once; every decision is on the audit trail; a farming pattern trips
anomaly detection.

- [x] Validate the **reconciled 2.3 receipt as-is** (start state + ordered typed actions + typed `StructuredDelta`s + the additive `LedgerEvent` list + `ruleset_version` + idempotency key + correlation id) — 3.3 adds *only* validation, **not a new schema** (0.8).
- [x] **Verify the signature over the exact received bytes** (the 3.0 envelope seam) *before* parsing enforced fields — never re-canonicalize or re-simulate to check (ADR-0006) — and **resolve the `signing_key_id` to a device key registered to the authenticated account** (3.1), so a valid but *relayed / stolen* signed receipt cannot be applied under a different account (the signer-∈-account bind).
- [x] **Decode defensively before validating** (the 3.0 boundary rule): size / depth / field caps and bounded action + delta + ledger-event counts, so a hostile receipt cannot exhaust the validator (integrity + stability).
- [x] Implement **per-tier plausibility bounds** (claimed state-axis deltas within the tier's possible range from C-4) + **statistical anomaly detection** (payout outliers, impossible cadence, illegal action sequences), under a **bounded per-receipt compute budget** so the C-3 #2 cost driver stays inside the 10k-MAU gate — the cheap, language-neutral invariants the minimal-server model relies on.
- [x] **Persist a bounded anomaly / provenance signal per accepted receipt** (not the raw receipt): the small set of aggregates cross-session farming detection needs — payout-per-case, referral-chain hop, counterpart account, cadence bucket — retention-windowed per C-3 (raw receipts age out; these derived signals are what the 5.3 Trauma-multiplier A→B→A guard and the 6.2 royalty anti-farming later read). Storing the signal cheaply *now* is what makes the Phase 5 guards possible without re-mining full receipt history.
- [x] **Ingest the session's `LedgerEvent` stream into the authoritative ledger (3.2) and enforce conservation**: dedupe on each event's idempotency key, reject any event whose fixed-point micros fall outside the tier bounds, and verify the accepted events **balance** (no currency minted or destroyed) — a trivial integer check that catches a whole class of economy tampering **with no sim engine**. This **replaces the old "economy-delta variant" assumption** (economy is the 2.5 `LedgerEvent` stream, not a `StructuredDelta`).
- [x] **Re-stamp authoritative time; never trust client timestamps.** The shipped `LedgerEvent.timestamp_seconds` (and any device time on the receipt) is client wall-clock — untrusted (0.8). The server records its **own authoritative receive-time** for ordering, cadence, ledger recency, TTL, and the audit trail, and treats the client value as an opaque non-authoritative hint only, so a device-clock lie can never shift economy timing, a cooldown, or a lease window.
- [x] Reject a receipt whose **ordered actions reference cards not in the recorded start-state loadout** (the 2.2 guard) — a receipt-forgery vector closed cheaply at the boundary.
- [ ] Compute **only the bounded high-value outputs derivable without the sim engine** (fee / payout ledger postings, cure retirement, and the ownership-affecting transitions arbitrated in 3.6) server-side; **explicitly defer** the derived-quantity math — Trauma Severity (5.3), Doubt + operational pressure (5.5) — to Phase 5 per [C-9](../specs/SERVER-DERIVED-QUANTITIES.md) (building them here is the wrong assumption the old plan carried), while making the **accepted-receipt + ledger stream** they will read available now.
- [x] Commit profile + ledger + ownership + audit **in the 3.0 atomic transaction**, so an accepted receipt applies **exactly once and completely** — or not at all (reliability + integrity).
- [x] Implement **idempotent dedupe + replay protection** on the receipt idempotency key (3.0) so a re-submitted or replayed receipt never double-applies (the server half of 3.4 / 2.9).
- [ ] Implement **`ruleset_version` pinning + the sunset schedule** (reject unknown or sunset versions, on the server clock, 0.8) — the authoritative counterpart to the 2.3 local ruleset-change policy — with the 3.7 kill-switch able to extend or close a window without a deploy.
- [ ] Implement the **append-only, hash-chained audit trail** (0.6 schema): every receipt acceptance / rejection and every high-value authoritative action, **tamper-evident (each row chains the prior row's hash)**, correlation-id-stamped, **transcript-free** — the forensic record Phase 7.3 moderation reads.
- [x] Route an **un-processable receipt to a dead-letter path** (rejected-with-reason on the 0.7 taxonomy, recorded in the audit trail) rather than silently dropping or infinitely retrying it (reliability).
- [ ] Add **backpressure / load-shedding** on the validation path (a bounded queue, fast-reject over quota) so a submission spike degrades gracefully rather than collapsing the service (stability).
- [ ] **Test:** a golden accepted signed receipt mutates profile + ledger + ownership exactly once and atomically; bad-signature / signer-not-in-account / out-of-bounds / replayed / sunset-version / non-conserving-ledger / un-owned-card receipts are each rejected with the right taxonomy code; a forged client timestamp does not shift authoritative ordering or cadence; the hash-chained audit trail records every decision and detects a tampered row; an A→B→A-style anomaly is flagged from the persisted provenance signal.

### 3.4 — Offline receipt protocol & reconciliation

**What.** Implement the §3 offline-tolerance deliverable: the durable client
receipt queue (wrapping the 2.9 shape), in-order submission, client-generated
idempotency keys + server dedupe, ownership lease TTL on the server clock, the
offline cure/transfer race resolution, and reconciliation feedback to the client.

**Why.** Play is offline-tolerant (ADR-0001, 0.10); this closes the gap between
offline play and authoritative state **safely** — a receipt submitted after a
network failure must never apply twice, and two clients acting on a leased case
offline must resolve deterministically without silent data loss.

**How.** Wraps the 3.3 validation path with the durable-queue + reconciliation
layer, binding additively to the 2.9 queue shape and the 0.10 resilience policy.

**Validation.** A receipt re-submitted after a failure is applied exactly once;
an expired lease behaves per spec; a conflicting offline cure/transfer resolves
to a single deterministic outcome with the loser reconciled, not dropped.

- [x] Implement **durable, in-order queue submission** on the 2.9 receipt-queue shape (append-only, idempotency-keyed) \u2014 **upgraded to hold the 3.0 signed envelope, not the bare `SessionReceipt`** the JSONL queue ([`career_persistence.dart`](../../app/lib/shared/career_persistence.dart)) stores today \u2014 draining through the 0.10 resilience policy (bounded backoff + jitter, `Retry-After`) when connectivity returns. A receipt is **signed once at enqueue** so a later drain re-sends byte-identical bytes and the signature stays valid across every retry.
- [x] Implement a **batched drain endpoint**: the queue submits multiple receipts in one authenticated request (each still individually idempotent + atomically applied) so a client reconnecting after a long offline stretch does not pay per-receipt round-trip overhead — directly serving the C-3 #2/#3 cost drivers.
- [x] Implement **client idempotency keys + server dedupe** (3.0 / 3.3) so exactly-once holds across retries, app kills, batched delivery, and duplicate delivery.
- [x] Implement a **reconciliation cursor / checkpoint**: the client tracks the last server-acknowledged receipt so a resumed drain continues from the cursor rather than re-sending the whole queue (efficiency + reliability).
- [ ] Implement the **ownership lease TTL** on the **server clock** (0.8, reconciled via the 3.0 time-sync endpoint): a client holds a case under a lease; an expired lease is reclaimable, and offline actions past expiry are **reconciled, not blindly applied** (ties to 3.6), with a **bounded clock-skew tolerance window** so a small honest drift is not punished while a large one cannot extend a lease.
- [ ] Implement the **offline cure/transfer race resolution**: a deterministic, server-arbitrated winner when two clients act on the same case offline, with the losing side reconciled to a consistent state and surfaced on the 0.7 taxonomy — never a silent drop.
- [ ] Implement **reconciliation feedback to the client**: an accepted / rejected / superseded status per queued receipt (plus a server queue-depth / backpressure hint) so the client converges its cached state and rolls back a provisionally-rendered outcome (the 0.9 crash-recovery + the C-9 client-proposes / server-decides contract).
- [ ] **Test (property-based):** a queue replayed after N interruptions applies each receipt exactly once; a batched drain of the same queue yields the identical state as one-by-one; an expired lease is reclaimed; a simulated two-client offline race resolves to one deterministic outcome with the loser reconciled; a device-clock advance beyond the skew window cannot extend a lease.

### 3.5 — Managed PKI (presence & signing)

**What.** Implement presence-record signing, key provisioning / certification,
public-half publication, revocation, crypto-agility + rotation readiness, and
reinstall / device-switch key recovery (§3).

**Why.** Signed presence is what lets clients trust what they display without
trusting each other (ADR-0001); it underpins matchmaking, referrals, and the §17
revocation list. Verification stays **verify-in-place** (ADR-0006) so the server
never reconstructs client bytes to check a signature.

**How.** Provides the signing / verification substrate the 3.3 receipts, the 4.4
signed manifests, and the 5.2 signed history envelope all build on.

**Validation.** Presence records validate against server-published keys; a
reinstall re-provisions without orphaning the account; a revoked key is rejected
and its revocation propagates; the signature suite can rotate without breaking
older records.

- [ ] Implement **key provisioning + server-signed presence records**, with the **signature suite pinned in the envelope** (crypto-agility) so the algorithm can rotate without a flag day, and **rate-limited provisioning** (0.6) so key issuance cannot be abused.
- [x] Implement **client-side device-key provisioning + receipt signing** — the *producer* side 3.3 verify depends on and the piece **missing from the shipped code**: the client generates a per-device keypair held in platform secure storage (0.6/0.9), the server **certifies its public half and binds it to the account** (3.1) at rate-limited provisioning, and the client **signs each 3.0 envelope** before it enters the 2.9 queue. Without this, 3.3 has nothing to verify. *(⏭ hardened later: device attestation + hardware-backed key storage are the 0.6 implementation; here the keypair + signing + account binding exist.)*
- [ ] Stand up the **presence store + query seam** — who is signable / present, the inputs matchmaking + referrals read — because signing alone is not enough: 4.5 routing and the 5.x social systems need to *read* signed presence, so the store + query path exists here even though its consumers land later. Presence is a **hot, read/write-heavy, DB-connection-bound dataset (the C-3 #3 driver)**, so the query seam is designed against a connection budget + a short cache TTL from the start, not left to scale by accident.
- [ ] Implement the **revocation list + public-key publication** with a **cacheable, versioned distribution** (ETag / TTL) and a **documented propagation-latency budget** so clients drop revoked entries cheaply and predictably (0.10) — the seam §17 revocation and Phase 7.3 moderation consume.
- [x] Implement **key recovery on reinstall / device-switch** against the server-authoritative identity (3.1) so a returning player re-provisions rather than orphaning presence / ownership.
- [x] Implement **key-rotation readiness**: overlapping validity windows and re-signing of long-lived records, so rotation never invalidates an in-flight signed artifact.
- [x] *(⏭ hardened later)* **Signing-key custody + rotation cadence** (HSM/KMS locations, access control, rotation schedule) is the 0.6 key-custody plan's server implementation — the **interface + rotation mechanism** land here; production custody lands in the hardening pass / Phase 7.6. **No private key in-repo.**
- [ ] **Test:** a valid presence record verifies; a tampered one fails; a revoked key is rejected and revocation propagates to a client within the budget; a reinstall re-provisions; a record signed under the previous suite still verifies during the rotation window; provisioning is rate-limited.

### 3.6 — Patient ownership arbitration & lifecycle (C-8)

**What.** Encode the [C-8](../specs/PATIENT-LIFECYCLE.md) §18 state machine
exactly — `pool ⇄ owned`, `owned → owned′` (referral), `owned ⇄ hospitalized`,
`owned → cured → archived`, `owned → archived` — all server-arbitrated, with
single-owner locking, idempotent transitions, and the audit trail.

**Why.** GM-1: the first server artifact must not contradict the transitions the
mechanics require. Single-owner exclusivity is the **double-assignment analog of
double-spend** — it must be a real concurrency guarantee, not a UI convention.

**How.** Makes the 2.3 local case lifecycle server-arbitrated, with every
transition an idempotent, audited, concurrency-safe operation the client can only
*propose*.

**Validation.** Every legal transition is exercised by a test; every illegal
transition (esp. `hospitalized → archived`, double-owner, client-initiated
transfer) is rejected; concurrent transfer attempts resolve to exactly one owner.

- [x] **Map the local `CaseLifecycle` (2.3) onto the C-8 ownership machine before encoding it** — they are *different vocabularies*, not the same names (lifecycle correction above). The shipped offline enum (`open`/`in-treatment`/`crisis`/`cured`/`abandoned`/`hard-failed`/`archived`) is the *treatment* view; C-8 is the *ownership* view (`pool`/`owned`/`hospitalized`/`cured`/`archived`). Define + document the mapping (`crisis → hospitalized`, `open`/`in-treatment → owned`, `abandoned → owned → pool`, `hard-failed → owned → archived`) and note the server introduces `pool` (unowned), which has **no offline single-owner equivalent** — so 3.6 layers the ownership axis onto the treatment states rather than renaming them.
- [x] Implement the **authoritative owner record + single-owner lock** (the double-spend analog) with **optimistic concurrency** so two simultaneous `pool → owned` claims resolve to exactly one owner, the other cleanly rejected.
- [ ] Implement the **full C-8 lifecycle state machine** — `pool ⇄ owned`, `owned → owned′`, `owned ⇄ hospitalized`, `owned → cured → archived`, `owned → archived` — each transition with its **server-enforced guard** (routing eligibility; **referral compatibility: receiver free + compatible + similar-tier** per C-8; freeze-trigger recording; cure computed / accepted server-side).
- [ ] Make every transition **transactional, idempotent + audited**: ownership changes commit in the 3.0 atomic transaction alongside any profile/ledger effect, a retried transfer / referral applies once (3.0 idempotency), and every transition writes to the hash-chained audit trail (3.3) with its trigger recorded (in-fiction derangement vs bug-recovery, per C-8).
- [ ] Integrate the **3.4 ownership lease**: a transition proposed against an expired or reclaimed lease is reconciled, not applied — ownership and the offline protocol share **one** authoritative lock.
- [x] Enforce the **illegal-transition rejections by construction**: `hospitalized → archived` direct, double-owner, and any client-initiated ownership change without a server round-trip.
- [ ] Enforce **`memory_class` discipline**: stateless / social-chronic patients follow the states minus a persistent history envelope (§17 / C-8), matching the 2.4 local rule.
- [ ] **Test (incl. concurrency):** every legal transition passes; the local→C-8 mapping is covered (a local `crisis` freeze surfaces as `hospitalized` under the same owner); re-pool on walkout / transfer, referral hand-off, and temporary hospitalization are covered; every illegal transition is rejected; **many concurrent double-claims yield exactly one owner** under load; a retried transition does not double-apply.

### 3.7 — Server observability, resilience & deployment

> **Current execution boundary:** Local load/cold-start/restore and deployment-definition tests are authorized. No cloud provision/deploy, production rollout or public endpoint is authorized; live production SLO/custody/rollout acceptance remains pending.

**What.** Wire the server into the 0.7 observability conventions (structured
logging, metrics, correlation-id tracing across the trust boundary),
health/readiness/liveness, graceful degradation, the config feature-flag +
kill-switch surface, the deployment shape sized for C-3 scale-to-zero, and the
migration/rollback runbook — plus the declared-now secret-management interface.

**Why.** An authoritative service that cannot be observed, degraded safely,
deployed cheaply, or rolled back is an operational liability. These are the
reliability / efficiency foundations every 3.x endpoint inherits, established
alongside 3.0 and hardened as the endpoints land.

**How.** Turns the 0.7 trust-boundary logging / metrics / versioning conventions
into a running, deployable service on the C-3 cost posture.

**Validation.** A single correlation id spans client → (native) → server logs for
one session; metrics expose the C-3 cost signals; a feature flag / kill-switch
disables a subsystem without a deploy; a bad deploy rolls back; cold start meets
the scale-to-zero budget.

- [x] Implement **server-side structured logging** on the 0.7 schema (the same rendered line + JSON payload, secrets redacted, **never a raw transcript** §17) via the Go `psylog` package, with **correlation / session-id propagation across the trust boundary** so one session's client + server lines share an id.
- [x] Implement the **0.7 metrics contract** server-side (counters / timers / gauges: receipt accept/reject rate, validation latency, per-receipt compute cost, auth failures, store latency + pool saturation, queue depth) — the minimal signal set the C-3 cost model and the Phase 6.6 balance oracle consume — and define **SLOs + alert thresholds** (accept-latency p95, error rate, store saturation) so a regression pages rather than silently degrades.
- [ ] Add **request tracing spans** across the request lifecycle (auth → decode → verify → validate → commit) keyed to the correlation id, so a slow or failing receipt is diagnosable without a transcript.
- [ ] Implement **health / readiness / liveness + graceful degradation**: extend the existing Phase 0.1 `/health` stub into a **split readiness (can-serve / deps up) vs liveness (process healthy)** probe, add dependency health checks, a circuit-breaker / degrade path when the store is slow, and the 3.3 load-shedding tie-in so partial failure never cascades.
- [ ] Implement the **server-side feature-flag + kill-switch surface** (0.2): receipt validation, matchmaking, and the economy have a documented off-switch, and the `ruleset_version` sunset has a runtime toggle, so a bad release degrades safely without an app-store push.
- [ ] Implement the **deployment shape + cold-start budget** for C-3 **scale-to-zero** (the Go static-binary advantage from ADR-0006) with a **canary / rollback-capable rollout**, and a recorded cold-start / warm-latency baseline against the cost model.
- [ ] Run a **load / soak test against the C-3 concurrency cap** (the #3 cost driver): sustained receipt-submission + handshake load holds p95 latency and the per-receipt compute budget, and back-pressure / load-shedding engages instead of collapsing — "it compiles" is not a scale proof.
- [x] Define the **audit-trail + metrics/log retention + redaction policy** (0.7 / 0.6 data-lifecycle): how long forensic and observability data live, redacted of PII, so retention is a decision, not an accident (integrity).
- [x] Define the **receipt + anomaly-history retention / age-to-aggregate policy** — a named **C-3 cost lever** for the #2 write-heavy driver: raw accepted receipts age out on a bounded window while the **derived aggregates are kept** (the 3.3 provenance signal, the hash-chained audit trail, the ledger snapshots), so the largest write-heavy dataset stays cost-bounded without losing the forensic + anti-farming trail. **No raw transcript is ever retained** (§17).
- [x] Write the **migration + rollback runbook** (3.0 migrations) so a schema change is deployable and revertible under a documented procedure.
- [x] *(⏭ hardened later)* **Secret management**: the config authority resolves secrets **by reference** (0.2 / 0.6) and the interface exists here; the production secret store / rotation (KMS / Vault) is the 0.6 secret-handling implementation, landing in the hardening pass / Phase 7.6. **No secret value committed.**
- [ ] **Test:** a correlation id + trace threads client → server for one flow; a kill-switch disables a subsystem in a test; a simulated store outage degrades rather than crashes; the cold-start + load baselines are measured and recorded.

### 3.8 — Phase 3 integration harness & exit report

**What.** Build the client↔server integration test harness (the precursor to the
Phase 5.6 network sandbox), expand the Dart↔Go contract tests, add failure
injection, ship the Phase 3 capability showcase, and record a Phase 3 exit report
with an explicit go/revisit decision before Phase 4 spend.

**Why.** "The endpoints compile" is not a pass — exactly as 1.6 and 2.10 insist.
The authoritative spine must be proven end-to-end (a client boots,
authenticates, submits validated receipts, survives offline/online transitions,
and every ownership transition matches C-8) as recorded, reproducible evidence,
and Appendix B now requires a capability showcase per phase.

**How.** Reuses the single deterministic core (0.1) driving a real client against
a local server stack, converting Phase 3 into a recorded de-risking decision
point.

**Validation.** The end-to-end loop passes against a local server; failure
injection (timeouts, duplicate / partial submissions, reconnect) is survivable;
the exit report records auth, receipt-validation, offline-reconciliation, and
ownership results with the decision stated.

- [x] Stand up the **client↔local-server integration harness** (headless where possible) — the reduced precursor to the Phase 5.6 sandbox — exercising boot handshake → receipt submission (single + batched) → offline queue drain → ownership transition end-to-end.
- [ ] **Expand the Dart↔Go contract + integration tests** (0.5): the full **reconciled** receipt (incl. the typed `start_state`, ordered actions, and `LedgerEvent` list) / **signed envelope** / profile / presence schemas round-trip **byte-identically** — a **regression test that fails on any camelCase/snake_case, stale-schema-version, or missing-field drift**, closing the 3.0 fork permanently — and the auth / validation / ownership flows pass against the running service.
- [ ] Implement **failure injection** (timeouts, duplicate + partial + batched submissions, disconnect / reconnect, expired lease, store slowness) proving exactly-once + reconciliation + graceful degradation hold under adverse conditions (0.10 / 3.4 / 3.7).
- [ ] Include a **lightweight load pass** in the harness (a burst of concurrent receipts + claims) that reproduces the 3.6 concurrency and 3.7 backpressure behaviour, so the exit report cites measured numbers, not assertions.
- [ ] Ship the **Phase 3 capability showcase** (Appendix B): headless scripts under `tools/showcase/phase3/` emitting human-readable Markdown to `docs/reports/showcase/phase3/` demonstrating auth, receipt + ledger validation, offline reconciliation, and the ownership state machine — it **demonstrates**, never substitutes for `make verify`.
- [ ] Record the **Phase 3 exit report** in `docs/reports/` under the 1.6 / 2.10 template: auth coverage, receipt accept/reject + ledger-conservation behaviour, offline-reconciliation results, C-8 transition coverage, and cost / cold-start / load baselines (C-3), with an explicit **go / revisit decision** before Phase 4 spend.

---

## Phase 4 — Content Pipeline & Distribution

**Goal.** Turn the server into the authoritative content factory: nine-axis
manifest generation, the two-pass validation gate, signing, CDN delivery, and
the matchmaking/adaptive router.

**Scope id.** `phase-4`

**Why now.** With authoritative state (Phase 3) in place, cases can be generated,
validated, signed, and routed to the right players at scale.

**Validation.** A generated case passes validation, is signed, delivered from the
CDN, and routed to an eligible player; matchmaking never assigns an unfetchable case.

### 4.1 — Patient manifest schema v1 (nine-axis + enriched)

**What.** Formalize the full manifest: nine synthesis axes (§12) plus the
enriched identity/clinical/memory/progression/narrative/behavioral fields (§17).

**Why.** This is the content contract every downstream system reads.

**How.** Replaces the PoC minimal manifest with the production schema.

**Validation.** Schema versioned + checksummed; `memory_class` (stateless vs
persistent) enforced.

- [ ] Define the versioned nine-axis + enriched manifest schema in `packages/`.
- [ ] Enforce `memory_class` discipline (stateless carries no history envelope).
- [ ] Add checksum + schema-version fields for revocation/rollback.

### 4.2 — Content generation pipeline

**What.** Implement server-side nine-axis synthesis: structured author input +
procedural variation → a compiled manifest with difficulty/volatility/reward
metadata (§2.1).

**Why.** This is how the case pool scales beyond hand-authoring.

**How.** Feeds the validation gate and the catalog.

**Validation.** Generated cases stay within their intended progression tier.

- [ ] Implement nine-axis assembly + procedural variation within tier bounds.
- [ ] Compile manifests with reward metadata + versioned checksum.
- [ ] Keep real diagnostic labels out of all generated content (fictional taxonomy only).

### 4.3 — Validation & safety gate

**What.** Implement the two explicitly separate passes (§2.2): mechanical
solvability (bots, every manifest, no LLM) and sampled acting-quality QA (LLM,
periodic), plus toxicity/safety screening.

**Why.** No case ships unwinnable, unsafe, or off-tone.

**How.** Reuses the Phase 2.8 bot harness for cheap per-manifest solvability.

**Validation.** Unsolvable/unsafe candidates are rejected; acting QA runs on a
sample + after model updates.

- [ ] Implement structural + gameplay (mechanical solvability) validation via the bot harness.
- [ ] Implement sampled acting-quality QA (LLM in the loop, periodic).
- [ ] Implement toxicity/safety screening + versioning/rollback.

### 4.4 — CDN delivery & signing

> **Current execution boundary:** Implement and test signing, delivery, client verification and revocation against a local object-store/CDN adapter. Public CDN deployment and live delivery evidence remain pending under the no-cloud/no-publishing restriction.

**What.** Implement signed-manifest delivery from a CDN/object store fronted by
the server (§2.3, §3).

**Why.** Structured, cacheable payloads keep delivery cheap at every MAU tier.

**How.** Separates heavy narrative data from the primitive profile store.

**Validation.** Clients fetch signed manifests; matchmaking only returns fetchable references.

- [ ] Implement manifest signing at publish time.
- [ ] Implement CDN/object-store delivery + client fetch/verify.
- [ ] Wire revocation so quarantined manifests can no longer be fetched.

### 4.5 — Matchmaking & adaptive router

**What.** Implement the canonical server-side routing function (§2.3, §13):
reputation + study-field coverage + pricing + operational pressure, the
social-chronic bias for newcomers/recovering clinics, and the tenure-gated
chaos roll.

**Why.** Routing is the single owner of case assignment; the display formulas are
just UI.

**How.** Delivers the right difficulty to the right player and protects new players.

**Validation.** New/low-rep players get social-chronic cases; the chaos roll never
fires below the tenure gate.

- [ ] Implement the canonical multi-factor routing function server-side.
- [ ] Implement the social-chronic bias for early-career + sub-recovery-threshold players.
- [ ] Implement the tenure-gated chaos roll + the three strategic-exit choices (reject / refer / force).

---

## Phase 5 — Networked Social & Economy Systems

**Goal.** Build the cross-player systems: the multi-currency economy, the living
revocable case history, the trauma multiplier with anti-collusion guards, the
referral/hospital ecosystem, and the server-derived hidden quantities.

**Scope id.** `phase-5`

**Why now.** These depend on authoritative state (Phase 3) and content
distribution (Phase 4). They are the systems most vulnerable to exploits, so
they come after the validation spine exists.

**Validation.** Economy sources/sinks balance in the sandbox; farming loops are
provably unprofitable; hidden quantities are server-derived, never client-trusted.

### 5.1 — Multi-currency economy engine

**What.** Implement the currency system (currency, study/subspecialty points, XP,
reputation, prestige, royalties) with modelled sources and sinks per the C-4 spec
(§9, §19).

**Why.** A multi-currency economy without modelled sinks inflates or dead-ends.

**How.** Gives every currency a purpose and every payout a server-side owner.

**Validation.** Sandbox shows no runaway inflation or dead currency.

- [ ] Implement the currencies + their sources/sinks from the balance spec.
- [ ] Route all high-value payouts through server-side computation.
- [ ] Re-run sandbox economy checks (inflation / dead-currency / sink coverage).

### 5.2 — Living case history (revocable signed memory)

**What.** Implement the server-signed, tamper-evident, revocable history envelope
(§17): pseudonymous therapist IDs, cards, meds, outcome, schema version.

**Why.** Narrative continuity must coexist with moderation and data-erasure duties.

**How.** Lets patients reference past treatment while keeping deletion enforceable.

**Validation.** Edited entries fail signature; revoked entries are dropped by clients.

- [ ] Implement the signed history envelope + schema versioning.
- [ ] Implement the revocation list + client-side drop/ignore of revoked entries.
- [ ] Enforce pseudonymous IDs only (no real PII in the ledger).

### 5.3 — Trauma multiplier & anti-collusion (C-9 part 1)

**What.** Implement the Trauma Severity Index as a **server-side** function over
signed history, and the anti-collusion/provenance guards (§17).

**Why.** An unguarded multiplier is a farming exploit; severity must never be
client-reported.

**How.** Makes "hunt for broken cases" pay while "manufacture broken cases with an
accomplice" does not.

**Validation.** A→B→A loops earn nothing; genuine broken-case referrals still pay.

- [ ] Implement server-side Trauma Severity Index accrual from accepted receipts.
- [ ] Implement the multiplier cap, chain decay, and provenance carve-out.
- [ ] Implement payout-outlier anomaly detection + A→B→A rejection.

### 5.4 — Referral & mental hospital ecosystem

**What.** Implement server-mediated referrals (structured envelope only) and the
freeze/unfreeze hospital loop with its two converging triggers (§18).

**Why.** Patients are never silently lost; every transition is accounted for.

**How.** Completes the lifecycle with real hand-off and recovery paths.

**Validation.** Referrals transfer ownership server-side; hospitalized cases return
to the same owner; triggers are recorded distinctly.

- [ ] Implement server-mediated referral (history envelope + deltas; never transcripts).
- [ ] Implement the freeze/unfreeze hospital loop (owned ⇄ hospitalized).
- [ ] Record which trigger (in-fiction derangement vs bug-recovery) fired, for clean analytics.

### 5.5 — Doubt, transfer & operational pressure (C-9 part 2)

**What.** Derive Doubt and operational pressure **server-side** from accepted
receipt history; execute the transfer roll server-side (§12, §23).

**Why.** Client-owned Doubt/pressure would let players suppress the pressure meant
to constrain them.

**How.** Makes patient retention and routing inputs trustworthy.

**Validation.** Doubt/pressure are never client-trusted; the transfer roll is
server-authoritative and rare-by-design.

- [ ] Implement server-side Doubt accrual + the server-executed transfer roll.
- [ ] Implement server-side operational pressure from receipt cadence + case tier.
- [ ] Feed operational pressure into the routing function as a trusted input.

### 5.6 — Realistic client/server integration sandbox

**What.** Build the high-fidelity network sandbox (§3): multiple clients vs a
local server stack, failure injection, client-state reproduction.

**Why.** Distinct from the balance sandbox — this de-risks runtime/networking
behavior before wider testing.

**How.** Surfaces reconnect, matchmaking, and hand-off bugs early.

**Validation.** Timeouts, partial fetches, and reconnects are reproducible and survivable.

- [ ] Stand up the multi-client + local-server integration environment.
- [ ] Implement failure injection (timeouts, partial/duplicate fetches, disconnects).
- [ ] Implement client-state reproduction for transfer/interruption/reassignment scenarios.

---

## Phase 6 — Institutional Endgame & UGC

**Goal.** Ship the endgame roles and the creator ecosystem: Medical Director
authoring, creator royalties, the Group Practice corporate system with its
oversight dashboard, the open authoring portal, macro events, and the balance
oracle.

**Scope id.** `phase-6`

**Why now.** These are explicitly endgame-gated (§7) and depend on the full
economy + content spine. Two roles (Medical Director, Corporate) unlock here.

**Validation.** A veteran player can author + publish a case (validated/signed),
hire associates with oversight, and earn royalties under anti-farming guards.

### 6.1 — Medical Director dashboard & authoring

**What.** Implement the Medical Director template-authoring panel with the
mandatory test-interview gate (§21).

**Why.** Veteran players become content suppliers; the test interview blocks broken files.

**How.** Feeds the shared case pool through the same validation/signing pipeline.

**Validation.** A template cannot publish until its author completes a successful test session.

- [ ] Implement the manifest template-authoring panel.
- [ ] Implement the mandatory validation test-interview gate.
- [ ] Route submissions through the Phase 4.3 validation + signing pipeline.

### 6.2 — Creator royalties & anti-farming (mirrors §17 discipline)

**What.** Implement royalties that accrue only on server-validated fee-payment
and cure events — never raw downloads — with per-player-per-case dedupe, rate
caps, and anomaly detection (§21).

**Why.** Download-triggered royalties are a currency printer (Sybil loops).

**How.** Applies the trauma-multiplier anti-farming rigor to the second creator economy.

**Validation.** Looped downloads mint nothing; genuine treatment/cure events pay once per pair.

- [ ] Implement royalty accrual on validated fee/cure events only.
- [ ] Implement per-player-per-case dedupe + per-creator rate caps.
- [ ] Implement payout-outlier anomaly detection.

### 6.3 — Group Practice & oversight dashboard

**What.** Implement the corporate sub-system (§24): jointly-gated hiring
(level + owned clinic tier), progressive hire slots, the shared deck library,
the +5 capability ceiling, diminishing-returns yields, and the accountability
damage matrix — plus the oversight dashboard.

**Why.** Corporate play must not become strictly dominant or unmanageable.

**How.** Adds the top institutional layer while protecting the solo fantasy.

**Validation.** Hiring requires both gates; yields diminish under a cap; the
dashboard surfaces at-risk associates before blow-ups.

- [ ] Implement the joint hiring gate + progressive hire-slot unlocks.
- [ ] Implement the shared deck library + the +5 associate capability ceiling.
- [ ] Implement diminishing-returns employer yields + the accountability/damage matrix.
- [ ] Implement the oversight dashboard (roster health, early-warning signals, bounded interventions).

### 6.4 — Open authoring portal & moderation (C-10)

> **Current execution boundary:** Build and exercise the complete portal workflow against the local catalog. Public portal opening remains pending and unauthorized; actual reviewer staffing/SLA acceptance requires human capacity, not a drafted policy.

**What.** Open the web authoring portal to external contributors (§2.4) **only
after** the moderation staffing model + review SLA exists.

**Why.** Human review cost scales with creator count; an unstaffed queue is a trap.

**How.** Turns the project into a modular content platform, safely.

**Validation.** The portal opens behind a defined reviewer capacity + turnaround SLA.

- [ ] Define the moderation staffing model + review SLA (C-10) before opening the portal.
- [ ] Implement the draft → preview → validate → version → publish workflow.
- [ ] Implement study-field authoring + progression tuning contributions.

### 6.5 — Macro events & environmental matrix

**What.** Implement server-seeded macro events (§22): sociopolitical shifts and
meteorological events that warp patient profiles across the player base.

**Why.** Macro events keep the shared world dynamic and re-engaging.

**How.** Adds global variance layered on top of individual routing.

**Validation.** A seeded event measurably shifts baseline attraction/agitation.

- [ ] Implement server-side macro-event seeding + client push.
- [ ] Implement sociopolitical profile-warping multipliers.
- [ ] Implement meteorological temporary multipliers (side-effects, somatic triggers).

### 6.6 — Adaptive master playbook (balance oracle)

**What.** Implement the private, designer-only adaptive card-benchmarking oracle
(§11) — server-side/offline on privacy-scrubbed telemetry, never shipped to client.

**Why.** Keeps card balance coherent as patient states evolve; a post-launch tool.

**How.** Prevents dominant/useless deck drift across the whole card system.

**Validation.** The oracle recommends decks + confidence bands offline; nothing
ships to the client.

- [ ] Implement the solver over evolving patient states (offline/server-side).
- [ ] Implement the privacy-scrubbed telemetry pipeline that feeds it.
- [ ] Expose the private designer diagnostic output (recommended deck, win-band, confidence).

---

## Phase 7 — Presentation, Monetization & Launch

**Goal.** Take the system to ship-ready: the Disco-Elysium ink-wash presentation
layer, monetization SKUs under the enforced SKU test, the moderation backdoor,
cosmetic-layer hooks, age-rating finalization, and the release process.

**Scope id.** `phase-7`

**Why last.** Presentation and monetization ride on a proven, safe system.
Cosmetics are explicitly post-launch; the launch gate is where legal/store
exposure is finalized.

**Validation.** The app passes its own SKU test, has a finalized age rating +
disclaimers, a working moderation backdoor, and a documented release process.

### 7.1 — Ink-wash presentation layer

**What.** Implement the painterly **Disco-Elysium ink-wash** visual language
(§20): layered portraits, Flutter fragment shaders, and the
psychological-fracture effect on failure states — sourced from an **offline
art-generation pipeline** built on **Google Gemini 2.5 Flash Image ("nano
banana")**.

**Why.** The aesthetic is core to the product's identity and immersion — style
and atmosphere are a primary draw that pull players into the game's emotional
world, not a cosmetic afterthought. A named, disciplined generation pipeline is
what keeps the whole cast visually coherent.

**How.** Turns the functional UI into the intended emotional experience, with a
reproducible content-build asset pipeline that never becomes a runtime
dependency.

**Validation.** Calm/agitated states render distinctly; fracture effects fire on
Manipulative failure; runtime cost stays low + offline-capable; the app makes no
image-API calls during play.

- [ ] Establish the **offline art-generation pipeline** using **Gemini 2.5 Flash Image ("nano banana")** at *content-build time*: a shared **ink-wash style preamble** (§20 palette/brushwork/ink-contour descriptors) prepended to each per-character prompt so the whole cast shares one visual language, producing the transparent portrait + background layers. No image model runs on-device and there are **no runtime image-API calls** — the app ships baked layers (offline-first §1, fixed footprint §5).
- [ ] Resolve the **nano-banana API key through the config authority / secrets reference** (0.2/0.6) — used only by the offline tooling, never committed and never shipped in the client.
- [ ] Store each asset's **prompt + generation params (model version, seed)** alongside the asset for reproducible regeneration and provenance (the visual analog of the 0.12 content-integrity discipline).
- [ ] Implement the layered asset pipeline (static portrait + animated paint background).
- [ ] Implement Flutter fragment shaders for the ink-wash motion.
- [ ] Implement the chromatic-fracture overlay triggered by high-agitation/derangement events.

### 7.2 — Monetization SKUs & the SKU test

**What.** Implement the revenue SKUs and in-game currency sinks (§19), each run
through the enforced non-pay-to-win SKU test.

**Why.** Monetization must never gate core progression or session outcomes.

**How.** Funds sustainability (feeds the C-3 cost model) without pay-to-win.

**Validation.** Every SKU passes the SKU test or is cut/converted; decks are
validated as sidegrades in the sandbox.

- [ ] Implement real-money SKUs (premium case packs, sidegrade decks, identity packs, hard-capped subspecialty points).
- [ ] Implement in-game currency sinks (study points, emergency consultations, practice modes).
- [ ] Enforce the SKU test on every item; validate decks as sidegrades.

### 7.3 — Governance & moderation backdoor

**What.** Implement the secure administrative control plane (§2.5): ban/suspend,
revoke privileges, quarantine/replace manifests, freeze suspicious content.

**Why.** A final authority for safety and anti-cheat is non-negotiable at launch.

**How.** Backs the whole open-content model with real enforcement capacity.

**Validation.** Admin actions take effect on authoritative state + the delivery layer.

- [ ] Implement account ban/suspend + privilege/reputation revocation.
- [ ] Implement manifest quarantine/replace + delivery-layer pull.
- [ ] Wire moderation actions into the revocation list.

### 7.4 — Cosmetic-layer hooks (deferred content, ready architecture)

**What.** Ship the theming hooks, skin-slot architecture, and CDN cosmetic path —
without any cosmetic SKU (§19).

**Why.** Cosmetics are post-launch, but the architecture must support them with
zero later rework.

**How.** Lets a future release add cosmetics as content, not an architecture change.

**Validation.** A test theme loads through the skin-slot path; no cosmetic SKU ships.

- [ ] Implement theming hooks + skin-slot architecture in the client.
- [ ] Wire the CDN cosmetic delivery path (unused at launch).
- [ ] Confirm no cosmetic SKU ships at first production.

### 7.5 — Age-rating finalization & legal safety (C-6 close)

**What.** Finalize the mature-band age rating, Manipulative-card tone guidelines,
disclaimers, PII separation, and entertainment-focused store metadata (§8).

**Why.** The manipulate-into-derangement loop will be read harshly; this makes it
defensible before submission.

**How.** Clears the store-review and legal exposure gate.

**Validation.** Rating + disclaimers + metadata finalized; no real health data
stored; PII kept separate from gameplay data.

- [ ] Finalize the age-rating strategy + Manipulative-card tone guidelines (closes C-6).
- [ ] Add explicit fictional-simulation disclaimers throughout.
- [ ] Confirm PII/gameplay-data separation + entertainment-focused store metadata.

### 7.6 — Launch readiness & release process

> **Current execution boundary:** Build and test local release preparation, provenance and dry-run definitions only. Actual signing/distribution for release, store submission and publishing remain excluded; unavailable target hosts/credentials and real release acceptance remain pending.

**What.** Establish the release process: build/sign/distribute across the five
platforms, a `CHANGELOG.md`, and a launch checklist.

**Why.** A repeatable release process is what makes "done" shippable and iterable.

**How.** Closes the loop from working software to a real product.

**Validation.** A release candidate builds + signs for all target platforms; the
checklist passes.

- [ ] Implement per-platform build/sign/distribute pipelines.
- [ ] Implement the **reproducible/verifiable signed-release build** on the 0.1 pinned build inputs — deterministic build, recorded toolchain + dependency hashes, provenance audit — across the five platforms.
- [ ] Add `CHANGELOG.md` + document the release process.
- [ ] Run the launch checklist against a release candidate.

---

## Appendix A — Tracking conventions

- One `run_id` per implementation pass through a phase.
- `scope` column on every row = the phase id (e.g. `phase-2`) or sub-phase
  (`phase-2.3`).
- One `action=commit, status=completed, commit_sha=pending` row per logical
  commit, with the `summary` in Conventional Commits format. See
  [`docs/tracking/tracking.schema.md`](../tracking/tracking.schema.md).

## Appendix B — Definition of done

A phase is **done** when:

1. Every `[ ]` bullet under its heading is `[x]`.
2. The phase's *Validation* line passes on a clean tree.
3. `make doctor` exits 0.
4. The status snapshot at the top of this file has been updated.
5. Load-bearing logic touched by the phase (per Principle 4) has tests that
   move with the code in the same commit.
6. The phase's run produced one or more `commit` tracking rows whose
   `[run-id]` trailers all appear in `git log`.
7. A **capability showcase** ships for the phase: headless scripts (no Flutter,
   no model, no network) that demonstrate the phase's features and emit
   human-readable Markdown a non-technical reader can follow. It **demonstrates**
   capabilities and never substitutes for `make verify`, which stays the
   verification of record. See the
   [`phase-showcase`](../../.agents/skills/phase-showcase/SKILL.md) skill.
   **Reference example (Phase 2):** scripts in
   [`tools/showcase/phase2/`](../../tools/showcase/phase2/) (shared helper
   [`report.dart`](../../tools/showcase/report.dart)), runner
   [`scripts/showcase.sh`](../../scripts/showcase.sh), reports under
   [`docs/reports/showcase/phase2/`](../reports/showcase/phase2/) (start at
   [`INDEX.md`](../reports/showcase/INDEX.md)); run `bash scripts/showcase.sh`
   to regenerate.

## Appendix C — Blueprint cross-reference map

Which [`STARTER.md`](../design/STARTER.md) sections each phase realizes.

| Phase | Blueprint sections |
|---|---|
| 0 — Foundations & Corrections | §1 (day-one inputs), §3 (cost model), §8 (age rating), §9 (balance spec) |
| 1 — Runtime PoC | §1, §4, §5, §6 |
| 2 — Deterministic Game Core | §4, §5, §9, §10, §11, §12, §13, §14, §15, §16, §17, §18, §22, §23 |
| 3 — Server Control Plane | §1, §3, §12, §18 |
| 4 — Content Pipeline | §2.1–§2.4, §3, §12, §13, §17 |
| 5 — Social & Economy | §3, §9, §12, §17, §18, §19, §23 |
| 6 — Endgame & UGC | §2.4, §11, §21, §22, §24 |
| 7 — Presentation & Launch | §2.5, §8, §19, §20 |
