# 🗺 Psychosims — Technical Roadmap

> **Single source of truth for sequenced work.** Agents implement against this
> file phase-by-phase, drain every `[ ]` bullet in scope, append a tracking row,
> then stage. Humans push via `make git`.
>
> **Source blueprint:** [`STARTER.md`](../../STARTER.md) (§1–§24). Every phase
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
| 0 — Foundations & Conceptual Corrections | 92 | 11 | 🟡 in progress |
| 1 — Minimal Cross-Platform Runtime (PoC) | 74 | 0 | ⚪ planned |
| 2 — Deterministic Game Core (offline) | 26 | 0 | ⚪ planned |
| 3 — Server Control Plane & Authoritative State | 22 | 0 | ⚪ planned |
| 4 — Content Pipeline & Distribution | 15 | 0 | ⚪ planned |
| 5 — Networked Social & Economy Systems | 18 | 0 | ⚪ planned |
| 6 — Institutional Endgame & UGC | 19 | 0 | ⚪ planned |
| 7 — Presentation, Monetization & Launch | 19 | 0 | ⚪ planned |
| **Total** | **285** | **11** | |

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

**All ten artifacts now exist under [`docs/specs/`](../specs/README.md)** (see the
Artifact column). C-1…C-6 (the Phase 0.3 documentation deliverables) are complete;
C-7…C-10 have authoritative specs their implementation phases build against.

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
Dart, native, and server stacks; CI runs build/lint/format/test on every push;
the secret-scan gate catches a planted secret; the six Phase 0.3 correction
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

- [ ] Create the monorepo skeleton (`app/`, `server/`, `packages/`, `content/`, `config/`, `tools/`) with a top-level `README` in each, matching `ARCHITECTURE.md`.
- [ ] Decide + record (ADR) the **server runtime/language** so `packages/` sharing (one schema vs two) and the toolchain are unambiguous; stand up a minimal server health-check stub rather than leaving the shape deferred.
- [ ] Define the Flutter client layout (`app/lib/core/` pure, `app/lib/features/`, `app/lib/shared/`) and codify the "core has no I/O, no model calls" boundary.
- [ ] **Settle the physical home of the pure deterministic core** so the `app/` client and the headless `tools/` bots + sandbox import **one** implementation — resolve `app/lib/core/` vs a shared `packages/` package now (and update [`ARCHITECTURE.md`](../code/ARCHITECTURE.md) if it moves), because Phase 2.8 solvability bots and Phase 4.3 validation both run the core outside the app and a duplicated core would silently drift from the shipped rules.
- [ ] **Declare the native/FFI module home** — the llama.cpp C/C++ binding layer and its build inputs — so Phase 1.1's inference path and Phase 0.7's C++ logging shim land in a declared module, not ad-hoc under `app/`.
- [ ] Declare the **cross-platform build matrix** (the five target platforms) and which are validated when — Linux desktop + x86 Android emulator in Phase 1; the rest deferred.
- [ ] Add the language toolchains with **pinned versions** — Flutter/Dart, the chosen server runtime, **and the native C/C++ toolchain (clang/NDK) for llama.cpp** — plus a `make`-level build/lint/format gate wired into `make doctor`.
- [ ] Establish a **reproducible dev-environment bootstrap** (a pinned SDK/version manifest + a one-command setup such as a devcontainer or bootstrap script) so "compiles on Linux" holds identically on any dev machine and in CI, not just locally.
- [ ] Provide a **single monorepo task orchestrator** (one `make`/workspace entry point that builds, tests, lints, and formats every module the same way locally and in CI) so no module invents its own commands and the 0.5 gate wraps one interface, not five.
- [ ] **Pin and record build inputs** as a convention from day one (deterministic toolchain + dependency hashes, a lockfile-backed build manifest), so the reproducible/verifiable signed-release build and provenance audit can be *implemented* at Phase 7.6 without a retrofit — the build-side complement to the signing-key custody plan (0.6) and [ADR-0002](../design/ADR-0002-desktop-distribution-and-auth.md).
- [ ] **Declare where generated code lands** (schema/serialization codegen from `packages/`, FFI bindings) — a committed-vs-generated boundary + a "generated is never hand-edited" rule — so the 0.8 shared-schema contract has an unambiguous, reviewable output home.
- [ ] Define the **large-binary policy**: the ~1.8 GB GGUF model and build artifacts are **never committed** — declare `.gitignore` + `.gitattributes` (LFS or, preferably, out-of-band fetch-on-first-run) and a checksum-verified fetch step that Phase 1 consumes (integrity closed in 0.6).
- [ ] Document the structure, the "where does new code go?" rule, and add a `CODEOWNERS` map for the module boundaries.

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

- [ ] Design + implement the typed config schema + loader (see [`DESIGN-centralized-configuration.md`](../design/DESIGN-centralized-configuration.md)), grouped `network` / `model` / `promptBudget` / `balance` / `featureFlags` / `secretsRefs`.
- [ ] Add startup validation with actionable errors; fail fast; reject unknown keys and out-of-range values.
- [ ] Implement environment overlays (dev / staging / prod **plus a `test`/CI overlay**) as validated layers over one base schema, so tests and CI run against deterministic, validated config rather than ad-hoc values.
- [ ] Provide DI access and add a **lint/CI rule that fails the build on any raw environment read** outside `config/` (closes the DESIGN doc's open enforcement item).
- [ ] Bind **all balance constants** to the config `balance` group sourced from the C-4 balance spec — no constant duplicated in a feature (Principle 1 + §9).
- [ ] **Define how validated config crosses module boundaries** — injected into the native/FFI layer (model params), the `server/` runtime, and the `tools/` sandboxes as validated values, so no consumer (native, server, or bot) reads raw env or holds its own copy.
- [ ] Add config **schema versioning** + secret-by-reference handling (`.env.example`, names only); **guarantee secrets are never logged** and emit the effective *non-secret* config at startup for reproducibility; unit-test the loader/validator.
- [ ] Establish the **feature-flag & kill-switch discipline** behind the same DI interface — flags resolve through the config authority (never ad-hoc booleans), support progressive rollout, and give server-authoritative systems (receipt validation, matchmaking, the economy) and the `ruleset_version` sunset a documented off-switch — so a bad release degrades safely instead of requiring an emergency app-store push.
- [ ] Define **config precedence + typed numeric bounds** explicitly (base → environment overlay → secret refs → runtime flags), so every value has a documented resolution order and out-of-range balance/model/network numbers fail validation at startup rather than surfacing as gameplay or cost bugs later.

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
- [ ] **Extend `make verify` / `make test`** beyond the xops framework suite to run the project test suites (Dart `core/`, native/FFI, server) so "verify" means the *product* is green, not just the agent framework.
- [ ] Wire pre-commit/local hooks mirroring CI (format, lint, secret-scan) so failures surface before push, never after.
- [ ] Establish the **test harness + conventions for every stack** — unit runner + fixtures + headless mode (Dart), a **native/FFI test path**, and an **integration harness** — that Phase 1.3 (assembler), the FFI boundary (1.1/1.4), and Phase 2/3 load-bearing tests build against.
- [ ] Establish **test-data / fixture management + deterministic CI seeds** — a shared home for golden fixtures and sample manifests/receipts, a fixed RNG seed convention in CI (ties to the 0.8 determinism contract), and a rule that fixtures move with the code they pin — so tests are reproducible run-to-run and machine-to-machine.
- [ ] Add a **build/dependency caching strategy** (pub, native compile artifacts, cached model fetch) plus a CI-time/build-time budget and a **fail-on-flaky** policy so the gate stays fast and trustworthy.
- [ ] Wire the **content-integrity gate (0.12) into CI** — the no-real-clinical-label lint and the untrusted-input schema checks run on every push, so a banned DSM/ICD term or a free-text field that could reach the prompt fails the build, not review.
- [ ] Add **contract tests across the client/server trust boundary** — the shared receipt/manifest schema (0.8) round-trips byte-identically on both sides — so the Phase 3 boundary cannot silently fork; a schema change breaks the contract test, not production.
- [ ] Adopt **property-based / fuzz testing for the deterministic core and the canonical serializer** (seeded generators exploring the state×action space) so determinism and round-trip integrity are proven across the input space, not just hand-picked examples (Principle 4 — load-bearing logic).
- [ ] Add coverage reporting for load-bearing modules (`core/`, economy, prompt assembler, receipt validation) — reported to inform, not a blanket gate (Principle 4 + [DECISION 0011](../project/DECISION_LOG.md)).

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

- [ ] Add `SECURITY.md` + a lightweight threat-model stub anchored on the server-authoritative trust boundary and the "no transcripts durable" invariant.
- [ ] Implement secret handling end-to-end: `.env.example`, CI + pre-commit secret-scanning, and the enforced "names not values" rule.
- [ ] Add dependency **lockfiles + a pinned-version policy** and **generate an SBOM**; fail CI on unreviewed drift.
- [ ] Add dependency **vulnerability + license-compliance** scanning (ties to C-2 model redistribution terms + third-party deps).
- [ ] **Establish the signing-key custody plan** for every signature the design relies on — mobile/desktop app signing ([ADR-0002](../design/ADR-0002-desktop-distribution-and-auth.md)) and server-signed presence/receipts/manifests (Phases 3/4) — locations, rotation, and access only; no keys in-repo.
- [ ] **Establish the client-side data-at-rest posture**: the durable offline receipt queue (Phase 3.4), the cached primitive profile (3.2), auth tokens, and any device-held signing keys live in platform secure storage (Keychain / Keystore / OS credential store), never plaintext on disk — the client half of the key-custody plan above.
- [ ] **Design the server-side abuse-prevention baseline** (policy + shapes only): the authenticated-request rule, per-account/per-endpoint rate-limit + throttle conventions, and request-quota shapes every anti-farming and anomaly-detection system (§3, §17, §21) will plug into — so the enforcement built in Phase 3.1 rides a documented convention rather than being re-invented per feature.
- [ ] **Define the append-only audit-trail schema + convention** for authoritative actions (moderation, ownership transfers, receipt acceptance/rejection, royalty payouts) — tamper-evident, correlation-id–stamped (0.7), transcript-free — so the trail *implemented* in Phase 3.3 makes integrity incidents forensically reconstructable and gives the Phase 7.3 moderation backdoor an accountable record.
- [ ] **Define the backup / disaster-recovery posture** for the authoritative profile + ledger store — backup cadence and point-in-time-recovery target — plus the server data-migration + transactional-integrity conventions the Phase 3 ownership arbitration (the double-spend analog) depends on; the documented restore drill that *proves* "ironclad progress preservation" (§3) runs in Phase 3.2 once the store exists.
- [ ] **Turn "no transcripts durable" into an enforced gate** (a test/lint that fails if a raw dialogue transcript can reach a durable store or server log) and write a short **data-classification & privacy baseline** the later PII work extends.
- [ ] **Define the data-lifecycle & erasure model** — pseudonymous IDs only in the ledger (§17), and a right-to-erasure / revocation data path that feeds the §17 revocation list, honours §8 PII separation, and covers the C-6 mature-rating age-gate/consent data — so deletion and moderation obligations are designed in, not bolted on.
- [ ] Document the responsible-disclosure path + the moderation-backdoor access-control principles that Phase 7.3 implements.

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

- [ ] Author a single **cross-stack logging convention** (`docs/code/LOGGING.md`): one canonical structured log-line schema — timestamp, level, scope/module, event name, structured key–values, and a correlation/session id — reused verbatim by the C++ FFI layer, the Flutter/Dart client, and the server (one convention, not three).
- [ ] Define the **formatting + balanced-emoji style**: exactly one leading emoji per line mapped to level/severity (e.g. debug 🔍, info ℹ️, success ✅, warn ⚠️, error ❌, fatal 🛑), aligned/padded columns for scannability, and a hard rule of *no decorative emoji spam and no emoji inside machine-parsed fields* — so logs stay both human-readable and `grep`-able.
- [ ] Provide a **shared logger per stack with identical output**: a Dart logger in `app/lib/shared/`, a thin C++ logging shim across the llama.cpp FFI boundary, and the server logger — all emitting the same rendered line and the same structured payload (human-readable in dev, JSON in staging/prod, selected via the config authority in 0.2), never raw transcripts server-side (§17); add a lint/CI check that fails direct `print` / `std::cout` / `stdout` writes bypassing the logger.
- [ ] Establish the **versioning registry/conventions** for `ruleset_version` (Phase 3.3) and the manifest schema version (Phase 4.1) as a single source of truth from day one.
- [ ] Define the **error-classification** convention (user / system / external; offline as a first-class state, not an error) that all features adopt, carried on the shared log schema.
- [ ] Define **correlation/session-id propagation across the trust boundary** so one session's client, native/FFI, and server log lines — and its eventual receipt — share a single id end-to-end, making the receipt flow debuggable without ever persisting a transcript.
- [ ] Establish the **identifier & idempotency-key strategy** as a single convention: how entity ids, the client-generated receipt idempotency keys (§3, Phase 3.4), and the pseudonymous therapist ids (§17) are generated (collision-resistant, non-PII, non-enumerable), so dedupe, provenance, and privacy all rely on one documented id scheme rather than ad-hoc formats per feature.
- [ ] Define the **metrics contract** (counters / timers / gauges) as a concern distinct from logs — the minimal signal set the C-3 cost model and the Phase 6.6 balance oracle consume — schema only, no collection yet.
- [ ] Define the **per-stack performance-budget targets** + the file they live in — app cold-start, inference tokens/sec + latency target, peak-RAM ceiling anchored to the [DEVICE-SPEC](../specs/DEVICE-SPEC.md) floor, UI frame budget, and binary size incl. the ~1.8 GB model delivery — so every later feature has a numeric budget to regress against, not a vibe; the actual baselines are *measured* against these targets at the Phase 1.6 device-viability gate.
- [ ] Define the **privacy-scrubbed telemetry + crash/error-reporting contract** the Phase 6.6 balance oracle consumes — schema, scrubbing rules, opt-in posture ([DECISION 0006](../project/DECISION_LOG.md)), and server-log **retention/redaction** so raw transcripts are never persisted (§17); no collection yet.

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

- [ ] Establish the **determinism contract for `core/`**: one seeded PRNG and an injected clock (no wall-clock, no ambient randomness in pure rules) so a fixed state + action + seed always yields the identical outcome — the precondition for Phase 2 determinism, Phase 4 solvability bots, and receipt replay.
- [ ] **Ban platform-dependent floating point from `core/` and the economy**: define a deterministic **fixed-point / integer money + ratio representation** for every currency, multiplier, and percentage (§9, §14, §17, §19, §24), so the same receipt replays byte-identically across x86/ARM and client/server, and rounding can never mint or destroy currency — a cross-platform determinism *and* economy-integrity foundation.
- [ ] **Define the authoritative-time seam**: the injected clock reconciles to *server* time for every time-dependent rule — ownership lease TTL (§3, Phase 3.4), cooldowns and recovery windows (§23), daily-reset cycles, tax weeks and audits (§22), and macro-event timing (§22) — while the device clock is treated as untrusted and only a monotonic source is used for local durations, so a player cannot gain advantage by changing their clock and offline replay stays consistent.
- [ ] Define **canonical, stable serialization** for the `packages/` schemas (manifest, receipt, structured deltas) — deterministic field ordering + encoding — so checksums/signatures (0.6, Phases 4/5) and cross-version diffs are reproducible.
- [ ] Settle the **shared-schema strategy** implied by the 0.1 server-runtime decision: one schema package vs two aligned ones, and the **language-neutral contract** (e.g. JSON Schema) if the server is not Dart, so the receipt/manifest contract cannot drift across the trust boundary.
- [ ] Bind the schemas to the **`ruleset_version` registry** (0.7) and add **golden/snapshot fixtures** so a ruleset or schema change that alters a serialized outcome is caught by a failing test, not discovered in production.
- [ ] Define the **wire-schema compatibility contract** — additive-only evolution and explicit unknown-field handling — so a newer client against an older server (and vice versa) degrades safely across the trust boundary; the 0.7 registry records *which* versions exist, this rule governs how they interoperate.

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

- [ ] Implement **GetX** as the state-management + dependency-injection layer ([DECISION 0016](../project/DECISION_LOG.md)), and make the [config authority](#02--centralized-configuration-authority) + shared services injectable through it (no globals, no ad-hoc singletons); document the choice in an ADR.
- [ ] Establish the **navigation/routing convention** (typed routes + deep-link readiness for the C-5 desktop OAuth callback) so `session/` / `clinic/` / `progression/` flows compose predictably.
- [ ] Define the **local-persistence & offline-first storage abstraction** — one seam for durable local state (the Phase 3.4 receipt queue, cached primitive profile, settings) with an explicit **local cache schema-migration** policy so state survives app upgrades and never scatters into per-feature stores.
- [ ] Declare the **on-device concurrency model**: inference (llama.cpp/FFI), serialization, and fetch run off the UI isolate so the frame loop never stalls — a performance rule Phase 1.1 builds against.
- [ ] Define the **app-lifecycle & crash-recovery convention**: state is durably checkpointed so a backgrounded, OS-killed, or crashed app relaunches into a consistent state with no lost or double-applied session progress — the client-side reliability complement to the 0.10 offline queue and the 0.6 backup posture.
- [ ] Declare the **memory-pressure & asset-lifecycle rule** (convention + budget): the ~1.8 GB model stays resident while only compact manifests swap (§5 zero-overhead swap) and heavy presentation assets (the Phase 7.1 ink-wash layers) load/evict against a budget — so features are written to it from the start; that the app actually degrades gracefully under OS memory pressure on minimum-spec devices ([DEVICE-SPEC](../specs/DEVICE-SPEC.md)) is *verified* at the Phase 1.6 device-viability gate.
- [ ] Codify the **feature-module skeleton** (the internal shape of `app/lib/features/<domain>/`: state, services, UI, tests) so every later feature lands in an identical, reviewable structure.

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

- [ ] Establish the **typed API-client seam** bound to the shared `packages/` schema (0.8) — no ad-hoc HTTP in features — with auth-token injection + refresh routed through secure storage (0.6/0.9), and every mutating request carrying its idempotency key (0.7) so the server-side dedupe (Phase 3.4) has a client contract to rely on.
- [ ] Define the **resilience policy for every remote call**: timeouts, bounded exponential backoff + jitter, idempotent-retry rules, honouring server rate-limit / `429` / `Retry-After` signals (the client half of the 0.6 abuse-prevention baseline), and a circuit-breaker / degrade-to-offline path that feeds the Phase 3.4 offline receipt protocol.
- [ ] Make **offline a first-class transport state** (detection + queue-and-replay), consistent with the 0.7 error-classification convention, so the client degrades to local-first play without data loss and reconciles on reconnect.
- [ ] Establish the **verified, bandwidth-aware large-asset fetch convention** (resumable/chunked fetch + signature/checksum verify before load, plus a metered-/cellular-connection posture) shared by the Phase 1 model download and the Phase 4.4 signed-manifest delivery — directly serving the §1 download-acceptance gate so the ~1.8 GB first-run fetch is deferrable and never silently burns a data cap.

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

- [ ] Externalize **all user-facing strings** behind a localization layer wired through the config-selected locale (0.2) — no hard-coded UI/dialogue-chrome copy — and add a gate that fails on a planted hard-coded string.
- [ ] Establish **locale-aware formatting** (numbers, the §9 economy currencies, dates, pluralization) and **RTL-readiness** as a shared convention in `app/lib/shared/`.
- [ ] Set the **accessibility baseline** — semantic labels, scalable text, sufficient contrast, and input alternatives — validated on the initial build matrix so Phase 7.1's presentation layer is built a11y-aware, not corrected after.
- [ ] Define the **input & motion accessibility contract** for the card-driven interface (§11) and the ink-wash motion (§20): keyboard/switch/pointer alternatives to the focus wheel and sliders, honour OS reduce-motion / high-contrast settings (the chromatic-fracture and shader motion must be dampenable), and keep hit-targets and dynamic-type reflow within platform guidelines — so the game's most distinctive UI stays reachable.
- [ ] Keep localization/a11y **out of the deterministic core**: `core/` emits stable tokens/keys, the presentation layer resolves them to localized, accessible strings — preserving §4 core purity and the 0.8 determinism contract.

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
- [ ] Establish the **fictional-taxonomy naming convention + registry** (§8 "evocative, not alien"): documented rules and a checkable registry for disorder, medication, and study-field names — familiar roots + plausible clinical/pharma suffixes, never a near-homophone of a real trademark or a reskinned real label — so names stay legible yet legally fictional.
- [ ] Define the **untrusted-input / prompt-injection defense contract** (§11): treat peer-authored case history (§17) and community-authored manifests (§21) as untrusted — strict schema whitelisting (enums + numbers over free text wherever possible), server-side sanitization + length caps applied at signing time (§2.2), and template-level isolation so an untrusted string can never be interpreted as instructions by the local model.
- [ ] Add the **disclaimer & fictional-framing string hooks** (§8): reserved, externalized (0.11) presentation slots for the "fictional simulation, not real care" disclaimer and entertainment-focused framing, wired from day one so Phase 7.5 finalises copy rather than retrofitting placement.

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
and no orphaned native call), and persists **no raw transcript**.

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

- [ ] Integrate llama.cpp via Flutter FFI behind a **narrow, typed `shared/` inference service** (load / tokenize / detokenize / **apply chat template** / generate / cancel / unload / **model-metadata query**) so no other module touches raw FFI; the binding lives in the 0.1-declared native module, not ad-hoc under `app/`. Embeddings/fine-tuning surfaces are explicitly out of scope (§18).
- [ ] **Pin the llama.cpp commit + the exact GGUF quantization (e.g. `Q4_K_M`) and its rationale** as recorded build inputs (0.1) so inference behaviour is reproducible across machines and CI; the native shared library **builds, links, and bundles** for Linux desktop and the x86 Android emulator — **and declares the `arm64-v8a` device target** (built, not perf-validated on the emulator) so the physical-device gate (1.6) is a rebuild, not a fresh integration.
- [ ] **Make the native library actually *load* on each target, not just link**: per-ABI JNI packaging on Android (`arm64-v8a` for devices, `x86_64` for the emulator) with 16 KB-page-size-aligned `.so`s, and the desktop `.so`/`.dll` shipped alongside the executable on a config-resolved load path — closing the silent gap between "compiles in CI" and "runs on device".
- [ ] Implement the **first-run verified model fetch** on the 0.10 resumable-fetch convention — a **free-disk-space preflight**, chunked/resumable HTTP-range download, **checksum/signature verified before load with an atomic temp→final rename** (0.1 fetch policy + 0.6 verify-before-load) so a corrupt partial can never be loaded, and a re-fetch-on-corruption path — closing the supply-chain gap for the largest untracked asset. *(⏭ hardened later: signing-key custody + the model file at rest in platform secure storage move to 0.6/Phase 3; here we verify against the pinned checksum and store under a config-resolved path.)*
- [ ] Implement **runtime Tier A/B selection**: a first-run device-capability check (RAM/SoC/ABI vs the [DEVICE-SPEC](../specs/DEVICE-SPEC.md) floor) chooses the Tier A primary or the Tier B fallback, resolved through the **config authority** (0.2) — so 4 GB-class devices never attempt a model they cannot hold.
- [ ] Load weights via **memory mapping (mmap)** and manage an **explicit KV-cache lifecycle** — allocate per session, **reset (not reallocate) between cases**, and reuse the stable Tier-1 prompt prefix across turns (1.3) instead of re-encoding it — cutting cold-start, peak RAM, and per-turn latency (the 1.6 budget); a case switch frees what it allocated and leaks nothing.
- [ ] Run **all inference off the UI isolate** (0.9) with a **streaming token callback**, a **single-flight generation guard** (a second request is queued or rejected, never raced against the native context), and a **cancellation path** (session abandoned / app backgrounded mid-generation) that **frees/resets the native context** so a cancelled turn leaves no orphaned call and no partial KV state; a foreground resume re-arms cleanly.
- [ ] Provide a **deterministic decode mode** (fixed seed + temperature-0 / greedy, **pinned thread count + batch size**) selectable via config, distinct from the shipped sampling profile — reproducible **on the same build + architecture** (cross-architecture byte-identity is deliberately *not* claimed for float matmul; see the Determinism-scope note) so the 1.6 samples are a fixed target rather than a moving one.
- [ ] **Expose a grammar / constrained-decoding seam (llama.cpp GBNF)** from day one — unused by the baseline sampling profile, but wired so the 1.6 acting-quality escalation ladder ([DECISION 0018](../project/DECISION_LOG.md)) is a config flip, not an FFI rewrite.
- [ ] Expose the full **generation-parameter set** through the **central config authority** (0.2) — tier, context window, thread count / CPU-affinity, batch size, seed, sampling temperature, top-p / top-k, repetition penalty, max output tokens, and stop / EOS tokens; no hard-coded model constants, and run a **warm-up (first-token) pass at load** so the first real turn is not a latency outlier in measurement.
- [ ] Add the **C++ logging shim across the FFI boundary** (0.7) so native load/inference events emit the same structured, correlation-id–stamped line as Dart — no raw `std::cout` / `stdout` bypass.
- [ ] Keep the model **resident** per the 0.9 memory-pressure rule (loaded once, reused across turns, explicit unload on shutdown / memory-pressure signal); classify inference failures on the 0.7 error taxonomy (**missing / corrupt / unsupported-ABI model, load failure, OOM, cancellation, generation error**) and **degrade an OOM to an actionable error or a Tier B retry**, never a hard crash.
- [ ] **Add a native memory-safety gate**: repeated `load → generate → cancel → unload` cycles leak no memory and trigger no use-after-free under a sanitizer (ASan/LSan) on the Linux CI build — the hand-managed FFI boundary is load-bearing and the cheapest place to catch a leak is here.
- [ ] Confirm build + verified model load + warm-up + one streaming inference on **Linux desktop and the x86 Android emulator** from the 0.1 one-command bootstrap.

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

- [ ] Define the minimal manifest schema in `packages/` (identity, style archetype, initial pressure/sim state, available interaction patterns) shared by app + tools, using the **canonical serialization + additive-only evolution** contract (0.8) with **`schema_version` + `content_checksum` fields from day one** and **field-level length/size caps**, so the untrusted-input *shape* (0.12) exists before Phase 4/6 accept external manifests.
- [ ] **Publish the schema as a language-neutral contract** (e.g. JSON Schema, per the 0.8 shared-schema strategy) as the single source of truth, with the Dart typed models generated/derived from it — so `tools/` and a future non-Dart server (0.1) validate the *same* shape and the manifest contract cannot fork across the trust boundary.
- [ ] **Set a total manifest byte budget + per-field caps** sized so a fully-populated worst-case manifest still fits the Tier-1 token budget ([C-7](../specs/PROMPT-TOKEN-BUDGET.md)) — so the 1.6 gate never discovers an inherently over-budget content shape after the fact.
- [ ] Define the **initial-state contract**: the manifest's pressure/sim-state fields are exactly the typed inputs the deterministic core (1.4) consumes, and the interaction-pattern enum foreshadows the Phase 2.1 card taxonomy — so Phase 2/4 extend the contract rather than reshaping it.
- [ ] Implement the loader + typed models in `shared/`; **malformed, unknown-`schema_version`, or checksum-mismatched manifests fail fast** with an actionable error on the 0.7 error taxonomy, never loading partially.
- [ ] **Decode untrusted input defensively**: enforce total-size, nesting-depth, and per-field caps *before* typing, and reject anything over budget — so the resource-exhaustion guard the Phase 4/6 external-manifest path needs exists from the first loader, even though the PoC content is bundled and trusted.
- [ ] Apply the **0.8 wire-compatibility rule to unknown fields**: a known-`schema_version` manifest carrying an unrecognised additive field loads (ignoring the unknown field) rather than failing, so a newer bundled case degrades safely on an older build — the compatibility contract Phase 4.1 relies on.
- [ ] **Verify the `content_checksum` on load** (integrity) and reject on mismatch — the local, unsigned precursor to the Phase 4.4 signed-manifest verify path, so the trust seam exists before the network does. *(Cryptographic signing + key custody are deferred to Phase 3/4; here we verify against the embedded checksum only.)*
- [ ] Resolve the **bundled-sample location + any tunable caps through the config authority** (0.2) — the PoC case ships as a small committed asset (0.1 large-binary policy: JSON is fine to commit; only the model is fetched), its path and limits never hard-coded.
- [ ] Seed the **`memory_class` field** (stateless vs persistent) now — the PoC case is **stateless** (no history envelope) — so the discipline exists before Phase 4.1 / 5.2 depend on it.
- [ ] Keep the schema **whitelisted (enums + bounded numbers over free text)** and insert any model-facing prose through a **template-isolation seam** (0.12): the PoC manifest is trusted/bundled, but the injection-defense *shape* is established now, not retrofitted at Phase 6.
- [ ] Split **core-facing tokens from player-facing copy**: `core/` consumes stable tokens/keys only (0.11 core-purity + 0.8 determinism); player-facing manifest text (case title, display name) carries localization keys the presentation layer resolves, never raw localized prose.
- [ ] **Validate that every player-facing localization key resolves** against the 0.11 string catalog at load (a missing key fails the loader test), so the token/copy split is enforced mechanically, not merely declared.
- [ ] Author one hand-authored sample case drawn from the **fictional-taxonomy registry** (0.12) that **passes the content-integrity gate** (no real DSM/ICD label or drug brand) — the first real content the CI lint checks.
- [ ] **Unit-test the loader + schema** (tests move with code): canonical round-trip is byte-identical, a malformed / unknown-version / checksum-mismatch manifest is rejected, and a **golden fixture** (0.5 / 0.8) pins the sample so a schema change flips it red.

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

- [ ] Implement the tiered assembler as a **pure, deterministic** function in `core/` (0.8 — no wall-clock, no ambient randomness), matching the C-7 signature.
- [ ] Source the **model's real tokenizer** through the `shared/` inference service so token counting matches llama.cpp exactly — a budget enforced against an approximate counter is not enforced; **cache the tokenizer handle** and count off the UI isolate so per-turn budgeting is cheap (0.9).
- [ ] **Apply the model's chat template** (from the GGUF metadata or a config-pinned template) inside the assembler so the roleplay frame is emitted in the exact turn format the instruction-tuned model expects — a wrong or missing chat template silently wrecks the 1.6 acting-quality gate even when the token count is within budget.
- [ ] **Version the system / roleplay-frame template with the `ruleset_version`** (0.7): it is model-facing content, not user-facing copy, so it is pinned and reproducible rather than localized — a frame change is a tracked ruleset change, not an invisible tweak.
- [ ] Emit a **byte-stable Tier-1 prefix** (deterministic field ordering, T1 assembled before T2/T3) so the fixed prefix is identical turn-to-turn — enabling the 1.1 KV-cache/prefix reuse rather than re-encoding the frame every turn (performance contract, not just correctness).
- [ ] **Own the sliding conversation-window structure** and its length `N` (resolved through config): the assembler *consumes* it and the session loop (1.5) *maintains* it, and the assembler never mutates it — preserving the pure-function contract.
- [ ] Enforce `tokenBudget` with the C-7 tier-ordered truncation (T2 conversation window → T2 digest; **never** T1 or T3) and reserve generation headroom; the budget value resolves through the **config authority** (0.2), not a literal. If **T1 alone exceeds budget**, fail loudly (a manifest-schema defect, per C-7) rather than silently dropping clue tokens.
- [ ] Implement the **history-digest compiler** — a fixed-token structured summary (prior style, trust trajectory, medication history, key outcomes), never raw deltas — deterministic for a fixed input.
- [ ] Establish **template-level isolation** so manifest/history strings are inserted as data and can never be read as instructions (0.12) — the assembler is the injection-contract enforcement point.
- [ ] Unit-test with **golden fixtures** (0.5 / 0.8): budget compliance for the worst-case full manifest, T1 integrity, clue-token survival, and truncation order — all independent of the model.
- [ ] Add a **property-based / fuzz test** (0.5) over randomized manifests + conversation-window lengths proving `output ≤ input_budget` and T1 integrity hold across the input space, not just the hand-picked golden examples.

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

- [ ] Implement the deterministic turn resolver in `core/` (no I/O, no model calls) on the **0.8 seeded-RNG + injected-clock seam** — fixed state + action + seed → identical outcome.
- [ ] **Define the minimal PoC action set** the resolver handles — a small fixed set drawn from the manifest's interaction-pattern enum (1.2) — so there is a concrete turn to resolve and score, foreshadowing the Phase 2.1 card taxonomy without building it.
- [ ] Define the **structured-delta schema in `packages/`** (0.8 canonical serialization) as the local, pre-server precursor of the Phase 3.3 receipt shape, so Phase 3 extends it additively; deltas carry the **0.8 fixed-point money/ratio type** even in the PoC so no platform float leaks into `core/`.
- [ ] **Tag each resolved turn's delta with the `ruleset_version`** (0.7) so an outcome is replayable against the exact rules that produced it — the local, pre-server precursor of the Phase 3.3 receipt's `ruleset_version` pin, and distinct from the manifest's `schema_version` (1.2).
- [ ] Emit outcomes as **structured deltas** (never transcripts) and enforce the 0.6 **"no raw transcript reaches a durable store"** rule even in the local-only PoC. *(⏭ hardened later: the transcript-blocking test/lint becomes a CI gate in 0.6/Phase 2.)*
- [ ] Apply each turn **transactionally**: a cancelled or failed generation (1.1) rolls the turn back so core state is never half-applied — the reliability guarantee the streaming/cancellation path depends on.
- [ ] Route mandatory clue tokens into the prompt and **validate their survival post-generation with a bounded regeneration loop then a templated fallback** (§4): retry at most `K` (config) times, then emit the deterministic templated line — so a forgetful model degrades to fixed text instead of looping or silently losing a clue.
- [ ] Keep **all** model interaction behind the `shared/` inference service; `core/` never imports the FFI layer (Principle 2 + the 0.2/0.9 boundary).
- [ ] Unit-test the split, including a **property-based determinism test** (0.5) across seeds/states: a fixed state + action yields a byte-identical outcome and prompt context, and no model output alters anything mechanical.

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

- [ ] Build the minimal session UI (case view, **structured card/choice action selector — never a free-text prompt box (§4, 0.12)**, **streaming** dialogue render) with **no hard-coded strings** (0.11 externalization) and the **a11y baseline** (semantic labels, scalable text, contrast) — keeping the direct prompt-injection channel closed from the first slice.
- [ ] Establish the **typed navigation/routing** convention (0.9) for the launch → case-select → session flow, with the deep-link seam stubbed for the C-5 desktop OAuth callback (no server in Phase 1).
- [ ] Wire UI → sim core → prompt assembler → inference → render through **GetX dependency injection** (0.9 / [DECISION 0016](../project/DECISION_LOG.md)) — the config authority and inference service are injected, never global singletons.
- [ ] Keep inference **off the UI isolate** and **stream tokens** into the view so perceived latency stays low and the frame loop never stalls (0.9).
- [ ] **Own the sliding conversation-window + delta-log accumulation** across turns, and **reset the KV cache + sim state on new-case / session reset** (1.1) so a fresh case never inherits stale context — the client-side half of the 1.1 KV lifecycle.
- [ ] **Surface the 0.7 error taxonomy in the UI**: model load / OOM / cancellation / generation errors render as actionable, localized states, and offline is shown as a first-class state — never a silent hang.
- [ ] Give the first-run model fetch a **progress + deferrable UI** (pause/resume, metered-connection posture per 0.10) so the download-acceptance gate (1.6) measures a real user path, not a blocking spinner.
- [ ] Honour **reduce-motion and input alternatives** (0.11) for the streaming render and action input, so the distinctive UI stays reachable from the first slice.
- [ ] Propagate a **single correlation/session id** across the Dart client and the C++ FFI layer for the whole turn (0.7) so the loop is debuggable without persisting any transcript.
- [ ] Implement **app-lifecycle / crash-recovery** (0.9): the full session — **sim state + conversation window + delta log + correlation id** — is durably checkpointed at each turn boundary so a backgrounded, OS-killed, or crashed session relaunches into a consistent state with **no lost or double-applied turn**, exercising the durable local-state seam (no server yet).
- [ ] Confirm the loop is **fully local/offline** (no server dependency in Phase 1) and that the same build path runs on Linux desktop and the x86 Android emulator.

### 1.6 — PoC exit-gate measurement

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

- [ ] Wire **local measurement instrumentation** on the 0.7 metrics contract (timers/gauges: tokens/sec, inference latency, peak RAM, cold-start, frame budget) into the FFI layer and the loop — you cannot measure a gate you did not instrument.
- [ ] Build a **headless reproducibility harness** that runs the core → assembler → inference path with no UI under the fixed seed + greedy decode, so the token-budget and determinism artifacts are reproducible in CI and the harness is reusable by the Phase 2.8 solvability bots and Phase 4.3 validation (0.1 single-core-implementation rule).
- [ ] **Take N samples per metric and report the distribution (median + p95), never a single shot** — a one-shot number hides warm-up outliers and thermal variance and is not a defensible gate.
- [ ] Measure **acting quality for both the Tier A primary and the Phi-3.5-mini comparator** ([DECISION 0015](../project/DECISION_LOG.md)) under a worst-case full-manifest prompt against a **written rubric** (in-character, honours clue tokens, respects style archetype, no rule-breaking), recorded with the fixed seed (0.8) so the sample is reproducible and the final pick is evidence-based.
- [ ] If acting quality **fails the rubric**, escalate along the fixed ladder — **prompt/few-shot exemplars → grammar-constrained decoding (llama.cpp GBNF) → one-time offline LoRA fine-tune (merged to fixed shipped weights) → model-tier bump** — *before* Phase 2 spend, per [DECISION 0018](../project/DECISION_LOG.md); runtime/continuous training stays out of scope (§18, [ARCHITECTURE](../code/ARCHITECTURE.md) §7). The sim core owning all mechanics (1.4) is the safety net that lets prompting-first be the baseline.
- [ ] Record the **prompt token budget** (C-7): chosen model's advertised max, measured usable factor, and worst-case token count vs `input_budget` with reserve — feeding back to the manifest schema (Phase 4.1) if T1 overflows.
- [ ] **Measure the prompt-prefix KV-cache reuse benefit** — per-turn latency and tokens processed *with* vs *without* T1-prefix reuse (1.1/1.3) — so the performance contract is validated rather than assumed and a regression here is visible.
- [ ] Implement + measure the **download-acceptance** path: the 0.10 resumable, deferrable, metered-connection-aware first-run fetch of the bundled GGUF, with its retry strategy and a recorded acceptance method.
- [ ] Record the **device-viability** method + the Tier B (SmolLM2 1.7B) fallback plan against the [DEVICE-SPEC](../specs/DEVICE-SPEC.md) floor — peak RAM within budget and tokens/sec above the playability threshold — **physical-device measurement gated on human sign-off** (kept explicitly *pending* until then).
- [ ] Measure **sustained throughput under thermal load**: a multi-turn run on mobile (not a single cold shot), recording whether tokens/sec collapses under throttling — the real playability risk on minimum-spec devices.
- [ ] Record **warm vs cold first-token latency** separately (the 1.1 warm-up pass) and a **rough per-turn energy/battery draw** on mobile against a budget, so playability accounts for the second turn and the battery cost, not just the first token.
- [ ] **Record the greedy-decode reproducibility scope explicitly**: byte-identical on the same build + architecture + pinned thread count, with the expected x86-emulator-vs-arm64-device divergence (float matmul) documented — so the determinism artifact is not misread as a bug and Phase 2/3 replay expectations are correctly scoped.
- [ ] Record the **0.7 performance-budget baselines** vs their targets (cold-start, tokens/sec + latency, peak RAM vs the DEVICE-SPEC ceiling, frame budget, binary size incl. model delivery) and confirm the app **survives OS memory pressure** on a minimum-spec device (the 0.9 rule). *(⏭ hardened later: any telemetry/crash collection stays local-only here; the opt-in, privacy-scrubbed pipeline is built in 0.7/Phase 6.6.)*
- [ ] Record all artifacts in `docs/reports/` under a **PoC exit-report template** and state the **decision gate explicitly**: any red gate revisits the architecture (or drops to Tier B) before Phase 2 spend — "it produced text" is not a pass (§1).

---

## Phase 2 — Deterministic Game Core (offline)

**Goal.** Build the real, offline, single-player game — the "Lane A" mechanics
the audit found ready today: card taxonomy, loadout, session resolution,
multi-session siege, progression, recovery, and the balance sandbox.

**Scope id.** `phase-2`

**Why now.** These systems are client-only and depend on nothing server-side.
Proving the game is *fun* offline validates the product before networking cost.

**Validation.** A full offline career loop is playable; the balance sandbox can
run bot sessions headlessly; core logic is unit-tested.

### 2.1 — Card taxonomy & signature principle

**What.** Implement the four card types (Disclosing, Relatable, Postponing,
Manipulative) with context-dependent, signature-biased effects (§16).

**Why.** The card system is the tactical heart of the game.

**How.** Everything in the session loop is expressed as card plays against state.

**Validation.** Each type produces its signature effect in-context and a weaker
effect out-of-context; Manipulative resolves three-way by trust state.

- [ ] Implement the four card types and their context-bias resolution in `core/`.
- [ ] Implement Manipulative three-outcome resolution (success / partial / derangement) keyed to trust.
- [ ] Implement Postponing multi-session decay and Transference Spike reclassification.

### 2.2 — Therapy deck & loadout system

**What.** Implement the pre-session loadout with a hard active-slot cap and the
preparation phase (§11).

**Why.** The slot constraint is what turns card collection into tactical choice.

**How.** Gates which cards enter a session, shaping every encounter.

**Validation.** Players curate a capped loadout; wrong loadouts leave measurable gaps.

- [ ] Implement the card library + capped active loadout (slot count from balance spec).
- [ ] Implement the clinical preparation phase (intake review → deck curation).
- [ ] Add focus/emotional-delivery controllers (§11 sliders) feeding sim state.

### 2.3 — Session resolution & outcome engine

**What.** Implement the deterministic state model (trustScore, agitationLevel,
activeDefense, medication effects, session progress) and outcome resolution (§4).

**Why.** This is the authoritative outcome owner; the model never touches it.

**How.** Produces the receipts and deltas every later server system validates.

**Validation.** Fixed inputs yield deterministic outcomes; unit tests cover
success/fail/stabilize/crisis paths.

- [ ] Implement the core state variables and transition rules in `core/`.
- [ ] Implement outcome resolution (succeed / fail / stabilize / crisis) with structured deltas.
- [ ] Implement fictional pharmacology effects on case pressure and dialogue behavior.
- [ ] Unit-test the resolver across representative scenarios.

### 2.4 — Multi-session siege & clue ownership

**What.** Implement the cross-session research loop (§15): exit to analyze
clues, study to acquire target cards, return for the breakthrough.

**Why.** This is the depth mechanic that carries mid-to-late game.

**How.** Ties progression (study) to session tactics, closing the core loop.

**Validation.** A layered case requires ≥2 sessions + a study step to resolve.

- [ ] Implement clue collection + the fictional clinical encyclopedia lookup.
- [ ] Implement multi-session case state carry-over via structured deltas (never transcripts).
- [ ] Implement the study → target-card acquisition path.

### 2.5 — Progression: XP, study points, reputation

**What.** Implement difficulty-scaled XP, study/subspecialty points, and
event-sourced reputation (§9, §10).

**Why.** Progression is the spine that sequences role unlocks and case access.

**How.** Feeds attraction/matchmaking inputs and the recovery systems.

**Validation.** Harder cases yield proportionally more XP; reputation responds
to outcomes with decay and floors.

- [ ] Implement the difficulty→XP curve (harder cases worth more; trivial grinding diminishes).
- [ ] Implement study/subspecialty point earning + the field training tree.
- [ ] Implement event-sourced, recency-weighted reputation (not a lifetime ratio).

### 2.6 — Financial stabilizers & recovery

**What.** Implement the anti-bankruptcy paths (§14) and the visible
operational-pressure/recovery model (§23).

**Why.** Failure states need designed exits, or the game becomes a death spiral.

**How.** Keeps struggling players in the loop without pay-to-win.

**Validation.** Both recovery strategies (discount practice; academic sabbatical)
restore a playable state; pressure is visible, not a hidden stat.

- [ ] Implement the Discount Practice recovery (pricing slider → casual case flood, XP penalty).
- [ ] Implement the Academic Sabbatical recovery (closure → study → reputation floor restore).
- [ ] Implement visible operational pressure + recovery windows (no hidden well-being stat).

### 2.7 — Clinic operations & environment

**What.** Implement the clinic business layer (§22): rent/buy offices, overhead,
taxes/audits, and the pricing slider's effect on routing.

**Why.** The clinic economy is the strategy layer around the session loop.

**How.** Establishes the owned-clinic asset that later gates hiring (Phase 6).

**Validation.** A player can rent, earn, buy, and sell a clinic; overhead and
audits apply.

- [ ] Implement office rent/buy/sell + overhead upkeep.
- [ ] Implement progressive taxes + randomized audits keyed to pricing.
- [ ] Implement the pricing slider's effect on the local (offline) case seed.

### 2.8 — Balance sandbox & bot simulation

**What.** Build the accelerated sandbox + bot-driven simulation harness (§3):
parameter mutation, profile/clinic injection, admin overrides, scenario runs,
structured result logs.

**Why.** This is core infrastructure — it shortens every future balance decision
and powers mechanical solvability checks (§2.2 of the blueprint).

**How.** Turns the C-4 balance spec from a document into a tuned, tested system.

**Validation.** Bots of configurable skill play scenarios headlessly and emit
comparable metrics; balance constants load from the central config.

- [ ] Implement the accelerated sandbox runtime + parameter mutation layer.
- [ ] Implement configurable-skill bots + profile/clinic state injection.
- [ ] Implement scenario runner + structured diagnostics; wire balance constants to central config.
- [ ] Tune the C-4 multi-currency balance spec against sandbox output (sources/sinks/inflation/dead-currency checks).

---

## Phase 3 — Server Control Plane & Authoritative State

**Goal.** Introduce the authoritative server: identity, profile storage, session
receipt validation, offline receipt handling, the managed PKI, and the patient
ownership lifecycle state machine.

**Scope id.** `phase-3`

**Why now.** The offline game is proven (Phase 2); the cost model (C-3) has
cleared its gate. The server is what makes progression, moderation, ownership,
and the economy trustworthy.

**Validation.** A client boots against the server, submits validated receipts,
survives offline/online transitions, and ownership transitions match the §18
state machine.

### 3.1 — Identity, auth & distribution channels

**What.** Implement Apple/Google auth and the C-5 desktop (Linux/Windows) sign-in
+ distribution channels (§3).

**Why.** Server-authoritative identity is the precondition for every trustworthy
cross-player system.

**How.** Anchors profiles, presence, ownership, and royalties to a real account.

**Validation.** All five platforms have a named sign-in path; a user authenticates end-to-end.

- [ ] Implement mobile auth (Apple/Google) via the BaaS ecosystem.
- [ ] Implement the desktop auth + distribution channels decided in C-5.
- [ ] Enforce row-level security on profile data.
- [ ] Implement the **server-side abuse-prevention enforcement** from the 0.6 baseline — authenticated requests only, per-account/per-endpoint rate limiting + throttling, and request quotas — the shared seam anti-farming/anomaly detection (§3, §17, §21) builds on.

### 3.2 — Profile store & session handshake

**What.** Implement the primitive-payload profile schema (<0.5 KB) and the boot
handshake that initializes the local game brain (§3).

**Why.** The profile is the authoritative player state the client only caches.

**How.** Establishes the source of truth for progression balances.

**Validation.** Boot pulls the profile; only server-accepted results mutate it.

- [ ] Implement the primitive profile schema (atomic metrics only; no transcripts/logs).
- [ ] Implement the session handshake that hydrates the local game brain.
- [ ] Confirm profile writes happen only via server-accepted results.
- [ ] Stand up **backup + point-in-time recovery** for the profile/ledger store per the 0.6 posture, and run a **documented restore drill** that proves "ironclad progress preservation" (§3) against the live store.

### 3.3 — Session receipt validation

**What.** Implement receipt submission + validation via per-tier plausibility
bounds and statistical anomaly detection, with `ruleset_version` pinning (§3).

**Why.** This enforces "a client number is a claim, not a fact" without the
server re-implementing the rules.

**How.** Guards the entire economy against client tampering.

**Validation.** Out-of-bounds and unknown-`ruleset_version` receipts are rejected;
high-value outputs are computed server-side.

- [ ] Implement the receipt schema (start state, ordered actions, claimed deltas, `ruleset_version`).
- [ ] Implement per-tier plausibility bounds + anomaly detection.
- [ ] Compute high-value outputs (trauma payouts, ownership transfers, cure retirement) server-side.
- [ ] Implement `ruleset_version` sunset schedule (reject unknown/sunset versions).
- [ ] Implement the **append-only audit trail** (0.6 schema) recording receipt acceptance/rejection and every high-value authoritative action — tamper-evident, correlation-id–stamped, transcript-free.

### 3.4 — Offline receipt protocol

**What.** Implement the §3 Phase-2 deliverable: local durable receipt queue,
idempotency keys, ownership lease TTL, and the offline cure/transfer race rules.

**Why.** Play is offline-tolerant; this closes the gap between offline play and
authoritative state safely.

**How.** Makes local-first play consistent with server authority.

**Validation.** A receipt re-submitted after a network failure is never applied
twice; expired leases behave per spec.

- [ ] Implement the durable offline receipt queue with in-order submission.
- [ ] Implement client-generated idempotency keys + server dedupe.
- [ ] Implement ownership lease TTL + the offline cure/transfer race resolution.

### 3.5 — Managed PKI (presence & signing)

**What.** Implement presence-record signing, key provisioning/certification,
public-half publication, revocation, and reinstall/device-switch key recovery (§3).

**Why.** Signed presence is what lets clients trust what they display without
trusting each other.

**How.** Underpins matchmaking, referrals, and the revocation list (§17).

**Validation.** Presence records validate against server keys; a reinstall
re-provisions without orphaning the account.

- [ ] Implement key provisioning + server-signed presence records.
- [ ] Implement the revocation list + public-key publication.
- [ ] Implement key recovery on reinstall/device-switch against server-authoritative identity.

### 3.6 — Patient ownership arbitration & lifecycle (C-8)

**What.** Encode the corrected §18 state machine exactly: `pool ⇄ owned`,
`owned → owned′` (referral), `owned ⇄ hospitalized`, `owned → cured → archived`,
`owned → archived`. All transitions server-arbitrated.

**Why.** GM-1: the very first server artifact must not contradict the transitions
the mechanics require.

**How.** Makes single-owner exclusivity a real server-side locking guarantee.

**Validation.** Every legal transition is exercised by a test; illegal transitions
are rejected; the client only proposes.

- [ ] Implement the authoritative owner record + server-side transfer arbitration.
- [ ] Implement the full lifecycle state machine with all legal transitions from §18.
- [ ] Add tests covering re-pool on walkout/transfer, referral hand-off, and temporary hospitalization.

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

**What.** Implement the painterly visual language (§20): layered portraits,
Flutter fragment shaders, and the psychological-fracture effect on failure states.

**Why.** The aesthetic is core to the product's identity and immersion.

**How.** Turns the functional UI into the intended emotional experience.

**Validation.** Calm/agitated states render distinctly; fracture effects fire on
Manipulative failure; runtime cost stays low + offline-capable.

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

## Appendix C — Blueprint cross-reference map

Which [`STARTER.md`](../../STARTER.md) sections each phase realizes.

| Phase | Blueprint sections |
|---|---|
| 0 — Foundations & Corrections | §1 (day-one inputs), §3 (cost model), §8 (age rating), §9 (balance spec) |
| 1 — Runtime PoC | §1, §4, §5, §6 |
| 2 — Deterministic Game Core | §4, §9, §10, §11, §14, §15, §16, §22, §23 |
| 3 — Server Control Plane | §1, §3, §12, §18 |
| 4 — Content Pipeline | §2.1–§2.4, §3, §12, §13, §17 |
| 5 — Social & Economy | §3, §9, §12, §17, §18, §19, §23 |
| 6 — Endgame & UGC | §2.4, §11, §21, §22, §24 |
| 7 — Presentation & Launch | §2.5, §8, §19, §20 |
