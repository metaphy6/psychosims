# Config precedence & typed bounds

> How the effective configuration is resolved and what guarantees hold.

## Precedence (highest wins)

1. **Runtime flags** — passed directly to `loadConfig` (e.g., `environment`).
2. **Secret refs** — values pulled from the runtime environment by variable name.
3. **Environment overlay** — `dev`, `staging`, `prod`, `test` layers over base.
4. **Base schema** — typed defaults and shape validation.

A value is only overridden when the higher layer provides a non-empty / non-zero
value. Empty strings, zero ints, and 0.0 doubles fall through to the next layer.

## Typed numeric bounds

Every numeric field has a documented range enforced by `validateConfig` at
startup:

| Group | Field | Bounds |
|---|---|---|
| network | connectTimeoutMillis | > 0 |
| network | receiveTimeoutMillis | > 0 |
| model | nCtx | > 0 |
| model | nBatch | > 0, ≤ nCtx |
| promptBudget | maxInputTokens | > 0 |
| promptBudget | maxOutputTokens | > 0 |
| promptBudget | maxInputTokens + maxOutputTokens | ≤ nCtx |
| balance | activeCardSlots | > 0 |
| balance | misfortuneRollPercent | [0, 100] |
| balance | doubtTransferBasePercent | [0, 100] |
| balance | discountPracticeXpPenaltyPercent | [0, 100] |
| balance | ownershipLeaseTtlHours | > 0 |
| balance | rulesetVersionSunsetDays | > 0 |

Out-of-range values fail fast at startup with a clear `ConfigValidationException`.

## Secret handling

Secrets are referenced by name only. The `Config` object stores only the
reference name. `safeConfig()` redacts the reference before logging.
