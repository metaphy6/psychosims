# 📖 Glossary

Domain terms used across Psychosims. One line each. Alphabetic. Section
references (§N) point at [`STARTER.md`](../../STARTER.md).

| Term | Meaning |
|---|---|
| Acting quality | PoC gate: the model stays in character/coherent under worst-case prompts (§1). |
| Adaptive master playbook | Private, designer-only oracle recommending optimal card combos; offline/server-side, never shipped to client (§11). |
| Agent | An AI coding assistant working in this repo (Copilot, Claude, Gemini, …). |
| agitationLevel | Core sim-state variable tracking a patient's distress within a session (§4). |
| Attraction (Clinic Attraction) | Server-side weight (reputation + pricing + study fields + pressure) that routes cases to a clinic (§10). |
| Balance spec | The single authoritative owner of every constant, formula, and percentage; tuned in the sandbox (§9). |
| Base persona core | The single shipped GGUF "Universal Actor" model (~1.8 GB, fixed footprint) (§5). |
| Card taxonomy | The four card types: Disclosing, Relatable, Postponing, Manipulative (§16). |
| Chaos roll ("Misfortune Roll") | Tenure-gated ~5% chance to route a volatile case past the safety filters (§13). |
| Clue token | Gameplay-critical text the sim core injects as mandatory prompt content and validates post-generation (§4). |
| Config authority | The single centralized, typed, validated configuration layer (`config/`); Principle 1. |
| Cure retirement | A fully cured patient leaves the live pool and is archived into the completing therapist's record (§17). |
| Derangement | Manipulative-card failure state; recorded as a session delta and applied only on server acceptance (§16). |
| Dialogue layer | The local LLM; voices tone/personality but never decides outcomes (§4). |
| Doubt | Hidden per-patient pressure (server-derived) that can trigger a transfer roll (§12). |
| GGUF | The quantized on-device model file format loaded via llama.cpp (§5). |
| History envelope | Server-signed, tamper-evident, revocable per-session case-history entry (§17). |
| Idempotency key | Client-generated UUID on each receipt so re-submission is never applied twice (§3). |
| Individual patient | `memory_class: persistent` case that accumulates signed history; higher stakes/reward (§17). |
| Loadout | The capped set of Active Card Slots a player brings into a session (§11). |
| Manifest (patient manifest) | Compact structured JSON case definition (state, not transcripts); the content atom (§5, §12). |
| Matchmaking (canonical) | The single server-side routing function; display formulas are UI only (§2.3, §10). |
| Medical Director | Endgame role: authors + publishes custom case templates for the shared pool (§21). |
| memory_class | Manifest flag: `stateless` (no history envelope) vs `persistent` (accumulates history) (§12, §17). |
| Operational pressure | Visible, server-derived load metric feeding routing and recovery; no hidden well-being stat (§23). |
| Ownership (single-owner) | A patient is owned by one therapist at a time; transfers are server-arbitrated (§12). |
| Ownership lease TTL | Server-granted expiry allowing offline sessions against an owned patient (§3). |
| PKI (managed) | Server-provisioned signing keys for presence records, with revocation + recovery (§3). |
| Presence record | Server-signed profile snapshot published to matchup/referral directories (§3). |
| Prompt assembler | Pure, token-budgeted, tiered function building the model prompt; unit-tested without the model (§6). |
| Receipt (session receipt) | Structured end-of-session submission (start state, ordered actions, claimed deltas, `ruleset_version`) (§3). |
| Reputation (event-sourced) | Recency-weighted score updated per outcome (not a lifetime ratio) with decay + floors (§10). |
| ruleset_version | Field pinning which shipped rules produced a receipt; bounds are calibrated per version (§3). |
| Sandbox (balance) | Accelerated, bot-driven environment for rule/economy testing; core infrastructure (§3). |
| Sandbox (integration) | High-fidelity client/server network environment with failure injection (§3). |
| Signature principle | A card is strongest in its matching context; correctness is contextual, not fixed (§16). |
| Simulation core | Deterministic layer owning all rules, state, and outcomes; no I/O, no model calls (§4, §6). |
| SKU test | Enforced gate: no monetized item may change a session outcome or core progression (§19). |
| Social chronic patient | `memory_class: stateless`, low-stakes reusable case for training/recovery; preferentially routed to newcomers (§13, §17). |
| Study points / Subspecialty points | Progression currencies spent on the field-training tree (§9). |
| Trauma Severity Index | Server-derived multiplier over signed history; bounded + provenance-aware to block farming (§17). |
| trustScore | Core sim-state variable tracking therapeutic alliance within a case (§4). |
| Universal Actor | The design framing of the single base model as one actor voicing every patient via manifests (§5). |
