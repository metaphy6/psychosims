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

## W3 composition contract — planned implementation

These routes define the next local implementation slice. At the repair baseline
only `/health`, `/ready`, `/time` and `/v1/boot` exist; this table is not a claim
that authentication or receipt HTTP delivery is already implemented.

All JSON endpoints use `Psy-API-Version: v1` and
`Psy-Correlation-ID`. Mutations require `Psy-Idempotency-Key`. Except provider
sign-in, refresh and the browser authorization handshake, identity comes only
from the verified bearer token. The server chooses roles; a request body cannot
select an account or privileges. Errors use the existing `api.HTTPError` schema.

| Method and route | Request | Response / authority |
| --- | --- | --- |
| `POST /v1/auth/id-token` | Provider, ID token, nonce | Verified provider identity; access/refresh pair and account ID. Test verifiers are dependency-injected and never a default production fallback. |
| `POST /v1/auth/refresh` | Refresh token | Atomically rotated access/refresh pair; replay rejected. |
| `POST /v1/auth/logout` | Authenticated session | Durable revocation; retries succeed idempotently. |
| `POST /v1/auth/link` | Current session plus second provider proof and nonce | Atomically links a verified identity; an identity linked elsewhere is a conflict. |
| `POST /v1/auth/start` | Provider, registered channel/redirect, S256 challenge | Expiring one-use state and provider authorization URL. |
| `POST /v1/auth/exchange` | State, provider code, PKCE verifier | Server exchanges the code with the stored provider/redirect before issuing the pair; an ID token cannot masquerade as a code. |
| `POST /v1/device-keys` | Public key, supported suite and provisioning metadata | Account-bound public certificate; no private key upload. |
| `POST /v1/device-keys/recover` | Authenticated replacement key and recovery metadata | Atomic replacement/revocation under the existing device policy. |
| `GET /v1/boot` | Bearer token, optional `If-None-Match` | Existing profile response/ETag or `304`. |
| `POST /v1/sessions` | Requested eligible catalog case and equipped card IDs | Existing authorization shape `{id,patient_id,ruleset_version,start_state,expires_at}` plus explicit reward eligibility. Catalog/profile supply all seeds, axes, ownership and budgets. |
| `POST /v1/receipts` | Signed envelope | Receipt verdict and authoritative profile version/reward status; successful acceptance is durable before acknowledgment. |
| `POST /v1/receipts/batch` | Existing `BatchRequest` with at most 64 envelopes | Existing ordered `BatchResponse` item results and queue hint; transient failures remain retryable and cannot be acknowledged past by the client. |
| `GET /v1/public-keys` | Cache validators | Versioned public verification keys and revocation metadata, with ETag/TTL. |

Wire byte fields use standard base64 strings; legacy integer-array decoding can
remain for compatibility, but new writers use one representation. Signed receipt
bytes are never parsed and reserialized before signature verification. Shared
Dart→Go HTTP and Go→Dart fixtures must cover the envelope representation, typed
receipt fields and batch results. Account/role/private-key values never come
from unsigned receipt or envelope metadata.

The initial finite reward path is implemented under
[ADR-0009](../design/ADR-0009-bounded-authoritative-derivation.md). Permits expose
conditional certification; acceptance reports certified awards, a bounded
withholding reason or an unproven result. Real Dart/Go/PostgreSQL gates cover
fresh starter inventory, signed submission, encrypted restart, stable single/
batch replay and balanced authoritative rewards. General gameplay coverage and
the full social economy retain their later roadmap gates.
Provider JWKS/code exchange and secure storage use local fixture
adapters in integration tests; live provider registrations, physical platform
custody and cloud deployment remain separately pending.
