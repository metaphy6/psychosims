# Networking & offline-first transport conventions

All remote calls go through one typed API-client seam; no feature hand-rolls HTTP.

## API-client seam

- Location: `app/lib/shared/api_client.dart`.
- Bound to the shared schemas (`packages/psychemas/`).
- Auth token is read from secure storage (Phase 0.6) and refreshed transparently.
- Every mutating request carries an idempotency key (`rcp_<ulid>` from
  [IDENTIFIERS.md](IDENTIFIERS.md)).

## Resilience policy

For every remote call:

| Concern | Rule |
|---------|------|
| Timeout | 10 s for reads, 30 s for mutating requests. |
| Backoff | Bounded exponential: 1 s, 2 s, 4 s, 8 s + full jitter. |
| Idempotent retry | Safe for GET and mutating requests with idempotency key. |
| Rate limit | Honor `429` + `Retry-After`; back off and retry once. |
| Offline | Degrade to offline-first; queue mutating requests for replay. |

## Offline as first-class state

- Connectivity is detected before each request.
- Mutating requests are queued with their idempotency key and replayed in order.
- Reads return cached data when offline, with a staleness marker.
- Reconciliation on reconnect is idempotent and ordered.

## Large-asset fetch

Used for the ~1.8 GB model download and signed manifest delivery:

- Resumable chunked fetch.
- Signature/checksum verification before load.
- Metered/cellular connection posture: defer unless on Wi-Fi and user confirms.
- Progress events feed the shared logger, not raw UI prints.

## Server contract

- The server returns structured errors with `error_kind` and stable codes.
- The client maps `error_kind` to the taxonomy in [ERROR_TAXONOMY.md](ERROR_TAXONOMY.md).
