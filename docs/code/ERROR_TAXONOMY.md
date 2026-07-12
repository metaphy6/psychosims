# Error taxonomy

Every failure in Psychosims is classified into exactly one of four buckets.
The bucket travels on the shared log schema (`error_kind`) and on any error
payload that crosses the trust boundary, so callers and operators know whether
to retry, apologize, or escalate.

## Buckets

| `error_kind` | Meaning | Example | Client action | Server action |
|--------------|---------|---------|---------------|---------------|
| `user` | The caller supplied invalid input or state. | Illegal action in current lifecycle phase. | Show a localized, actionable message; do not auto-retry. | Return `400` with a stable error code. |
| `system` | An internal bug or invariant violation. | Unexpected null, corrupt local state. | Log and degrade gracefully; prompt restart if needed. | Return `500`, page on-call, create audit entry. |
| `external` | A downstream dependency failed. | Model load failure, CDN timeout, database error. | Retry with backoff if idempotent; otherwise queue offline. | Return `502/503` with `Retry-After` when safe. |
| `offline` | The device has no usable network right now. | No connectivity, request timeout while offline. | Treat as first-class state, not an error; queue for replay. | N/A (request never arrived). |

## Offline is not an error

`offline` is a **state**, not a failure mode. The UI may show "playing locally"
and the transport layer queues mutating requests with idempotency keys. When
connectivity returns, queued requests replay in order.

## Stable error codes

User-facing errors carry a stable code (e.g. `lifecycle_invalid_transition`)
instead of free text, so the presentation layer can localize it and telemetry
can aggregate it. Codes are lower-case snake_case and scoped:

- `lifecycle_*` — patient/entity lifecycle violations
- `economy_*` — currency / inventory violations
- `auth_*` — identity / token issues
- `network_*` — transport failures mapped from external/offline
- `schema_*` — manifest/receipt validation failures
- `invariant_*` — system bugs (should never reach users)

## Mapping to HTTP status codes

| Bucket | Typical status | Retryable |
|--------|---------------|-----------|
| user | 400 / 409 / 422 | no |
| system | 500 | no |
| external | 502 / 503 / 504 | yes, with backoff |
| offline | none (client-local) | yes, on reconnect |

## Logging rule

All errors are logged with `error_kind`, `scope`, `event`, and `kv` containing
the stable error code. Raw stack traces or request bodies are redacted in
production.
