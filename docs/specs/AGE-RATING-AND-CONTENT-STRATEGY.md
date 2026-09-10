# 🔞 C-6 — Age-rating & content strategy

> **Closes register item C-6** ([ROADMAP](../planning/ROADMAP.md#-conceptual-corrections-register)).
> §8 schedules this: the manipulate-a-patient-into-derangement loop (§16) will be
> read harshly by store reviewers and press. Direction is set now; finalized before
> submission (Phase 7.5). Section refs (§N) → [`STARTER.md`](../design/STARTER.md).

- **Status:** direction set (finalized in Phase 7.5)
- **Owner:** @maintainer
- **Consumed by:** Phase 4.2 (content generation tone), Phase 7.2 (SKU/store text), Phase 7.5 (final rating)

## Position (the frame everything inherits)

Psychosims is a **fictional, interactive simulation — not therapy, not medical
treatment** (§8). All clinical content is invented (no DSM/ICD labels, no real
drug brands). Store metadata, marketing, and in-app text use game language
("simulation," "scenario," "narrative experience"), never clinical guidance.

## Target rating band

Aim for a **mature band**: **ESRB Mature 17+**, **PEGI 16/18**, **IARC/Google
"Mature 17+"**, **Apple 17+**. The Manipulative-card mechanic and psychological
themes make a teen rating unrealistic and risky. Rating is confirmed via each
store's questionnaire at submission (Phase 7.5).

## Manipulative-card tone guidelines (the load-bearing rule)

Manipulative cards (§16) are the mechanic reviewers will scrutinize. They must
read as **a clinical gamble with consequences**, never as gratuitous cruelty:

- **Framing:** coercive *insight under pressure* — a high-risk therapeutic
  technique with a real downside — not abuse for its own sake.
- **Consequences are visible and costly:** derangement, walkouts, reputation
  loss, and audit exposure (§16, §17, §22) are the designed price; the game does
  not reward sadism (deliberate severity-farming is penalized, §17).
- **No real-world instructional content:** nothing that reads as a how-to for
  manipulating real people; the fiction stays inside the invented taxonomy.
- **Language:** clinical/strategic register, not degrading or sexualized.
- **Derangement depiction:** stylized (the §20 ink-wash fracture), not graphic
  self-harm or realistic medical distress.

## Content boundaries

- **Fictional taxonomy, enforced pipeline-wide** (§8): validated at content
  generation (Phase 4.2/4.3) and at UGC signing (Phase 6.4).
- **No real health data collected or stored;** PII kept separate from gameplay
  data (§8) — see the profile schema (§3).
- **Disclaimers** ("This game is a fictional simulation and not a substitute for
  professional mental health care") shown at onboarding + in the about screen.
- **UGC** inherits these tone rules; the moderation gate ([C-10](UGC-MODERATION-SLA.md)) enforces them.

## Store-review readiness checklist (finalized Phase 7.5)

- [ ] Rating questionnaires completed per store (ESRB/PEGI/IARC/Apple).
- [ ] Manipulative-card tone guidelines applied to all shipped + generated content.
- [ ] Disclaimers present at onboarding, about screen, and store listing.
- [ ] Store metadata/screenshots use entertainment language, no clinical claims.
- [ ] A reviewer-facing note explaining the fictional framing + consequence model.

## Open (resolved at Phase 7.5)

- Exact rating per store (questionnaire output).
- Whether any regional market needs a stricter cut or is excluded.
- Marketing tone guidelines for trailers/press (same "clinical gamble, not cruelty" frame).
