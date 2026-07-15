The psychosims_server is still a skeleton — no sim math implemented yet — which matters: **Phase 3 hasn't started, so this is the cheapest possible moment to revisit the runtime.** Here's my grounded read before I ask what specifically worries you.

## What this server actually is
Per README.md and the cost assessment: a thin, local-first **trust plane** — identity, profiles, receipt validation, ownership arbitration/state machine, content signing, economy ledger, moderation, matchmaking, macro-event seeding. **No ML, not in the session hot path, ~0.5 KB profiles, scale-to-zero cost.** So it's I/O-bound, correctness-critical, and schema-locked to your Dart `psychemas`.

That profile means the usual "Python is slow" argument barely applies — the real question is **correctness and drift**, not throughput.

## The one concern I'd weight highest: determinism parity with the Dart core
Your `psycore` encodes a strict deterministic contract — portable integer PRNG, fixed-point (scale 1e4), one canonical JSON serializer. And GM-2/GM-3 (per the cost assessment) push **deterministic aggregate math onto the server**: "doubt is derived server-side," "operational pressure is computed server-side," "Trauma Severity Index accrual is a server-side function," and the "manifest is re-signed on server acceptance."

If the server re-derives any of those in Python, you now maintain the **same fixed-point / PRNG / canonicalization logic in two languages**, and ADR-0003's contract test only round-trips JSON *shape* — not *computational equivalence*. That's an ongoing drift hazard on your most safety-critical surface (economy + anti-cheat + signatures). A **Dart server could import `psycore` directly → one source of truth, zero reimplementation.**

## Honest tradeoff of the realistic options *for this workload*
- **Dart (dart_frog / shelf / serverpod):** biggest win — share `psycore` + `psychemas` verbatim → zero schema/math drift, one toolchain. Cost — smaller managed-deploy/observability/BaaS ecosystem, smaller hiring pool.
- **Python + FastAPI (current):** fastest to build, best ecosystem/ops/observability, OpenAPI for free, easy contributors. Cost — reimplements schemas *and* any sim math; needs a real cross-language golden-vector test, not just schema round-trip; must reproduce your canonical-JSON byte format exactly for signatures.
- **Go:** great tiny static binary, superb cold-start for scale-to-zero, strong concurrency. Cost — third language, same reimplementation/drift class as Python, another toolchain.
- **Rust:** best correctness/perf, worst build-time/contributor cost — overkill pre-PoC (ADR already rejected it).

## Process note
ADR-0003 is **accepted**. If we change the runtime, the clean move is a **new superseding ADR** that references and supersedes 0003 (your decision log is append-only) — not a hand-edit. If we keep Python but harden the guard, that's a consequences/amendment note instead. I can draft either.

The decision really hinges on one fork, so:

Analyzing your answers...

That free-text answer is the crux, and it actually *reshapes* the whole decision. Let me reflect it back and re-rank honestly — no files, just the reasoning.

## Your model dissolves your #1 concern (mostly)
You want the server to **verify cheating via a trusted mechanism** and **store/retrieve login + patient-ownership data** — and to *compute as little as possible*. That means the server is **not re-deriving** doubt/pressure/TSI. And if it doesn't re-derive sim math, the determinism-parity worry with `psycore` **largely evaporates** — which was the single strongest reason to pick Dart-for-sharing. So paradoxically, your "compute the least" instinct removes the best argument against Python.

There's one condition to keep it evaporated: **verify signatures over the exact received bytes, never re-serialize or re-simulate to check.** If the client signs `CanonicalJson` bytes and the server validates the signature on those same bytes (and only *parses* the few fields it enforces), then the server never has to reproduce your canonical-JSON byte format or fixed-point math — the language is fully decoupled from the determinism contract. If instead the server re-canonicalizes to verify, you've re-introduced a parity surface. Design for verify-in-place.

## The trust-model nuance (worth being explicit about)
"Check the cheat over a trusted mechanism" via signatures proves **integrity + authenticity** (untampered, from this account) — but **not honesty**, because a modified client holds its own key and can sign well-formed lies. So a minimal server catches cheating through **cheap server-checkable invariants**, not re-simulation:
- ledger conservation (sum integer micros — trivial, language-agnostic),
- idempotency keys + monotonic counters/timestamps,
- ownership **state-machine legality** (`pool ⇄ owned`, referral, asylum-return),
- rate caps + statistical anomaly detection.

That's genuinely little compute — your instinct is sound. The parity concern isn't *deleted*, it's **deferred and scoped**: *if* you ever discover a cheat that can only be caught by re-deriving one specific outcome, that single routine is where sharing the Dart implementation would pay off. Cross that bridge only if it appears.

## So re-rank against your *remaining* two concerns
With parity mostly off the table, the deciders become **type-safety at the boundary** and **cold-start/scale-to-zero cost** — and on those two, Python is the *weakest* of the sensible options:

- **Go** — sharpest fit for exactly this: a small, statically-typed, fail-closed trust plane; tiny static binary → **millisecond cold starts and low memory**, which is precisely what scale-to-zero rewards. Directly answers #2 and #3. Cost: a third language, but the reimplementation is small (you verify bytes + read a handful of fields; you're *not* porting the sim engine).
- **Dart-AOT (e.g., dart_frog)** — lets you share the `psychemas` *schema types* for the fields the server parses, one language across the repo, AOT binary gives decent cold-start. Cost: smaller server/BaaS/observability ecosystem. Its unique edge (sharing sim math) is now low-value since you're not computing sim math.
- **Python + FastAPI/Pydantic** — best build speed, ecosystem, contributor pool; Pydantic v2 is *excellent* runtime fail-closed validation at a trust boundary (arguably the right primary defense for untrusted input). But **heaviest cold-start** on scale-to-zero and only runtime (not compile-time) type-safety. Defensible if familiarity + FastAPI velocity outweigh cold-start cost.

## My honest lean
Given your three concerns and the "minimal server" model: **Go is the cleanest match**, Dart-AOT second (repo cohesion + schema sharing), Python third. The decisive factor isn't performance-under-load (your traffic is near-zero) — it's **cold-start cost on scale-to-zero + static type-safety on the trust boundary**, and a compiled static binary wins both. Python's real advantages (ecosystem, ML-assisted moderation later, contributor velocity) are the counterweight — if those matter more to you than cold-start cost, Python stays reasonable.

Two things that would flip my lean back toward Python: (a) you expect **ML-assisted moderation** on the server soon, or (b) contributor familiarity with Python is a hard constraint.

And timing is on your side — src is still a skeleton, so this is the cheapest moment to change course. When you've decided, I'd capture it as a **superseding ADR** (referencing 0003), not a rewrite. Want me to sketch a decision matrix or draft that ADR when you're ready?
