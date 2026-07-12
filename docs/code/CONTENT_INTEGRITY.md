# Content integrity & untrusted-input safety

This document enforces the fictional-clinical taxonomy and the prompt-injection
defense contract across the whole content pipeline.

## No real clinical labels

Real DSM/ICD terms and real drug brands are **forbidden** in:

- `content/manifests/`
- Nine-axis synthesis fields (§12)
- Study-field definitions (§15)
- In-game encyclopedia entries (§15)

CI runs `scripts/content_integrity_check.sh` to catch violations.

## Fictional-taxonomy naming convention

Names must be **evocative, not alien**:

- Use familiar linguistic roots + plausible clinical or pharma suffixes.
- Avoid near-homophones of real trademarks or reskinned real labels.
- Maintain an explicit registry of approved roots and suffixes.

See `content/fictional_taxonomy.yaml` for the current registry.

## Untrusted-input / prompt-injection defense

Two channels carry attacker-controlled strings into the prompt:

1. Peer-authored case history (§17)
2. Community-authored manifests (§21)

Defense in depth:

- **Strict schema whitelisting**: enums and numbers over free text wherever possible.
- **Length caps and sanitization** applied server-side at signing time.
- **Template isolation**: untrusted strings are inserted into predefined slots
  and can never be interpreted as instructions.
- **No free-form player chat** ([DECISION 0002](../project/DECISION_LOG.md)).

## Disclaimer & fictional framing

Reserved presentation slots exist from day one:

- `disclaimers.fictional_simulation`
- `disclaimers.not_medical_advice`
- `disclaimers.entertainment_focus`

These are externalized in `app/lib/shared/l10n.dart` and finalized in Phase 7.5.
