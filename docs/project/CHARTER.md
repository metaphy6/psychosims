# 📜 Charter: Psychosims

> The "what is this project even" doc. One screen.

## Vision

A cross-platform, fictional social-simulation and strategy game about running a
psychology practice — where a small on-device AI voices believable patients, a
deterministic rules engine owns every outcome, and a small authoritative server
makes progression, ownership, and the economy trustworthy across players.

## Scope (in)

- A **Flutter** client for iOS, Android, Windows, macOS, and Linux.
- **On-device** LLM inference (llama.cpp via FFI) that generates *dialogue only*.
- A **deterministic simulation core** that owns all rules, state, and outcomes.
- A compact **patient manifest** content format (structured state, never transcripts).
- A **small but authoritative server**: identity, profiles, receipt validation,
  matchmaking, ownership arbitration, content signing, moderation, economy ledger.
- A **balance sandbox** for fast, bot-driven rule and economy testing.
- The 3–5 outcomes that define "done enough to ship":
  1. The end-to-end session loop runs on Android + Linux and clears the PoC gates.
  2. A full offline career loop (cases, cards, progression, recovery) is playable.
  3. Server-authoritative profiles + receipt validation resist client tampering.
  4. Server-generated cases are validated, signed, delivered, and matched.
  5. The cross-player economy is exploit-resistant and store/legal-defensible.

## Scope (out)

- **Free-form player messaging / chat** — disproportionate moderation, safety, and
  legal exposure for a small control plane (§1). Structured interactions only.
- **Real therapy / clinical use** — this is a fictional simulation, not medical care.
- **Real diagnostic labels or medications** (DSM/ICD, real drug brands) — fictional
  taxonomy only, across the entire content pipeline (§8).
- **A monthly model-retrain-and-ship pipeline** — the shipped model has a fixed
  footprint; bug logs feed an offline, opt-in improvement queue only (§18).
- **Paid cosmetics at first production** — deferred post-launch; architecture is
  cosmetic-ready but no cosmetic SKU ships at launch (§19).

## Audience

- **Primary**: players — solo clinicians building a practice; endgame institutional operators.
- **Secondary**: content creators (Medical Directors, community authors) supplying cases.
- **Operators**: the small team running the server control plane, moderation, and balance.

## Success criteria

- PoC exit gates (acting quality, device viability, download acceptance, prompt
  token budget) measured and green before content/networking/economy spend.
- Offline career loop is demonstrably fun without any server dependency.
- No monetized item alters a session outcome (the enforced SKU test).
- No known farming loop (trauma multiplier, creator royalties) is profitable.
- Infrastructure cost model holds at 10k MAU against the full server dataset.

## Non-goals & explicit trade-offs

- **Working software over ceremony.** Tests concentrate on load-bearing logic
  (sim core, economy, prompt assembler, receipt validation), not blanket TDD.
- **Local-first at the session level; server-authoritative for anything trustworthy.**
  The client proposes; the server decides.
- **Small server storage footprint, real server authority.** "Minimal" describes
  storage/per-session compute — never authority.

## Constraints

- **Legal/store safety** (§8): fictional framing, disclaimers, mature age band,
  no real health data, PII separated from gameplay data.
- **Device floor**: the shipped model size is bounded by a written minimum device
  spec and validated on physical hardware (a human-gated milestone).
- **Base-model license**: redistribution terms must permit commercial embedding.
- **Cross-cutting engineering rules**: centralized configuration and strict
  separation of concerns — see [`../code/ARCHITECTURE.md`](../code/ARCHITECTURE.md)
  and [`ROADMAP.md`](../planning/ROADMAP.md) Principles 1–2.
