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
| 0 — Foundations & Conceptual Corrections | 54 | 11 | 🟡 in progress |
| 1 — Minimal Cross-Platform Runtime (PoC) | 20 | 0 | ⚪ planned |
| 2 — Deterministic Game Core (offline) | 26 | 0 | ⚪ planned |
| 3 — Server Control Plane & Authoritative State | 19 | 0 | ⚪ planned |
| 4 — Content Pipeline & Distribution | 15 | 0 | ⚪ planned |
| 5 — Networked Social & Economy Systems | 18 | 0 | ⚪ planned |
| 6 — Institutional Endgame & UGC | 19 | 0 | ⚪ planned |
| 7 — Presentation, Monetization & Launch | 18 | 0 | ⚪ planned |
| **Total** | **189** | **11** | |

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
is designed to avoid. Sub-phases 0.5–0.8 are **cross-cutting foundations
established alongside** 0.1–0.4 (not strictly after them): every later phase
inherits the CI gate, the security posture, the logging/versioning conventions,
and the determinism/serialization contract from day one rather than bolting them
on.

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
C-7…C-10.

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
- [ ] **Declare the native/FFI module home** — the llama.cpp C/C++ binding layer and its build inputs — so Phase 1.1's inference path and Phase 0.7's C++ logging shim land in a declared module, not ad-hoc under `app/`.
- [ ] Declare the **cross-platform build matrix** (the five target platforms) and which are validated when — Linux desktop + x86 Android emulator in Phase 1; the rest deferred.
- [ ] Add the language toolchains with **pinned versions** — Flutter/Dart, the chosen server runtime, **and the native C/C++ toolchain (clang/NDK) for llama.cpp** — plus a `make`-level build/lint/format gate wired into `make doctor`.
- [ ] Establish a **reproducible dev-environment bootstrap** (a pinned SDK/version manifest + a one-command setup such as a devcontainer or bootstrap script) so "compiles on Linux" holds identically on any dev machine and in CI, not just locally.
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

- [ ] Stand up **CI (GitHub Actions)** running build + lint + format + `make verify` on every push/PR across the initial build matrix (Linux + Android emulator), with **required status checks + branch protection** so a red build cannot merge.
- [ ] **Extend `make verify` / `make test`** beyond the xops framework suite to run the project test suites (Dart `core/`, native/FFI, server) so "verify" means the *product* is green, not just the agent framework.
- [ ] Wire pre-commit/local hooks mirroring CI (format, lint, secret-scan) so failures surface before push, never after.
- [ ] Establish the **test harness + conventions for every stack** — unit runner + fixtures + headless mode (Dart), a **native/FFI test path**, and an **integration harness** — that Phase 1.3 (assembler), the FFI boundary (1.1/1.4), and Phase 2/3 load-bearing tests build against.
- [ ] Add a **build/dependency caching strategy** (pub, native compile artifacts, cached model fetch) plus a CI-time/build-time budget and a **fail-on-flaky** policy so the gate stays fast and trustworthy.
- [ ] Add coverage reporting for load-bearing modules (`core/`, economy, prompt assembler, receipt validation) — reported to inform, not a blanket gate (Principle 4 + [DECISION 0011](../project/DECISION_LOG.md)).

### 0.6 — Security, secrets & supply-chain integrity

**What.** Establish the baseline security posture for a server-authoritative
system: secret handling, dependency integrity, license compliance, and a written
trust-boundary threat model.

**Why.** The whole design rests on "a client-computed number is a claim, not a
fact" ([`ARCHITECTURE.md`](../code/ARCHITECTURE.md) §4–§5). Secrets, vulnerable
dependencies, or incompatible licenses (especially around the C-2 base model)
are integrity risks that are far cheaper to fence off now than to retrofit. This
grounds Phase 3 (auth/PKI/receipts), Phase 5 (anti-collusion), and Phase 7.3
(moderation backdoor).

**How.** Turns the trust boundary from prose into enforced gates and gives every
later security-sensitive phase a documented threat model to extend.

**Validation.** A committed secret is caught by the gate; a vulnerable or
license-incompatible dependency fails CI; `SECURITY.md` + a threat-model stub
exist and are referenced from the architecture doc.

- [ ] Add `SECURITY.md` + a lightweight threat-model stub anchored on the server-authoritative trust boundary and the "no transcripts durable" invariant.
- [ ] Implement secret handling end-to-end: `.env.example`, CI + pre-commit secret-scanning, and the enforced "names not values" rule.
- [ ] Add dependency **lockfiles + a pinned-version policy** and **generate an SBOM**; fail CI on unreviewed drift.
- [ ] Add dependency **vulnerability + license-compliance** scanning (ties to C-2 model redistribution terms + third-party deps).
- [ ] **Verify the base-model artifact's integrity** — the ~1.8 GB GGUF fetch (0.1) checks a pinned checksum/signature before load, closing the supply-chain gap for the largest untracked asset.
- [ ] **Establish the signing-key custody plan** for every signature the design relies on — mobile/desktop app signing ([ADR-0002](../design/ADR-0002-desktop-distribution-and-auth.md)) and server-signed presence/receipts/manifests (Phases 3/4) — locations, rotation, and access only; no keys in-repo.
- [ ] **Turn "no transcripts durable" into an enforced gate** (a test/lint that fails if a raw dialogue transcript can reach a durable store or server log) and write a short **data-classification & privacy baseline** the later PII work extends.
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
- [ ] Define the **metrics contract** (counters / timers / gauges) as a concern distinct from logs — the minimal signal set the C-3 cost model and the Phase 6.6 balance oracle consume — schema only, no collection yet.
- [ ] Establish **performance-budget baselines** + a place to record them (app cold-start, inference latency target, binary-size incl. the ~1.8 GB model delivery) feeding the Phase 1.6 device-viability gate.
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
- [ ] Define **canonical, stable serialization** for the `packages/` schemas (manifest, receipt, structured deltas) — deterministic field ordering + encoding — so checksums/signatures (0.6, Phases 4/5) and cross-version diffs are reproducible.
- [ ] Settle the **shared-schema strategy** implied by the 0.1 server-runtime decision: one schema package vs two aligned ones, and the **language-neutral contract** (e.g. JSON Schema) if the server is not Dart, so the receipt/manifest contract cannot drift across the trust boundary.
- [ ] Bind the schemas to the **`ruleset_version` registry** (0.7) and add **golden/snapshot fixtures** so a ruleset or schema change that alters a serialized outcome is caught by a failing test, not discovered in production.

---

## Phase 1 — Minimal Cross-Platform Runtime (PoC)

**Goal.** Prove the core promise: a small local model + a compact patient
manifest + a Flutter game loop runs on **both** an Android emulator and a Linux
desktop, and clears the blueprint's falsifiable exit gates.

**Scope id.** `phase-1`

**Why this is the first real build.** §1 names this the true first milestone.
It de-risks the project's three existential bets (model can act, device can run
it, users accept the download) before any content, networking, or economy spend.

**Validation.** The end-to-end loop runs on Android emulator + Linux desktop;
the four PoC exit artifacts (acting quality, device viability, download
acceptance, prompt token budget) are measured and recorded.

### 1.1 — Flutter app + llama.cpp FFI integration

**What.** Load the GGUF base model through llama.cpp via Flutter FFI and run a
single inference call from the app.

**Why.** Local inference is the load-bearing technical unknown; everything else
assumes it works.

**How.** Establishes the on-device inference path the whole session loop rides on.

**Validation.** App runs one inference and renders raw output on Linux + Android emulator.

- [ ] Integrate llama.cpp via Flutter FFI; load a GGUF model behind a `shared/` inference service.
- [ ] Confirm build + model load on Linux desktop and the x86 Android emulator.
- [ ] Expose model params (size, context window) through the central config authority.

### 1.2 — Minimal patient manifest schema + loader

**What.** Define a compact first-pass manifest (identity, tone, pressure state,
available interaction patterns) and load it from a bundled JSON file.

**Why.** The manifest is the content atom; the loop needs one concrete case to
run against.

**How.** Gives the prompt assembler and sim core their input contract.

**Validation.** A sample manifest parses into typed models; malformed manifests fail loudly.

- [ ] Define the minimal manifest schema in `packages/` (shared by app + tools).
- [ ] Implement the loader + typed models in `shared/`.
- [ ] Ship one hand-authored sample case for the PoC.

### 1.3 — Prompt assembler (pure, token-budgeted, tiered)

**What.** Implement the §6 prompt assembler as a pure function
`assemblePrompt(SimState, Manifest, ConversationWindow, tokenBudget) → String`
with the tiered structure (Tier 1 never truncated, Tier 2 capped, Tier 3 reserved).

**Why.** The token budget is a PoC exit gate (C-7); the assembler must be
verifiable without running the model.

**How.** Guarantees the model never receives an over-budget prompt and that clue
tokens survive — the spine of the sim-core/dialogue contract.

**Validation.** Unit tests prove tier truncation order and that the budget is
never exceeded (load-bearing logic per Principle 4).

- [ ] Implement the tiered assembler as a pure function in `core/`.
- [ ] Enforce `tokenBudget` with tier-ordered truncation; reserve generation headroom.
- [ ] Implement the history-digest compiler (structured summary, never raw deltas).
- [ ] Unit-test budget compliance and clue-token survival independent of the model.

### 1.4 — Simulation core vs dialogue layer split

**What.** Implement the deterministic core that resolves one turn (approves
context, emits mandatory clue tokens) and hands only approved content to the model.

**Why.** §4: the model voices dialogue, it never decides outcomes. This split is
what makes the game fair and testable.

**How.** Cements the authority boundary the entire design depends on.

**Validation.** Given a fixed state + action, the core produces a deterministic
outcome and prompt context; the model output changes nothing mechanical.

- [ ] Implement the deterministic turn resolver in `core/` (no I/O, no model calls).
- [ ] Route mandatory clue tokens into the prompt; validate survival post-generation with a templated fallback.
- [ ] Keep all model interaction behind the `shared/` inference service.

### 1.5 — End-to-end session loop

**What.** Wire the full path: Flutter UI → load case → compose prompt from sim
state → local inference → render dialogue back into the session view.

**Why.** §1's explicit PoC definition; a single connected flow is the milestone.

**How.** Produces the first playable vertical slice the exit gates measure.

**Validation.** A player can open a case and exchange several turns on Linux +
Android emulator.

- [ ] Build the minimal session UI (case view, action input, dialogue render).
- [ ] Connect UI → sim core → prompt assembler → inference → render in one loop.
- [ ] Confirm the same build path works on Linux desktop and Android emulator.

### 1.6 — PoC exit-gate measurement

**What.** Measure and record the four falsifiable gates before declaring the PoC
passed.

**Why.** §1 is explicit: "it produced text" is not a pass. Red gates mean the
architecture is revisited before further spend.

**How.** Converts the PoC from a demo into a de-risking decision point.

**Validation.** All four artifacts are recorded in `docs/reports/`; device
viability is explicitly marked pending until the human opens physical-device testing.

- [ ] Measure **acting quality** under a worst-case full-manifest prompt.
- [ ] Record **prompt token budget** (C-7) vs the chosen model's usable context.
- [ ] Define the **download-acceptance** delivery/retry strategy for the ~1.8 GB first-run model.
- [ ] Record the **device-viability** method + the 1–1.5B fallback plan (physical-device measurement gated on human sign-off).

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

### 3.2 — Profile store & session handshake

**What.** Implement the primitive-payload profile schema (<0.5 KB) and the boot
handshake that initializes the local game brain (§3).

**Why.** The profile is the authoritative player state the client only caches.

**How.** Establishes the source of truth for progression balances.

**Validation.** Boot pulls the profile; only server-accepted results mutate it.

- [ ] Implement the primitive profile schema (atomic metrics only; no transcripts/logs).
- [ ] Implement the session handshake that hydrates the local game brain.
- [ ] Confirm profile writes happen only via server-accepted results.

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
