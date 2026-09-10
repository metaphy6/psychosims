# 🧠 docs/tracking/context.md — shared project context pack

> **This file is the single place for project-specific overrides.**
> All vendor entry points (`CLAUDE.md`, `CONVENTIONS.md`,
> `.github/copilot-instructions.md`, etc.) are invited to reference this file
> so context stays in sync without editing every vendor file.

---

## Project identity

- **Name**: Psychosims
- **One-liner**: Fictional psychology-practice sim; on-device AI voices patients, a deterministic core owns outcomes, a small server owns trust.
- **Primary language**: Dart / Flutter (client); server runtime finalized in Phase 3.
- **Blueprint**: [`STARTER.md`](../../STARTER.md) (§1–§24).

## Key paths

| Concern | Path |
|---|---|
| Master rulebook | `AGENTS.md` |
| Project plan | `docs/planning/ROADMAP.md` |
| Tracking log | `docs/tracking/tracking.csv` |
| Skills library | `.agents/skills/` |
| Ops scripts | `xops/` |

## Active context (update as the project evolves)

The blueprint is audited and roadmapped. Next up is **Phase 0 — Foundations &
Conceptual Corrections** in [`ROADMAP.md`](../planning/ROADMAP.md): stand up the
monorepo structure, the centralized `config/` authority, and close the deferred
entry-gate decisions (device spec, model license, cost model, balance spec)
before any feature code.

## Project-specific conventions

- **Centralized configuration only** — no module reads raw env vars or hard-codes
  constants; everything flows through `config/` (Principle 1;
  [DESIGN-centralized-configuration](../design/DESIGN-centralized-configuration.md)).
- **Separation of concerns** — code lands in exactly one declared module per
  [`ARCHITECTURE.md`](../code/ARCHITECTURE.md); pure rules live in `core/`.
- **All balance constants are owned by the balance spec** (§9), loaded via config.
- **No dialogue transcripts persisted anywhere** — structured state/deltas only.

## Out-of-scope / do not touch

<!-- List directories, files, or systems agents should treat as read-only.
     E.g.: "Never edit vendor/ — it is a git subtree." -->

_None yet._

## External service dependencies

<!-- List services this project calls, with the env var that holds each key.
     Do NOT include actual keys here — only the var names. -->

| Service | Env var | Notes |
|---|---|---|
| (example) Stripe | `STRIPE_SECRET_KEY` | Sandbox only in dev |

## Agent quick-reference

```bash
make help           # all targets
make doctor         # sanity-check framework install
make git.dry        # preview pending commits (read-only)
make git            # commit + push (human runs this)
make track.add ACTION=note SUMMARY="..."   # append tracking row
make skills.find TAG=<tag>                 # search skill library
make skills.status                         # skill index with line counts
```
