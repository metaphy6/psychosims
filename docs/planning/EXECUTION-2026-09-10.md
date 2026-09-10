# Authorized implementation execution plan — 2026-09-10

## Goal

Resolve every finding in the [assessment](../reports/2026-09-10-project-assessment.md), then complete the locally implementable [roadmap](ROADMAP.md) so the game works as a durable offline and authoritative online experience. ROADMAP remains the canonical deliverable/status checklist; this document maps repair work and acceptance evidence to it.

## Current stop boundary

The user subsequently instructed: finish the last work and stop. The reviewed
W3/W4 repair slice is staged as `remediation-20260910-w34` (298 files including
the earlier foundation). Only the already-started configuration-driven dialogue
retry fix was finalized and verified as `remediation-20260910-final`.
Lifecycle/sign-in and PKI/content follow-ons were
not implemented. Remaining roadmap items below are recorded for a future
explicit continuation; they are not an instruction to resume automatically.

## Non-goals

- No cloud deployment, public hosting, publishing, store submission, release, or distribution. Build deployment/release tooling and validate locally without running its publishing actions.
- No commits/pushes by agents, unapproved workstation/package changes, or replacement of existing user/concurrent work.
- No claim that mocks, local emulators, source inspection, a drafted policy, or an unavailable external gate constitute a completed device/provider/operational acceptance test.

The user authorized continuing through the full roadmap without asking between phases. Missing hardware, credentials, staffing, or prohibited release actions leave their exact gates pending; continue independent implementation and tests.

## Touched files

| Workstream | Expected existing homes; add adjacent files only after discovery |
| --- | --- |
| Build/runtime | `native/{src,include,tests}/`, native pin/patch records; `scripts/`; `.github/workflows/`; `app/lib/shared/inference_service.dart`; matching native/Dart tests |
| App/career | `app/lib/{features,shared}/`, `app/test/`, `app/lib/main.dart`; `packages/psycore/`, `packages/psychemas/`, `config/`, `test_fixtures/` |
| Authoritative service | `server/cmd/psy-server/`, `server/internal/`, `server/scripts/`, `server/tools/`; app identity/API/signing/queue consumers and shared schemas |
| Content/social/endgame/presentation | `content/`, existing tools/showcase homes, app feature modules, server domain modules, shared schema/core/config modules and their tests |
| Evidence/documentation | `docs/planning/`, relevant `docs/specs/`, `docs/code/`, `docs/design/`, `docs/reports/` and existing README files; existing changelog/release location if present |

Workers own disjoint modules. The coordinating parent owns integration, tracking and staging; this planning pass edits planning documents only. Preserve the staged assessment and all concurrent work.

## Test plan

Each behavior repair needs a regression that fails on the assessed behavior and passes after the fix. Tests must call production composition points as well as domain functions. Use `safe-run.sh`, retain failure evidence, and repair causes without weakening assertions. Run reviewer then verifier at each wave boundary; refresh a capability showcase after a full roadmap phase passes its complete gates.

| Wave | Outcome and acceptance evidence |
| --- | --- |
| W1 — execution/gates | Fresh native build against the pinned submodule; real native smoke and sanitizer; normal app bindings resolve model-fetch/session; downloaded selected model is the one loaded; format checks leave files unchanged; each quality/security gate rejects a planted defect and accepts valid input; CI obtains its submodule. |
| W2 — offline flow | Equipped actions → validated dialogue → terminal result → one reward/history update → saved career → resumed/next case, through actual startup bindings. Crash/cancel tests preserve the last committed turn; no raw transcript persists; real solvability rejects a structurally valid unwinnable case. Core/schema/config plus app regression suites pass. |
| W3 — authoritative flow | Local migrated PostgreSQL and real HTTP composition: sign-in adapter → first boot/profile creation → account-bound device key → signed receipt → durable exactly-once ledger/profile/ownership/audit/idempotency transaction → offline drain/reconciliation. Concurrent duplicate, cross-account, unauthorized card/case, expired lease, restart and forced rollback tests exercise successful service submission. |
| W4 — device/operating evidence | Define numeric thresholds before measuring. Full populated prompt/digest tests per model; quantization/tier comparison; download interruption/metered/disk behavior; local load/cold-start/bounded metrics/backup restoration and cost assumptions. Physical memory/thermal/battery and live provider/platform tests remain pending until their inputs are available. May run alongside W2–W3. |
| W5 — Phase 4 | Locally generated enriched case passes mechanical/acting/content validation, is signed, delivered through a local object-store adapter, verified by a client and routed only when fetchable. Corrupt/unsafe/unwinnable/revoked cases fail closed. Cloud delivery remains pending. |
| W6 — Phase 5 | Authoritative economy sources/sinks and bounded derived quantities; signed revocable history; referrals/hospitalization; farming/race/replay tests; local multi-client reconnect/failure scenarios. |
| W7 — Phases 6–7 local artifacts | Authoring/test-interview/validation/publish-to-local-catalog workflow; royalties/hiring/oversight/macro events/private oracle; art pipeline/presentation/accessibility; sandbox purchase entitlements/SKU tests; moderation and privacy controls; reproducible local build/provenance tooling. External staffing, provider/store/device acceptance and all real publishing remain pending. |

## Checklist

Initial dispatch units are intentionally small; expand later wave rows into similarly bounded tasks immediately before execution, using the canonical roadmap bullets as the acceptance owner. Checking a repair unit here never closes an entire roadmap bullet by itself.

- [x] W1.1 Add a regression for the pinned native API mismatch and align wrapper/build inputs.
- [x] W1.2 Add explicit real-backend load failure coverage; prevent a failed real load from becoming a successful stub.
- [x] W1.3 Run fresh native smoke/sanitizer checks and capture any remaining platform prerequisites.
- [x] W1.4 Add startup-binding navigation coverage and repair the config type mismatch.
- [x] W1.5 Test one shared model-cache path from completed fetch through selected-model load.
- [x] W1.6 Make formatting check-only and fail-propagating; test that it does not rewrite a fixture.
- [x] W1.7 Fix the content gate's self-match; test a valid taxonomy and a banned player-facing term.
- [x] W1.8 Make vulnerability/license scanner failures explicit; do not substitute lint for scanning. Actual license, vulnerability, inventory and planted-defect acceptance passes; broader platform-distribution gates remain pending.
- [x] W1.9 Correct CI submodule checkout and fix the assessment's current lint/format violations.
- [x] W1.10 Review the complete wave diff, run relevant tests/checks, and record evidence before parent staging.
- [x] W2.1 Replace static-only solvability with a bounded deterministic search returning a replayable winning witness or an explicit unproven result; test impossible cases, equipment, repeatability and exhausted budgets.

Assessment repairs and future wave coverage are mapped below. Continue W2–W7 after the repair staging window without a new authorization step. Checked repair units now reference current tests and reviews; they do not close larger combined roadmap acceptance gates.

### Current repair evidence

The 2026-09-10 implementation has independently reviewed native fixes for real
load failure, cached logits, active cancellation, disposal, and context overflow.
Direct C and Flutter reject oversized requests and then successfully generate a
valid next request. Evidence includes 25 Flutter inference tests, 4 native build
contract regressions, real Qwen smoke, and ASan/leak/UBSan cycles. These are Linux
host measurements; physical-device and other-platform gates remain pending.

Seventeen isolated quality-gate regressions pass, including error propagation,
read-only formatting, missing content inputs, and symbolic-link bypass attempts.
The real pinned Go vulnerability scan reports no vulnerabilities. A broader
multi-stack vulnerability/license/SBOM gate remains open under W1.8/0.6; this Go
result alone does not close it. `make lint` and `make format.check` pass.
The supply-chain follow-up repaired the reopened secret-hook, secret-scan,
and lockfile/SBOM findings. Gitleaks now scans staged and working bytes; all five
Dart lockfiles are retained and enforced. A deterministic CycloneDX inventory
contains 118 components with license fingerprints and dependency edges. The
actual OSV scan checks 105 Pub/Go/native commit identities and rejects omitted
coverage. Native commits are queried as commits, not GitHub Actions packages.
Installed-license classification replaces unsupported online Dart license data.
Exact-component GTK and Flutter engine notice exceptions record future source/
notice obligations; unknown and incompatible licenses remain failures.

`security-dependencies-current--20260910T114254Z-712705` passed 14 tests,
including real planted vulnerable-version and incompatible/unknown-license
acceptance, plus govulncheck, inventory drift verification and the actual OSV
scan. Independent security review passed 42 Python checks and seven config
loader tests, then identified custom-registry identity confusion. The fix
reads actual YAML lock metadata and requires matching package name/version and
`https://pub.dev`; its regression and the full live dependency gate pass in
`hosted-origin-live-gate--20260910T115450Z-750524` (15 tests).
The registry fix passed independent re-review and ten inventory tests in
`registry-review--20260910T121240Z-816527`. Model attribution is reconciled
against exact Qwen/Phi license sources and SmolLM2's official model card.

The privacy command now executes actual client persistence and PostgreSQL tests;
it no longer searches comments for the word transcript. Both propagation
regressions failed the old gate and pass now. Combined acceptance of the
encrypted client and actual PostgreSQL/race suite passes in
`certified-privacy-combined--20260910T134458Z-1163355` (42 client privacy tests).

The initial foundation pass ran 164 core tests, nine config tests and 122 app
contract tests. Independent offline review passed after repairing
concurrent checkpoint writes and empty-loadout recovery; a separate re-review
ran all 31 affected checkpoint, controller and navigation tests. Both bundled
cases have replayable winning paths. The refreshed balance showcase reports
four dead-currency flags and uneven bot outcomes; economy tuning remains open.
PostgreSQL foundation race tests pass, including independently re-reviewed legacy-account, authorization-lifecycle,
expiry, and rejection-audit repairs.

The independent strict `make verify` run
`repair-slice-verify--20260910T105509Z-531369` exited 0: 316 Dart/Flutter tests
(config 9, schemas 12, core 164, app 131), 17 quality-gate regressions,
4 native build regressions, 27 Go packages, real native smoke and four
ASan/UBSan/LSan model cycles including cancellation/regeneration. Lint,
check-only formatting (178 files, zero rewrites), build and doctor passed.
This closes the initial repair staging gate, not W3-W7 or the full roadmap.

The two real-model measurement suites now fail on missing weights and carry
an explicit acceptance tag; all 9 current Qwen/Phi checks passed on Linux.
These are happy-path samples, not a fully populated context or physical-device
quality assessment. The primary sample omitted its clue token before the
validated production fallback; expanded acting/context measurement stays open.

CI now runs explicitly named model-free contract verification. `make verify`
and `make native.acceptance` still require real-model acceptance. CI configuration
changes are local source changes; no hosted workflow, deployment or release has
been triggered.

### W3 / W4 active review evidence

- Server canonical HTTP composition, durable identity/token/device-key stores,
  browser code exchange, trusted catalog session permits and restart/retry paths
  pass real PostgreSQL race tests. The real Dart signer/API/outbox client also
  completes sign-in, session creation, signed receipt submission and reconciliation
  through Go HTTP and PostgreSQL. The initial path held rewards; the subsequent
  certified-outcome slice below now awards eligible finite proofs.
- The encrypted client integration passes in
  `w3-cross-stack-custody--20260910T115619Z-756857`; 67 owned/affected client tests
  pass and schema tests pass 18 cases. Account/profile/outbox/checkpoint snapshots
  now use authenticated encryption with platform-held keys. Subsequent review
  reproduced dropped logout obligations, unrecoverable denied session starts
  and free-text fields surviving encrypted persistence. Repairs passed 26
  independent checks in `w3-fixes-review--20260910T122836Z-875710`; the complete
  app suite passed 191 tests before the separate full-session bound follow-on.
- Independent server review reproduced expired-lease next-day session failure,
  private-route failed-auth limiter bypass, dialogue in known receipt fields,
  and a SQL key lookup ignoring cancellation. All four fixes passed re-review,
  real PostgreSQL race tests and lint in
  `server-review-final-confirm--20260910T121148Z-812298`. Server public
  verification-key publication remains later work. Replay retention, local erasure and finite
  certified payouts were subsequently implemented and verified below.
- Native exact-prompt caches preserve immutable prefill logits to repair Phi
  cold/warm divergence. Strict shorter-prefix reset, stochastic sampler, cancel
  and reset regressions pass. Independent review found generated-token counting
  merged UTF-8 callbacks and configured repetition penalty was ignored; fixes
  now have synthetic-logit/byte-split and real-model smoke/sanitizer evidence.
  The parameter-error classification correction passed review, smoke and
  sanitizer checks before the full matrix restarted.
- The full parent-owned three-model matrix completed in 42m33s with complete
  samples. Every model misses cold latency and at least one raw dialogue criterion;
  exact-prompt warm-cache and throughput pass. See the retained
  [baseline and raw evidence](../reports/2026-09-10-model-baseline.md).
  Corrective prompt/retry and actual-next-turn diagnostics are now recorded
  below; a full post-correction acceptance matrix remains pending.
- Download recovery fixes passed 48 independent checks in
  `w4-fixes-independent--20260910T123352Z-894355`, including the original queued
  cancellation and corrupt resume-metadata probes. Automatic metered detection,
  Windows free-space integration and physical platform onboarding remain open.
- Local database recovery passed twice independently; see
  [recovery evidence](../reports/2026-09-10-local-database-recovery.md). The
  bounded HTTP admission and actual HTTP/PostgreSQL load/cold-start gate also
  passed; see [local load evidence](../reports/2026-09-10-local-control-plane-load.md).
  Review strengthened the cancellation test to require recovery while SQL is
  still blocked, and a mutation ignoring cancellation now fails that assertion.
- Metrics now use fixed histograms and capped name sets instead of retaining
  every timing sample. 100,000-observation storage and concurrent aggregation
  regressions passed independent review/race checks in
  `metrics-independent-review--20260910T121540Z-825649`.
- Certified-outcome prerequisites exposed an ordinary 100-turn cure rejected
  by the old 64-action receipt cap and a config adapter confusing a trust bump
  with a trust threshold. The shared count limits and exact app/compiler balance
  now align at 120 actions, 1,024 deltas and 131,072 canonical bytes.
  A production-balance 100-turn Dart/app/Go/PostgreSQL flow passed with 100 actions
  and 154 deltas; this initial run held payouts. Independent review found the Go
  byte limit differed; absolute validator and HTTP single/batch rejection now
  precede device-key/receipt/profile database access (three Go packages pass). Explicit authored cards now
  survive production manifest loading, and the published manifest schema accepts
  the actual canonical action vocabulary. Their independent review passed.

### W3 certified outcomes — bounded implementation slice

The goal is to make the first authoritative online cure/reward path depend on a
trusted content-build result from the actual Dart resolver (accepted ADR-0009).
Device signatures and client ledger amounts remain insufficient. This slice
does not port the simulation to Go or enable any cloud/release action.

Expected files are the existing manifest loader/tests, a pure core outcome
compiler and adjacent tests, a headless tool in `tools/`, generated structured
fixtures/catalog evidence in the existing content/fixture homes, then the server
catalog/authorization/receipt transaction and app reconciliation consumers.

- [x] Preserve explicit authored card definitions through the production manifest
  loader; reject malformed/ambiguous executable definitions instead of silently
  substituting fallback cards. Preserve existing legacy manifest checksums.
- [x] Build immutable witness records by replaying the real core through a cured
  terminal state. Bind manifest checksum and schema, ruleset and effective balance,
  exact initial axes/seed, loadout, inventory and fixed controller settings.
  Exhausted search, unsupported starts, prior terminal states and altered
  execution inputs must not produce a certified outcome.
- [x] Make the content-build command deterministic and bounded. Verify source
  checksums and authoritative fictional taxonomy before output; generate the
  same proof bytes for the same approved inputs. No transcript or model output
  enters the certificate. Check generated evidence for drift in CI.
- [x] Load certificates only from operator-configured trusted catalog artifacts.
  Authorize only matching owned/equipped inputs and pin the certificate version
  in the durable permit. Revoked or stale certificates cannot authorize new
  payouts; unsupported paths remain explicitly unproven.
- [x] In the existing SQL acceptance transaction, match the certificate and
  derive configuration-capped rewards. Enforce once-per-case eligibility and
  atomically update profile, balanced ledger, cure ownership, receipt tombstone
  and audit. Every repeated acceptance returns its original durable verdict.
- [x] Prove exact Dart→Go binding, forged-input rejection, concurrent/restarted
  replay, rollback at each write, stale/revoked evidence, budget/cooldown denial
  and zero payout for uncertified receipts in real PostgreSQL/HTTP tests.
- [x] Surface certified/held verdicts and eligibility in the client without
  provisional local progression writes; independent review and full integration
  verification precede acceptance of ADR-0009 and staging.

Independent server acceptance passed in
`certified-review-independent--20260910T132125Z-1086625`: real PostgreSQL/race,
six top-level tests and twelve subcases, eight concurrent submissions, original
verdict after restart/cache cleanup, exact HTTP start replay after cure,
three-currency ledger conservation, cooldown/budget/revocation denial and
rollback at ledger, receipt, audit and deferred-commit boundaries. The real
Dart 100-turn certified client flow now passes both held and certified modes in
`certified-starter-dart-postgres--20260910T134209Z-1155140`: a fresh account
using its actual one-card inventory completes 100 actions/160 deltas (31,949
canonical bytes), earns XP100/study3/test-policy cash2.5m, and retains its
original verdict across encrypted restart, single and batch replay. Database
checks prove one cure, one audit record and six balanced ledger rows. The first
run correctly held this starter because only four-card witnesses existed; a
third real-compiler witness now covers the starter without granting inventory
or changing either existing proof. Seven tool tests and Go loader race tests pass.
The app contract suite passed 208 tests; independent certificate UI/privacy/wire
review passed 31 tests (`certified-app-review--20260910T134225Z-1156864`).

Prompt 1.1 now makes clue markers explicit, separates stable and changing
prompt components, and provides bounded typed corrective retries. Three fresh
model diagnostics are recorded without claiming the full matrix passed.
Independent review found and repaired raw-whitespace length bypass, bullet-list
bypass and corrective-context overflow; all original probes plus focused tests
pass (`prompt-repairs-independent--20260910T132309Z-1094945`, 24 tests).
The full dependency gate passed with the new tools lockfile: 119 inventory
components and 106 actual vulnerability identities, no known vulnerabilities
(`certified-dependencies-live--20260910T132042Z-1082550`).

Local maintenance now performs bounded cleanup and erasure with legal-hold and
replay fences. The actual pre-erasure backup/journal recovery test passes and
preserves ledger/audit/accepted hashes. Independent review required
crash-durable creation of journal directories and strict duplicate/case-alias
JSON rejection. Both fixes passed the original probes, fault injection and an
actual fsync trace in `journal-fixes-independent--20260910T133242Z-1127373`. See
[maintenance procedure](../../server/MAINTENANCE.md) and
[recovery evidence](../reports/2026-09-10-local-database-recovery.md).

The combined gate `certified-config-authority-verify--20260910T135052Z-1179439`
passes build/lint/format, 435 Dart/Flutter tests, 56 framework tests, four native
build tests, 32 Go packages and native contract/sanitizer checks. The separate
real held/certified client gate passes in
`certified-config-http-confirm--20260910T135052Z-1179462`. The HTTP harness now
uses a strict, local-only adapter inside the configuration module; the original
environment-authority gate remains unchanged. See the
[current remediation checkpoint](../reports/2026-09-10-remediation-progress.md).

Certification is conservative: a finite witness set can leave legitimate
alternative wins unproven. The UI must describe that limitation. The compiler
must not claim a full nine-axis manifest, signed content distribution, complete
cross-session history or general cheat-proof gameplay before those are built.

### W5 content pipeline — next implementation units

The final W3/W4 roadmap audit identified three adjacent app integration repairs
before this wave. The retry repair and its roadmap bullet are now complete;
the other two repairs remain pending:

- [x] Resolve `ResponsePlanner` retry count from the validated config authority
  in actual session bindings; test zero/bounded retry settings through production
  composition and preserve validated-only display.
- [ ] Wire background and memory-pressure events to owned cancellation/reset or
  unload/reload behavior; test interrupted generation, checkpoint consistency,
  foreground reuse and observer cleanup without racing the native context.
- [ ] Provision the authenticated account's device signing key at completed
  sign-in/recovery, before a first session; test lost responses, repeated sign-in,
  account switches and key-custody failures with actual production services.

Literal streamed raw dialogue and a durable conversation window conflict with
validated-only output and the no-durable-transcript invariant. Those wording
conflicts stay visible for an explicit architecture reconciliation; do not
display rejected partial output or persist dialogue to close a checkbox.

Goal: an authored, generated and validated enriched case reaches the local app
through a signed, revocable catalog and server-selected eligible assignment.
No public publication, cloud object store or human moderation sign-off occurs.
The existing manifest loader/core/compiler, `content/`, `tools/`, server catalog
and app API/cache homes own these changes; avoid a parallel simulation engine.

- [ ] W5.1 Add explicit production manifest version alongside legacy 1.0.0.
  Preserve old checksums; strictly type nine synthesis axes, fictional identity,
  clinical/memory/progression/narrative/behavioral fields and bounded rewards.
- [ ] W5.2 Test every axis, unknown enums, field/byte bounds, version/checksum
  tampering and stateless rejection of any signed-history envelope. Keep runtime
  contract and JSON Schema aligned with cross-language fixtures.
- [ ] W5.3 Generate deterministic tier-bounded variation from structured author
  input and a seed. Compile bounded model prose from approved tokens/templates;
  never infer inherent behavior or ability from a real protected demographic.
- [ ] W5.4 Run the actual bounded core solver for every generated candidate.
  Require a replayable cured witness where curing applies; explicitly validate
  social-chronic practice completion separately. Exhaustion stays unproven.
- [ ] W5.5 Gate generated names/templates/tokens through fictional taxonomy and
  bounded content checks. Add adversarial instructions, controls, banned labels
  and unsafe fixture rejection; keep policy screening distinct from acting QA.
- [ ] W5.6 Add reproducible sampled acting-QA inputs/results tied to manifest,
  model and prompt hashes. Measure real-model samples; failing/absent required
  review evidence prevents local catalog promotion rather than being a pass.
- [ ] W5.7 Sign exact validated manifest bytes with a separate local operator key.
  Persist a versioned local catalog, revocation generation and content hashes;
  test corruption, unknown key, key rotation, replacement and rollback rules.
- [ ] W5.8 Serve bounded content references through the local service and fetch
  through the app's verified cache. A missing/revoked/tampered artifact cannot
  be assigned or opened; public CDN and production key custody remain pending.
- [ ] W5.9 Derive the initial bounded operational-pressure input from accepted
  receipt cadence and trusted case tier. Never accept pressure in player input;
  test duplicates, rejected receipts, decay and concurrent profile updates.
- [ ] W5.10 Implement canonical routing using authoritative reputation, completed
  studies, server-known pricing and pressure. Cover social-chronic bias,
  tenure-gated chaos and compatible-tier reject/refer/force decisions.
- [ ] W5.11 Exercise generated-case fetch, verification, assignment, session and
  reconciliation with two local clients; inject missing files, revoke-after-cache,
  expired references and interrupted fetch/duplicate assignment.
- [ ] W5.12 Independent review, current full gates and headless capability
  showcase precede marking the locally completed Phase 4 bullets and staging.

Test plan: each unit's negative case must fail before implementation; fresh
Dart/schema/tool tests plus real HTTP/PostgreSQL and cryptographic client
integration verify boundaries. Risks are schema drift, stale signed caches,
leaking private solver witnesses, confusing finite certification with arbitrary
wins, and overstating automated safety/acting checks. Keep publication
fail-closed, proofs operator-only, and evidence limitations visible.

W5 contract review decisions:

- Production 2.0 dispatch must reach both Dart loaders and Go catalog/proof
  validators. Legacy 1.0 constructors, cards and checksum bytes stay unchanged.
  Nine synthesis tracks project deterministically into the existing simulation
  axes and cards; they do not replace the six accepted initial-state axes.
- Fresh authored content cannot set therapist histories, earned severity,
  ownership/lifecycle state or balances. History is a separate server-signed,
  revocable W6 envelope. Reward metadata expresses approved bounded weights,
  applied only under server policy; it never grants client-selected currency.
- Social chronic means a classification with `memory_class: stateless`, no
  history and repeatable non-cure completion. Individual instances require one
  global owner. Existing account-plus-template patient IDs remain valid only
  for explicit per-account practice, not shared individual assignment.
- A verified immutable content handle replaces rootBundle reloads for assigned
  cases in OnlineScreen and SessionController. Revalidate hash/key/version and
  current revocation generation on cache open/resume; missing assigned content
  cannot fall back to a bundled case. Private solver witnesses never ship.
- Eligibility must guard both recommendation and POST /v1/sessions, with
  profile/studies/pricing/pressure and content liveness checked in the ownership
  transaction. Stable operation identity prevents chaos rerolls on retries.
  Accepted unproven sessions supply cadence only, not clinical success/severity.
- Generated runtime prose comes from approved templates/tokens even when the
  authoring UI is bypassed. Promotion QA binds manifest/model/quantization/
  prompt/config hashes and explicit sample criteria; fallback-only, absent or
  stale evidence cannot pass a required real-model quality gate.
- Authoring rejects unknown fields. Runtime version compatibility may ignore
  harmless additive fields under the existing rule, while rejecting forbidden
  history/authority-bearing fields; do not change that policy accidentally.

## Risks

Receipt signatures authenticate a producer, not entitlement or correct gameplay. Resolve accepted state against the authoritative account/case, and keep all writes in one database transaction. Determinism and wire compatibility must survive every schema addition; reuse shared golden fixtures. A plain checksum detects corruption but is not a substitute for authenticated server state or secure key storage. Bound retries, input sizes, metrics, queues and retained histories. Keep the existing no-durable-transcript requirement while making recovery replay structured state; do not silently preserve dialogue to simplify resume.

External prerequisites do not block unrelated work. Record evidence limitations beside the owning roadmap bullet, not as an invented completed substitute:

The parent confirmed a local Docker daemon and real GGUF assets are available. Use them for PostgreSQL and real-model validation; they are not blockers. Check exact candidate/quantization availability before labeling any model evidence unavailable.

| Pending input/action | Local work that continues | Acceptance that remains pending |
| --- | --- | --- |
| Physical minimum-spec Android/iOS and other target hosts | Measurement harnesses, budgets, native/runtime fixes, test fixtures | Actual sustained memory/thermal/battery and five-platform runtime evidence |
| Google/Apple client registrations, test accounts, redirect configuration | Real verifier implementation, local JWKS/OAuth fixtures, replay/nonce/audience tests, durable identity integration | Live sign-in and cross-platform account linking |
| Model/art provider artifact access and licensed assets | Verified download/build adapters, reproducible prompts/metadata, local fixture tests | Missing real model/quantization or named art-provider output; never claim mock output proves it |
| Cloud store/CDN/KMS/deployment and public portal | Local storage/key adapters, restore/load harnesses, deployment definitions and dry-run validations | Cloud provisioning/deployment, live custody/CDN/production SLOs; prohibited by current scope |
| Store/signing accounts, platform SDK hosts, payment sandbox credentials | Entitlement adapters, purchase/replay/SKU tests, unsigned local artifacts and provenance | Unavailable platform/sandbox acceptance; no real purchase, publication, release or distribution |
| Human reviewer staffing and age-rating/store/legal review inputs | Moderation queue/backpressure/audit, policy drafts, disclaimers, data separation, local review UI | Staffed moderation capacity, final external ratings/approvals and opening the portal |

### Assessment acceptance mapping

Numbers below refer to assessment section 4; named rows also cover its P2 table and section 5 failed checks. Detailed repair tests remain adjacent to the implementation they protect.

| Assessment issue | Wave / roadmap owner | Required regression or evidence |
| --- | --- | --- |
| 1 Native compile | W1 / 0.1, 1.1 | Fresh pinned build, smoke and sanitizer; no stale binary used as proof. |
| 2 Config bindings | W1 / 0.9, 1.5 | Navigate with `AppBindings`, without test-only `Config` injection. |
| 3 Model paths/stub fallback | W1 / 1.1, 1.5 | Fetch/load selected model at identical path; corrupt/missing real model yields actionable failure. |
| 4 Terminal career/recovery/actions | W2 / 1.5, 2.2–2.9 | Only equipped actions; terminal action lock; one reward/receipt/history transition; kill/resume/next case with preserved career. |
| 5 Clue validation/retries/display | W2 / 1.4, 2.3 | Required clue survives raw validation; sanitized display contains no control markers; retry buffers isolated; rejected partial output never leaks. |
| 6 Executable service wiring | W3 / 3.0–3.4 | Start actual binary against local DB/config; authenticated boot and single/batch receipt HTTP routes work. |
| 7 Transaction/replay/+10 XP | W3 / 3.0, 3.2–3.3 | Successful `Submit` replay/concurrent replay awards once; durable idempotency recorded atomically; forced ledger/audit failure rolls profile back; reward from rules/config. |
| 8 First-profile/presence SQL | W3 / 3.2, 3.5 | Empty migrated database creates first profile; presence suite/signature round-trip through SQL. |
| 9 Entitlement/lease checks | W3 / 3.3–3.6 | Forged client library/foreign case/expired lease rejected against authoritative ownership and profile. |
| Inference context/cancel/metrics | W2 / 1.1, 1.5–1.6 | One owned worker context; active cancellation interrupts work promptly; load stays off UI; timings from active context. |
| Durable raw dialogue | W2 / 0.6, 1.4–1.5, 2.9 | Inspect actual checkpoint bytes; no raw role/text transcript; deterministic structured recovery retains valid progress. |
| Global/nonreserved idempotency keys | W3 / 3.0, 3.3–3.4 | Account-scoped uniqueness, atomic reservation/commit, concurrency and restart tests in PostgreSQL. |
| Ownership/memory-class/referrals | W3 / 3.6 | Persist supplied memory class; stateless remains stateless; legal referral/pool owner changes and double-claim races validated. |
| Identity/key durability/revocation | W3 / 3.1, 3.5 | Durable identities/public keys; restart/reinstall/rotation/logout/account-ban tests; real token verifier with local JWKS fixtures. |
| Audit/migration concurrency | W3 / 3.0, 3.3 | Concurrent audit chain validates; migration DDL/version record is atomic and serialized; rollback injection leaves consistent schema. |
| Resilience/metrics integration | W3–W4 / 3.1, 3.7 | Real HTTP stack rate limits/flags/traces/dependency failures; metrics storage stays bounded under sustained load. |
| CI/format/scanners/content false positive | W1 / 0.5–0.6, 0.12 | Check-only formatter does not mutate; scanner/tool errors fail; planted unsafe content fails while registry passes; recursive submodule checkout. |
| Core/app/server lint findings | W1 / 0.5 | Raw logging, duplicate export, unused variables and all reported format/analyzer findings repaired without weakening gates. |
| Static-only solvability | W2 / 2.8–2.10 | Structurally valid but impossible manifest rejected by deterministic gameplay search/bots; a known solution returns reproducible evidence. |
| Incomplete device/context/quant/download evidence | W4 / 1.6 | Fully populated per-model context, declared thresholds, tier/quant comparisons and fetch tests; actual physical measures separately recorded. |
| Unquantified infrastructure/restore/load | W4 / 3.2, 3.7–3.8 | Cost worksheet with explicit sourced assumptions, local measurements and restore evidence; no claimed live/cloud result. |
| Stale roadmap/reports/links/authority conflict | All / 0.4, 3.8, 5.5 | Accurate counts; original wording preserved for reopened acceptance; current docs link actual blueprint; showcase outputs exist; ADR agrees with C-9 bounded derivation. Historical report contents remain snapshots. |

### Remaining-phase acceptance mapping

Every remaining subphase stays authoritative in ROADMAP. Complete local implementation while retaining excluded deployment/release clauses as pending, even when their adapters and tests pass.

| Roadmap subphase | Wave | Acceptance slice |
| --- | --- | --- |
| 4.1 manifest | W5 | Versioned nine-axis/enriched schema; checksum and additive compatibility; stateless rejects history. |
| 4.2 generation | W5 | Seeded tier-bounded variations compile reward metadata; generated content passes fictional taxonomy. |
| 4.3 validation | W5 | Mechanical solver per manifest, sampled real-model acting QA, unsafe-content rejection and rollback/version tests. |
| 4.4 delivery/signing | W5 | Local publication signs exact payload; client fetch/verify rejects tamper/revocation; public CDN deployment pending. |
| 4.5 routing | W5 | Eligibility/fetchability, social-chronic bias, tenure gate, strategic exits; implement the bounded 5.5 pressure precursor first so routing never accepts client pressure. |
| 5.1 economy | W6 | Every currency has modeled source/sink; authoritative high-value payout; long-run inflation/dead-currency/rounding tests. |
| 5.2 histories | W6 | Signed versioned pseudonymous history; tamper and revocation rejected by clients. |
| 5.3 trauma/anti-collusion | W6 | Accepted receipts alone accrue severity; caps/decay/provenance; A→B→A produces no illicit payout. |
| 5.4 referral/hospital | W6 | Compatible receiver atomically gets ownership; hospital freeze/unfreeze preserves owner and records both triggers. |
| 5.5 Doubt/pressure | W5 precursor, W6 completion | Server clock/accepted history alone drives bounded quantities and transfer roll; retry idempotency; authoritative routing input. |
| 5.6 network sandbox | W6 | Multi-client local sessions survive timeout, duplicate/partial delivery, reconnect and transfer/reassignment reproduction. |
| 6.1 authoring | W7 | Authoring panel and successful test-interview gate feed the local validated/signing catalog. |
| 6.2 royalties | W7 | Validated treatment/cure pays once per eligible pair; download loops pay zero; caps/anomaly tests. |
| 6.3 practice | W7 | Joint hiring gates/slot cap, shared deck capability ceiling, bounded diminishing returns and oversight interventions. |
| 6.4 portal/moderation | W7 | Local draft/preview/validate/version/catalog workflow and field contribution tests; staffed public opening pending. |
| 6.5 macro events | W7 | Server seed deterministically drives bounded sociopolitical/weather effects and local client updates. |
| 6.6 private oracle | W7 | Evolving-state solver returns deck/win-band/confidence from scrubbed opt-in telemetry; private output excluded from client artifacts. |
| 7.1 presentation | W7 | Config-referenced build-time art tooling/provenance; baked layers/shaders/fracture; offline runtime and reduced-motion checks; unavailable provider output pending. |
| 7.2 monetization | W7 | Catalog/sandbox entitlement validation; replay/refund/invalid receipt rejection; in-game sinks; sidegrade/outcome-neutral SKU tests; no real transactions/publication. |
| 7.3 governance | W7 | Admin-only ban/privilege revocation/quarantine changes authoritative local state/delivery; player token denied; audit records actions. |
| 7.4 cosmetics | W7 | Local theme/skin delivery test; no launch cosmetic SKU in catalog; actual launch confirmation pending. |
| 7.5 framing | W7 | Fictional disclaimers, tone/content checks, separated PII/gameplay data and draft store metadata; external rating/approval pending. |
| 7.6 release preparation | W7 | Existing-or-new changelog/release docs, deterministic local builds/provenance and dry-run pipeline checks; unavailable target signing and every actual release/distribution remain pending. |

The pure Dart outcome compiler proves both bundled cases at production balance,
with explicit seed/loadout/start/controller binding, first-terminal success and
receipt wire-size limits. Independent compiler and server review passed; the
current combined suite includes 179 core and seven tool tests. Tools tests and
source/fixture `--check` are now
part of the normal gate; planted tool-test and fixture-drift failures fail it
(29 gate tests pass in `outcome-gate-green--20260910T125004Z-953530`).

The compiler passed independent replay/tool review and isolated source-drift
verification (27 tests). The new Go outcome loader pins exact operator artifact
bytes, rejects invalid/ambiguous shape, checks proof digests and exact wire sizes,
selects owned certified starts and compares all action/delta fields. Review
caught a false declared-size assumption; an actual 192,185-byte proof now fails
load. Independent outcome/config race suites pass. The source inventory was
regenerated to 119 components after tools dependencies changed. Atomic certificate
reward/verdict integration and its real PostgreSQL tests have passed independent
review; the app cross-stack integration remains pending below.

The server now has an independently reviewed certified acceptance path: migration 9 pins
certificate/artifact identity to the grant and stores the original verdict;
actual matching derives policy-bounded XP/study/cash, pairs recipient/source
ledger entries, marks the case cured and records once-per-account/case history
inside the existing transaction. Default cash is zero; XP100/study3 use current
base progression values, and rolling-window/cooldown limits are explicit local
engineering defaults. These are not a tuned full economy or human-play proof.
Eight concurrent submits, restart/cache-GC replay and audit-failure rollback
passed real PostgreSQL tests in `certified-pg-second--20260910T130953Z-1042375`.
Actual HTTP single/batch feedback then passed, including immutable original
profile version and idempotent start replay after a cure. Altered actions/deltas,
withdrawn/revoked certificates and disabled/over-budget policies paid zero.
The maintenance false Applied report and pending legal-hold races were repaired
and the full PostgreSQL/race suite passed. Source-ledger/receipt-write/deferred-
commit rollback and cooldown/once-per-case checks also passed independently in
`certified-review-independent--20260910T132125Z-1086625`. Client metadata UX
and real Dart certified reconciliation now pass the evidence above; full
combined verification and the current staging window remain in progress.
