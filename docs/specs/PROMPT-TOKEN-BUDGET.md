# 🎯 C-7 — Prompt token-budget specification

> **Closes register item C-7** ([ROADMAP](../planning/ROADMAP.md#-conceptual-corrections-register)).
> §1 PoC exit artifact + §6 tiered structure. The *methodology* is fixed here; the
> measured worst-case number lands at the PoC (Phase 1.6) against the chosen model
> (C-2). Section refs (§N) → [`STARTER.md`](../../STARTER.md).

- **Status:** methodology set (measured value recorded in Phase 1.6)
- **Owner:** @maintainer
- **Consumed by:** Phase 1.3 (prompt assembler), Phase 1.6 (PoC exit measurement)

## The budget rule

The worst-case prompt must fit the chosen model's **usable** context window —
typically **50–70% of the advertised maximum** for 1–3B models — with headroom
reserved for generation output. The assembler **never** exceeds the budget; the
model never receives an unverified-length prompt (§6).

`usable_context ≈ advertised_max × [0.5..0.7]`  (exact factor measured per model at PoC)
`input_budget = usable_context − generation_reserve`

## Worst-case prompt (what must fit)

All at once (§1): nine-axis manifest fully populated · case-history digest ·
medication state · style archetype · mandatory clue tokens for the turn ·
sliding conversation window. This is the measured worst case, not the happy path.

## Tiered structure (from §6) and truncation order

| Tier | Contents | Budget policy |
|---|---|---|
| **T1 — fixed** | system/roleplay frame; core manifest state + active flags; medication + style archetype; **mandatory clue tokens** | **Never truncated.** If T1 alone exceeds budget → the manifest schema must be redesigned (hard fail). |
| **T2 — capped** | case-history **digest** (compiled summary, never raw deltas); last N conversation turns | Hard cap. Drop oldest turns **before** shortening the digest. |
| **T3 — reserve** | generation headroom | Fixed reserve; never consumed by input. |

Truncation, when over budget, proceeds **T2 conversation window → T2 digest**,
never touching T1 or T3.

## Assembler contract (verifiable without the model)

Pure function (§6): `assemblePrompt(SimState, PatientManifest, ConversationWindow, tokenBudget) → String`,
no side effects. Unit-tested (Phase 1.3) to prove:
- output token count ≤ `input_budget` for every input, including worst case;
- T1 content is always present and intact;
- mandatory clue tokens survive assembly (and the post-generation validation +
  templated fallback catches model omission, §4);
- truncation removes T2 in the specified order only.

## History-digest rule

The sim core compiles a fixed-token structured summary (prior treatment style,
trust trajectory, medication history, key outcomes) **before** each prompt. Raw
delta records are never injected regardless of session count (§6). The digest's
token envelope is a placeholder owned by the balance spec ([C-4](BALANCE-SPEC.md)).

## Measured at PoC (Phase 1.6, recorded there)

- [ ] Chosen model's advertised max + measured usable factor.
- [ ] Worst-case prompt token count vs `input_budget` (must fit with reserve).
- [ ] If it does not fit → apply the §6 tiered resolution (tighten caps / digest envelope);
      if T1 overflows → redesign the manifest schema (Phase 4.1 feedback).

## Open (resolved at measurement)

- The usable-context factor for the selected model + quantization.
- Generation-reserve size (target output length).
- N (conversation-window turns) and the digest token envelope — set with C-4 tuning.
