# Psychosims — end-to-end project assessment

Assessment date: 2026-09-10. Baseline: `main`, commit `b9b72d93d6d302eef96e116161235b8f1a0258b8`; llama.cpp submodule `311d4211bf1611ff7ca6b67035a4a07c79766efc`. The working tree was clean before assessment.

## Assessment

**Psychosims has a substantial, tested deterministic simulation foundation, an incompletely connected Flutter prototype, and substantial backend components that are not yet an operational authoritative service. It is not ready for external alpha or release in the current checkout.** The most valuable next milestone is one working, persistent gameplay journey through the real application and server.

The design is coherent: fictional psychology-practice strategy, local AI for dialogue, deterministic rules for outcomes, and server authority for progression, ownership and shared economy. The separation is a useful foundation. Implementation breadth is strongest in the rules libraries; integration, production persistence, device validation and actual player-facing progression lag behind. See the [charter](../project/CHARTER.md), lines 5–43.

The immediate problems are concrete: a clean native build fails; production app bindings cannot resolve their configuration dependency; downloaded models are not consumed from their download location; the application does not complete sessions into career progression; the server executable does not wire its identity/storage/receipt services; and receipt acceptance has transaction and duplicate-processing defects. Adding content or multiplayer features before closing these seams would multiply the paths needing repair.

### How to read this report

- **Verified now:** commands executed against this checkout, with results in section 5.
- **Source-confirmed:** implementation and tests inspected, with file/line evidence; runtime consequences not necessarily reproduced on a device or live database.
- **Historical/documented:** earlier reports and checked roadmap bullets, which are not treated as current passing evidence.
- **Planned:** roadmap work without a complete implemented path.

This review covers first-party app, core/schema/config packages, native integration, server, tests/build/CI, roadmap/specifications and operational documents. CodeGraph was consulted first; queries that returned unrelated vendored llama.cpp symbols were supplemented by direct source inspection. This is not an exhaustive security audit or a live deployment/load test. No gameplay/server implementation fixes were made.

## 1. What is implemented

| Area | Delivered capability | Current maturity / gap |
| --- | --- | --- |
| Configuration and contracts | Central config loader, typed configuration, safe config output, canonical JSON, manifests, receipts, signed envelopes and gameplay state types. | Useful shared foundation. Schema tests pass; production dependency injection and cross-language service integration still need completion. |
| Deterministic gameplay | Seeded PRNG, integer/fixed-point boundaries, pinned rulesets, card ownership/equipment checks, contextual card effects, defense/trust/agitation/trauma, therapy settings, fictional medication, terminal outcomes and lifecycle. | Strongest implemented subsystem: 155 core tests pass. The application consumes turn resolution but does not orchestrate the full lifecycle. |
| Multi-session and career | Clues, persistent/stateless cases, inherited medication, bounded history digests, study/clinical grading, XP, reputation, currencies, recovery, pressure, cooldowns, clinic economics and offline case routing. | Library-level functionality with tests/showcases. Most of this is not reachable as a career experience through the four application routes. |
| Balance tooling | Scripted core runs, bots, scenario runner, sandbox/economic flags and showcase tooling. | Useful development tools. The static solvability check only checks nonempty/known interaction patterns; it does not establish that a patient is winnable. Historical balance sample: 60 runs, two manifests, three skill levels. |
| Flutter interface | Home, model download, loadout and structured-action session screens; dialogue streaming, cancel control, two therapy settings and some accessibility/reduced-motion handling. | Prototype screens. Binding, model-path, dialogue-validation, recovery and completion defects interrupt the intended journey. |
| Local persistence | Atomic session saves; career checksums/backups/import/export/budgets; signed receipt storage and queue abstractions. | Components exist, but save recovery and career/API/receipt services lack production flow consumers. A tested queue is not yet a signed, durable submission pipeline. |
| Native inference | Real llama.cpp loading, tokenization/chat templates, sampling, UTF-8 streaming, stop handling, cancellation flag, KV-prefix reuse and timing fields. | Real integration exists, but current wrapper/submodule API mismatch prevents a clean build. Runtime failure can silently select a stub. |
| Backend | HTTP lifecycle, boot handler, identity/token abstractions, PostgreSQL repositories/migrations, receipt validation, ledger, device keys, ownership, presence, offline reconciliation, audit, flags and resilience/metrics components. | Substantial components. Default binary wiring, SQL correctness, successful receipt acceptance, real providers and durable identity/key state are incomplete. |
| Operations | Logging, verification scripts, CI, deployment/backup/migration/retention/key-custody documents. | Useful scaffolding and runbooks. Current gates fail; executable deployment automation, live recovery/load evidence and a quantified infrastructure cost model are not established. |

Representative implementation anchors: [turn resolver](../../packages/psycore/lib/src/turn_resolver.dart):23, [multi-session resolver](../../packages/psycore/lib/src/multi_session_resolver.dart):16, [ledger](../../packages/psycore/lib/src/ledger.dart):8, [clinic economics](../../packages/psycore/lib/src/clinic_economy.dart):33, [scenario runner](../../packages/psycore/lib/src/scenario_runner.dart):35, [solvability oracle](../../packages/psycore/lib/src/solvability_oracle.dart):13, [app routes](../../app/lib/main.dart):39, [native wrapper](../../native/src/psychosims_native.cpp):432, [server routes](../../server/internal/server/server.go):109. Historical balance evidence: [Phase 2 exit report](phase_2_exit_report.md):68–86.

## 2. The end-to-end player journey

| Journey step | What happens today | What must connect |
| --- | --- | --- |
| Open app → choose model/session | Home and destination screens exist. | Model-fetch/session bindings request `Config`, while startup registers `ConfigProvider`; normal navigation fails dependency resolution. |
| Download → run selected model | Downloader stores files under application documents `/models`. | Session looks in system temp, then uses a PoC fallback filename. Use one authoritative model cache and assert actual model/backend identity. |
| Select cards → play turns | Loadout and deterministic resolution exist. | Only offer valid equipped actions; reconcile clue validation with sanitization; enforce output checks before rendering. |
| Finish → rewards → next case | Core produces terminal outcomes and progression functions exist. | Session controller ignores terminal outcomes and returns to ready. Add results, history, rewards, persistence and next-case orchestration. |
| Close/crash → resume | Checkpoint writer exists. | Case loading clears the checkpoint; application never consumes the saved checkpoint. Define and implement recovery semantics. |
| Sign in → load authoritative profile | Boot, token and identity components exist. | Binary has no configured auth/profile/store dependencies; live provider verifier and durable identity mapping are absent. |
| Finish offline → reconnect → submit | Receipt schemas, signature verification and queues exist separately. | Provision a real device key, produce/sign receipts, persist envelopes, expose HTTP acceptance and reconcile authoritative state exactly once. |
| Trusted economy → social/content/endgame | Specifications and partial foundational types exist. | Phases 4–7 remain planned and depend on the preceding functioning journey. |

## 3. Roadmap reality

Counts below include `- [x]` / `- [ ]` bullets between each phase heading and the next phase/appendix. Nested bullets have equal weight. **These counts are bookkeeping, not an estimate of engineering effort or percentage of finished product.**

| Phase | Checked / total | Evidence-based interpretation |
| --- | ---: | --- |
| 0 — Foundations | 92 / 92 | Foundations/conventions largely established; green checkboxes do not prove current builds or deployed operations. |
| 1 — Runtime PoC | 90 / 93 | Historical desktop/emulator evidence; current native build broken; physical-device, download acceptance, quantization and full-context validation incomplete. |
| 2 — Offline core | 87 / 87 | Broad implemented mechanics, with passing core tests. Integrated career play and actual application recovery remain incomplete. |
| 3 — Authoritative server | 92 / 92 | Completion is overstated. Components exist, but executable wiring, client trust path, SQL correctness and acceptance evidence are missing. |
| 4 — Content pipeline | 0 / 15 | Enriched manifests, generation, validation, signing, delivery/revocation and routing remain planned. |
| 5 — Online economy/social | 0 / 18 | Authoritative payouts, histories, anti-collusion, referrals, hidden quantities and realistic multi-client testing remain planned. |
| 6 — Endgame/UGC | 0 / 19 | Authoring, royalties, group practices, moderation operations, macro events and adaptive oracle remain planned. |
| 7 — Presentation/launch | 0 / 22 | Art, monetization, moderation UI, cosmetic hooks, store preparation and five-platform release work remain planned. |
| **Total** | **361 / 438** | **77 explicitly unchecked tasks, plus incomplete acceptance criteria inside checked tasks.** |

The [roadmap snapshot](../planning/ROADMAP.md):27–35 still reports 269/438 and Phase 3 as 0/92, while its detailed Phase 3 checklist is 92/92. The [Phase 3 exit report](phase3-exit-report.md):53–58 also admits missing client key provisioning/receipt production, live identity verification and load validation. Source inspection finds queue/storage classes now present, so that historical report is partly stale too; their missing production integration remains material. Neither the old snapshot nor the checked checklist is a reliable readiness indicator.

Additional acceptance gaps:

- Physical-device battery/memory survival remains unproven despite checked bullets with pending/partial notes ([roadmap](../planning/ROADMAP.md):884–886; [device specification](../specs/DEVICE-SPEC.md):48–53).
- The “worst case” prompt measurement used an empty conversation window and minimal digest; a full conversation plus digest remains unmeasured ([token budget](../specs/PROMPT-TOKEN-BUDGET.md):61–73).
- Infrastructure cost entries are still `$`/`$$` placeholders, not a measured or quoted budget; cold-start figures are targets ([cost model](../specs/INFRA-COST-MODEL.md):7–14,52–57; [deployment shape](phase3/deployment_shape.md):10–16).
- ADR-0006 says the server does not derive Doubt/pressure/Trauma Severity, while C-9 and Phase 5 require it. Reconcile bounded server derivation with the decision not to replay the entire simulation ([ADR](../design/ADR-0006-server-runtime-go.md):22–24; [server-derived quantities](../specs/SERVER-DERIVED-QUANTITIES.md):4–6,22–45).

## 4. Prioritized defects and risks

Priority describes impact on the next usable/releasable milestone. Backend findings below are latent defects in services that are not currently exposed by receipt routes; they are not claims of an exploited deployment.

### P1 — restore basic execution and a complete session

1. **Clean native compilation fails.** `llama_model_params` no longer has `use_mmap`, but the wrapper writes it at [psychosims_native.cpp](../../native/src/psychosims_native.cpp):435. This is a directly reproduced compiler failure against the checked-out submodule. Align the wrapper and pin, then verify the real native backend and sanitizer suite.

2. **Production dependency injection breaks both main flows.** [AppBindings](../../app/lib/shared/injection.dart):16 registers `ConfigProvider`; [SessionBindings](../../app/lib/features/session/session_bindings.dart):19 and [ModelFetchBindings](../../app/lib/features/model_fetch/model_fetch_bindings.dart):13 request `Config`. Tests inject `Config` themselves and conceal the mismatch. Add navigation tests using real startup bindings.

3. **Model download and loading disagree; failed real loads become successful stubs.** Compare [fetch controller](../../app/lib/features/model_fetch/model_fetch_controller.dart):52, [session bindings](../../app/lib/features/session/session_bindings.dart):54 and [session fallback](../../app/lib/features/session/session_controller.dart):378. The [native loader](../../native/src/psychosims_native.cpp):475 returns a stub after a model-load failure. Require a shared cache/tier selection and explicitly separate development stub behavior from a successful real-model launch.

4. **Sessions never become career progress, and recovery is not implemented in the live flow.** [SessionController](../../app/lib/features/session/session_controller.dart):322 ignores the resolver's terminal outcome, returns to ready, and produces no receipt/reward/history transition. Its case loader clears checkpoints at line 181. The available action list at line 215 also includes unequipped patterns. Implement one complete terminal transition and actual checkpoint restore, then test session completion, restart and next-case continuity.

5. **Dialogue checks conflict at the controller boundary.** The controller supplies identical clue lists as both required and removable tokens ([controller](../../app/lib/features/session/session_controller.dart):314). [Sanitizer](../../app/lib/shared/dialogue_sanitizer.dart):18 removes them before [planner](../../app/lib/shared/response_planner.dart):60 verifies their presence. Retries share a buffer, and raw tokens are rendered before validation (controller:287–311). Validate the raw output contract before display sanitization, isolate retry buffers and test the actual composed call.

### P1 — make the authoritative boundary real and correct

6. **The server executable does not wire its services.** [main.go](../../server/cmd/psy-server/main.go):25 calls `server.New(clock)` without auth/profile/health dependencies. Only health, readiness, time and boot routes are registered ([server.go](../../server/internal/server/server.go):109); default boot returns unauthorized and readiness reports an unconfigured store. Receipt/offline/identity components are not working HTTP APIs in this binary.

7. **Receipt processing is neither exactly once nor fully transactional.** [Submit](../../server/internal/receipts/receipts.go):201 checks idempotency at line 215 but does not record acceptance before returning. It adds placeholder XP `+10` at line 236; replay can award XP again while duplicate ledger events are ignored. [Profile writes](../../server/internal/profile/profile.go):99 use `sql.DB` outside the receipt transaction, so a later audit or transaction-commit failure cannot roll back that profile mutation. Use one transaction for profile, ledger, idempotency and audit, with durable account-scoped uniqueness and authoritative reward rules.

8. **SQL repositories do not match the assumed behavior/schema.** Boot tries to create a missing profile through an UPDATE-only method ([boot](../../server/internal/server/server.go):164; [profile](../../server/internal/profile/profile.go):93). Presence queries use `suite_id`, absent from its table migration, and signatures do not round-trip ([presence](../../server/internal/presence/presence.go):45–74; [migration](../../server/internal/store/migrations.go):123). Exercise first boot and repository round trips against actual migrated PostgreSQL.

9. **Receipt signatures do not establish authoritative entitlement.** Validation checks action ownership against the client's own submitted card library ([receipts](../../server/internal/receipts/receipts.go):144), without checking the authoritative profile or patient ownership/lease. [Offline submission](../../server/internal/offline/offline.go):67 does not call its separate lease checker. Bind accepted input to authoritative state before exposing these endpoints.

### P2 — close reliability, privacy and operations gaps

| Concern | Consequence and evidence |
| --- | --- |
| Inference lifecycle | Main and worker isolates both load contexts; the main load is synchronous. Active generation blocks the worker message loop, preventing its queued cancel message from being processed until generation ends. Timing reads use the other context. [InferenceService](../../app/lib/shared/inference_service.dart):342,353,490,506,577,762. Test active cancellation and real memory/latency behavior. |
| Durable dialogue contradicts privacy comments | Checkpoint serialization includes role/text conversation pairs, including generated dialogue, despite the no-durable-raw-transcript claim. [Session persistence](../../app/lib/shared/session_persistence.dart):35; [controller](../../app/lib/features/session/session_controller.dart):330. Resolve the data contract and test what is actually written. |
| Idempotency isolation/concurrency | SQL key is globally unique, while lookup is account-scoped; `CheckOrBegin` only looks up rather than reserving atomically. [Migration](../../server/internal/store/migrations.go):14; [idempotency](../../server/internal/idempotency/idempotency.go):94–118,146–164. |
| Ownership restrictions | `Claim` ignores memory class, SQL omits it, and empty class defaults to persistent. Referral/pool transfer is not implemented by changing state alone. [Ownership](../../server/internal/ownership/ownership.go):75–88,113–118,154–184. |
| Identity/key durability | Only a stub provider verifier and in-memory identity/device-key stores exist; token account revocation is a no-op. [Identity](../../server/internal/identity/identity.go):222,276; [tokens](../../server/internal/tokens/tokens.go):153. |
| Audit and migrations | Concurrent audit appends can share a predecessor; migration DDL/version recording is not atomic or serialized. [Audit](../../server/internal/audit/audit.go):57–75; [store](../../server/internal/store/store.go):125–129. |
| Resilience integration | Rate limiting, backpressure, flags and tracing components are not in the normal HTTP stack; metrics accumulate individual durations in memory. [Server](../../server/internal/server/server.go):99–106; [metrics](../../server/internal/observability/observability.go):70–74. |
| Build/CI credibility | Dart format script mutates files even in check mode and suppresses failure; vulnerability script also suppresses errors and may substitute `go vet`. CI does not fetch submodules, while native builds depend on llama.cpp and sanitizer CMake requires it. [Formatter](../../scripts/dart_format.sh), [vulnerability script](../../scripts/vuln_check.sh), [CI](../../.github/workflows/ci.yml), [native build](../../scripts/native_build.sh), [sanitizer](../../scripts/native_sanitizer_test.sh). |

## 5. Current verification evidence

Commands ran on the local Linux environment. No failing assertion was weakened, no test was removed, and no implementation was changed to manufacture a green result.

| Check | Result now | Interpretation |
| --- | --- | --- |
| `make build` | **FAIL** | Clean native build reaches wrapper compilation and fails on `llama_model_params.use_mmap`. Initial relocated CMake cache was diagnosed separately and bypassed with fresh generated artifacts. |
| `make server.build` | **PASS** | Go sources compile. |
| `make dart.test` — config | **7 passed** | Configuration behavior. |
| `make dart.test` — schemas | **12 passed** | Shared schema/canonical/manifest behavior. |
| `make dart.test` — core | **155 passed** | Deterministic core behavior. |
| `make dart.test` — Flutter | **58 passed / 34 failed** | All 34 failures report a missing native shared library in the fresh-build attempt. These are one shared prerequisite failure, not 34 independently diagnosed logic regressions. |
| `make server.test` | **27 tested packages passed; 3 packages have no tests** | Component and mocked/in-memory integration tests. No real PostgreSQL integration tests or successful `Submit` path are present. |
| `make lint` | **FAIL** | Raw `fmt.Printf` in `server/tools/showcase/phase3/showcase.go:40`; later aggregate checks do not execute. |
| `make dart.lint` | **FAIL** | Config/schemas clean; core has duplicate export and unused-variable warnings; aggregate stops before app. |
| App `dart analyze --fatal-infos` | **FAIL** | 2 warnings, 7 informational findings. |
| `make server.lint` | **FAIL** | `go vet` completes; 16 Go files fail formatting check. |
| Read-only `dart format --output=none --set-exit-if-changed config packages app` | **FAIL** | One file needs formatting: `strategic_exit.dart`. No source was reformatted. |
| Content integrity script | **FAIL** | Scans its own banned-term regex in `content/fictional_taxonomy.yaml`, flagging `schizophrenia`. This result is a gate-design false positive, not evidence of that term being presented to players. |
| Core purity script | **PASS** | Current smoke checks for prohibited nondeterministic constructs. |
| `make doctor`; framework test runner | **PASS** | Framework wiring. The current framework test runner invokes doctor; this is not broad application coverage. |

`make verify` cannot pass given these independent failures. Its mutation-prone Dart formatter was deliberately replaced with the read-only equivalent above. Native smoke/sanitizer execution after a successful fresh build, real GGUF inference, device behavior, live Google/Apple sign-in, PostgreSQL transactions, load/soak and deployment restore remain **unverified in this assessment**.

Some existing model checks also allow weaker evidence than their names suggest: [native smoke](../../native/test/native_smoke_test.cpp):79 and [model evaluation](../../app/test/poc_gate_exit_report_test.dart):301 skip real-model cases when weights are absent. The latter's refusal/latency assertions at lines 351 and 387 do not enforce product thresholds; the [statistics test](../../app/test/inference_service_test.dart):274 checks field presence. A green run must explicitly identify which real-model acceptance limits were exercised.

The Go green result is narrower than the Phase 3 claim: boot tests inject memory repositories and fake health/auth; receipt integration tests manually perform validation, ledger append and idempotency recording instead of calling successful service acceptance. The only `Submit` test rejects an invalid envelope before opening a transaction. See [boot integration](../../server/internal/integration/integration_test.go):26, [receipt integration](../../server/internal/integration/receipt_integration_test.go):193–220, [receipt test](../../server/internal/receipts/receipts_test.go):185 and [migration tests](../../server/internal/store/migrations_test.go):7.

Raw command evidence is retained locally in `/tmp/agent-runs/assessment-*.{cmd,log,exit}` for this session (timestamps `20260910T095254Z` through `20260910T095559Z`). Original native build artifacts were preserved/restored; the fresh diagnostic build is under ignored `native/build/assessment-clean-build-20260910/`. Generated SDK-path changes and the build-applied vendor patch were restored. Old cached binaries were not accepted as evidence of a working current build.

## 6. Recommended implementation sequence

These are proposed next milestones, not a replacement roadmap or a commitment to an estimated delivery date. They deliberately close partially delivered phases before expanding feature breadth.

| Order | Outcome | Acceptance gate |
| --- | --- | --- |
| 1. Restore trustworthy execution | Align native pin/wrapper; correct app bindings/model cache; repair failing and misleading checks. | Fresh checkout builds; non-mutating format/lint pass; actual app navigation tests pass; real native smoke and sanitizer pass; CI fetches required source and fails when checks fail. |
| 2. Complete one offline career loop | Loadout → real dialogue → terminal result → history/rewards → durable save → resume/next case. Integrate existing core functionality. | Real startup bindings; verified model identity; terminal action lock; crash/restart test; correct rewards/history; clue/streaming/cancellation tests; explicit durable-data contract. |
| 3. Complete one authoritative online loop | Real sign-in → persisted boot → device key → signed receipt HTTP acceptance → profile reconciliation. Fix SQL and transaction defects first. | Disposable PostgreSQL test runs real migrations; first profile creation succeeds; duplicate/concurrent retry changes state once; forced ledger/audit failure rolls everything back; restart and offline reconciliation preserve state. |
| 4. Establish device and operating evidence | Define performance thresholds; compare quantization/model tiers; measure minimum-device memory/battery/latency, full prompt context, model download behavior, infrastructure usage and recovery. | Physical-device results meet declared limits; actual cost worksheet, cold-start/load measurements and backup restoration evidence. This can run alongside steps 2–3. |
| 5. Deliver Phase 4 content pipeline | Enriched manifest → generation → real solvability/acting/content QA → signing → delivery/revocation → routing. | A newly generated case reaches a client through the trusted pipeline; invalid/unsolvable/revoked content is rejected. |
| 6. Deliver Phase 5 economy/social | Authoritative payouts/sinks, trusted histories, referrals, anti-collusion, server-derived quantities and multi-client simulation. | Entitlement/race/replay checks, realistic economy simulations and failure-injected reconciliation. Reconcile authority documents first. |
| 7. Deliver Phases 6–7 and release | UGC/endgame, staffed moderation, presentation, purchase flows and five-platform distribution. | Moderation capacity/SLA/backpressure, UGC abuse tests, purchase/entitlement validation, platform signing and full release acceptance evidence. |

Phase 4 routing consumes operational pressure whose trusted derivation is planned in Phase 5.5. Define a limited precursor or reorder that dependency explicitly. UGC similarly depends on moderation capacity and operating procedures, not only an authoring screen.

## 7. Documentation and planning hygiene

Update the live roadmap to distinguish **implemented**, **integrated** and **validated**, and refresh its summary from actual boxes. Keep historical exit reports immutable snapshots; link to this assessment and later measured results from the live roadmap/reports index. Do not interpret a passing component test or an existing service class as a delivered endpoint.

Repair the onboarding documentation: README still has scaffold quickstart text and a broken root `STARTER.md` link; the actual blueprint is [docs/design/STARTER.md](../design/STARTER.md). All six Phase 3 showcase report links point to absent files ([showcase index](showcase/phase3/INDEX.md):8–13). Cost, device, prompt and balance documents should label their measurements, assumptions and unmeasured targets consistently.

**Recommended decision:** prioritize integration and evidence for the existing offline/authoritative foundations. The investment in deterministic mechanics is reusable; the next increment should make those mechanics work as one durable player experience before funding broad content, social or launch scope.
