# ⚖️ C-2 — Base-model license shortlist

> **Closes register item C-2** ([ROADMAP](../planning/ROADMAP.md#-conceptual-corrections-register)).
> Candidate open base models for the on-device "Universal Actor" (§5), compared on
> the one axis that constrains a commercial embedded game: **redistribution terms**.
> Section refs (§N) → [`STARTER.md`](../../STARTER.md).

- **Status:** drafted shortlist (final model chosen at the PoC, §1, jointly with C-1)
- **Owner:** @maintainer
- **Consumed by:** Phase 1.1 (which model to bundle), Phase 1.6 (acting-quality gate)

> ⚠️ **Not legal advice, and not a settled fact.** Model licenses change and
> carry acceptable-use clauses. Every row below **must be re-verified against the
> official license text at selection time** and reviewed before shipping. This
> table is a starting shortlist, not a clearance.

## Why the license gates model choice

The game **embeds and redistributes** the model inside the app binary/first-run
download. That is redistribution, so the license must permit commercial
redistribution of the weights (or a quantized derivative) inside a closed
product. A model that is excellent but non-redistributable is disqualified
regardless of quality — which is why the licence is settled *at* model selection,
never discovered afterward (§1).

## Shortlist (1–3B class, on-device viable)

| Model (size) | License family | Key redistribution consideration to verify |
|---|---|---|
| **Qwen2.5 1.5B** | Apache-2.0 (per-size — verify) | Permissive; several Qwen2.5 sizes are Apache-2.0 while some (e.g. 3B, 72B) use a separate Qwen license — **confirm the exact size's license**. |
| **Phi-3.5-mini (3.8B)** | MIT | Very permissive; slightly above the 3B target — check RAM fit against C-1. |
| **Gemma 2 2B** | Gemma Terms of Use (custom) | Redistribution allowed with the prohibited-use policy attached + notice requirements; **must pass along terms** — verify game use is permitted. |
| **Llama 3.2 1B / 3B** | Llama 3.2 Community License (custom) | Permits commercial use with attribution ("Built with Llama") + an acceptable-use policy; a >700M-MAU clause exists (not a near-term concern) — **verify attribution + AUP**. |
| **SmolLM2 1.7B** | Apache-2.0 | Permissive; smaller capability — a strong Tier-B (fallback) candidate (C-1). |
| **TinyLlama 1.1B** | Apache-2.0 | Permissive; lowest capability — fallback-of-last-resort candidate. |
| **StableLM 2 1.6B** | Community/Non-commercial variants exist — **verify** | Some Stability releases require a membership/commercial agreement — check before shortlisting seriously. |

## Selection criteria (applied at the PoC)

1. **Redistribution permitted** for commercial embedding (hard gate — verified license text).
2. **Acting quality** under worst-case prompts (§1) at the chosen quantization.
3. **Fits the C-1 floor** (peak RAM + tokens/sec) in its Tier A or Tier B slot.
4. **Attribution/notice obligations** are satisfiable in-app (about screen, store text).
5. **Quantization terms** — confirm producing/shipping a GGUF Q4 derivative is allowed.

## Recommendation (provisional, to confirm at PoC)

**Provisional selection (recorded as [DECISION 0015](../project/DECISION_LOG.md)):**
prefer **permissive licenses only** (Apache-2.0 / MIT) to keep the base-model legal
surface to "include the license text + notices" — no acceptable-use policy,
in-app attribution string, or MAU clause.

- **Tier A — primary:** **Qwen2.5 1.5B (Apache-2.0)** — fits the on-device 1–3B target; **verify the exact 1.5B size is Apache-2.0** (Qwen licenses vary per size).
- **Tier A — comparator:** **Phi-3.5-mini (MIT)** — cleanest license; only used if peak RAM clears the [DEVICE-SPEC](DEVICE-SPEC.md) floor (3.8B is above the 3B target).
- **Tier B — fallback:** **SmolLM2 1.7B (Apache-2.0)**.
- **Deferred unless they clearly beat the permissive picks on acting quality:** Gemma 2 2B (Gemma Terms) and Llama 3.2 1B/3B (Llama Community License) — usable but add notice pass-through, an AUP, a "Built with Llama" attribution, and (Llama) a >700M-MAU clause. **StableLM 2 1.6B is disqualified** unless a commercial-permitted variant is confirmed.
- The **final pick is an output of the Phase 1.6 acting-quality + device gates**,
  recorded in the PoC exit report and the [DECISION_LOG](../project/DECISION_LOG.md).

## Open (resolved at selection)

- Exact license text re-verification for every shortlisted model + size.
- Attribution wording placement (about screen / store listing).
- Whether one model serves both tiers or Tier A/B use different families.
