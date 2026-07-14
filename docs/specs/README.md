# 📐 `docs/specs/` — commissioned specifications

Standing reference specifications the [`ROADMAP.md`](../planning/ROADMAP.md)
commissions as entry gates. These are the concrete artifacts behind the
[Conceptual corrections register](../planning/ROADMAP.md#-conceptual-corrections-register)
(C-1…C-11). Unlike a `design/` proposal (a change to be reviewed then built) or
a `reports/` snapshot (a point-in-time audit), a spec here is a **living
reference** that later phases implement and tune against.

Section refs (§N) point at [`STARTER.md`](../../STARTER.md).

| # | Spec | Closes in | Status |
|---|---|---|---|
| C-1 | [Minimum device spec](DEVICE-SPEC.md) | Phase 0.3 | drafted |
| C-2 | [Base-model license shortlist](MODEL-LICENSE-SHORTLIST.md) | Phase 0.3 | drafted |
| C-3 | [Infrastructure cost model](INFRA-COST-MODEL.md) | Phase 0.3 | drafted |
| C-4 | [Multi-currency balance spec](BALANCE-SPEC.md) | Phase 0.3 → tuned Phase 2.8 | skeleton |
| C-5 | [Desktop distribution + auth](../design/ADR-0002-desktop-distribution-and-auth.md) (ADR-0002) | Phase 0.3 → built Phase 3.1 | decided |
| C-6 | [Age-rating & content strategy](AGE-RATING-AND-CONTENT-STRATEGY.md) | Phase 0.3 → finalized Phase 7.5 | direction set |
| C-7 | [Prompt token-budget](PROMPT-TOKEN-BUDGET.md) | Phase 1.6 (measured) | methodology set |
| C-8 | [Patient lifecycle state machine](PATIENT-LIFECYCLE.md) | Phase 3.6 (implemented) | spec complete |
| C-9 | [Server-derived quantities](SERVER-DERIVED-QUANTITIES.md) | Phase 5.3 / 5.5 (implemented) | spec complete |
| C-10 | [UGC moderation staffing & SLA](UGC-MODERATION-SLA.md) | Phase 6.4 (before portal opens) | policy set |
| C-11 | [Session rule model](GAME-RULES.md) | Phase 2.1 / 2.3 (implemented against) | spec complete |

## Status meanings

- **drafted / skeleton** — the artifact exists and is usable; numbers marked as
  placeholders are owned by the balance spec (C-4) and tuned in the sandbox (§3).
- **decided / direction set / policy set** — the conceptual question is resolved;
  the named phase carries it into implementation or final sign-off.
- **methodology set** — the *how* is fixed; the measured value lands at the PoC.
- **spec complete** — the design is authoritative; the named phase writes the code.

## Rule

These specs are the single owner of their subject. If a later phase needs to
change a number or a rule, it edits the spec here — it does not fork a second
copy into code or another doc.
