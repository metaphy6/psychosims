# Identifier & idempotency-key strategy

All identifiers in Psychosims follow one documented scheme so that deduplication,
provenance, and privacy properties are predictable across the stack.

## Principles

- **Collision-resistant** — use 128-bit random or time-ordered entropy.
- **Non-PII** — IDs must not encode emails, names, or device serials.
- **Non-enumerable** — sequential counters are forbidden in public contexts.
- **URL-safe** — base32 or base64url, no spaces or ambiguous characters.
- **Sortable when useful** — receipt idempotency keys are lexicographically
  sortable to simplify replay ordering.

## ID types

| Type | Format | Generator | Example | Notes |
|------|--------|-----------|---------|-------|
| Session / correlation id | `sess_<ulid>` | ULID (Crockford base32) | `sess_01J3KQ...` | Bound to one play session; crosses client→server→receipt logs. |
| Receipt idempotency key | `rcp_<ulid>` | ULID, client-generated | `rcp_01J3KQ...` | Client mints before sending; server dedupes on this key. |
| Entity id (patient, item, ...) | `ent_<uuid-v7>` | UUIDv7 | `ent_018f...` | Time-ordered, database-friendly, no PII. |
| Pseudonymous therapist id | `dr_<uuid-v4>` | UUIDv4 | `dr_a1b2...` | Therapist-facing public handle; unlinkable to account id. |
| Account id | `acct_<uuid-v7>` | UUIDv7 | `acct_018f...` | Server-authoritative; never exposed in manifests. |
| Content version / manifest id | `man_<sha256-8>` | 8-char content hash | `man_a3f9...` | Immutable content addressing. |

## ULID vs UUIDv7

- **ULID** is used when lexicographic sort order is operationally useful
  (receipt queue replay, log tailing).
- **UUIDv7** is used when database primary-key performance matters (entity and
  account rows).
- Both are 128-bit and URL-safe.

## Receipt idempotency keys

- The client generates `rcp_` keys before any network attempt.
- The key travels in the request and is stored by the server as a unique index.
- A retry with the same key returns the previously computed result; a new key is
  treated as a new request.
- Keys are never reused across different logical operations.

## Pseudonymity rule

The ledger and manifests store pseudonymous IDs only. Mapping to real account
IDs lives in the server’s identity service and is out of scope for public
schemas. See [`DATA-LIFECYCLE.md`](../project/DATA-LIFECYCLE.md) for erasure.

## Implementation homes

| Stack | Location |
|-------|----------|
| Dart | `packages/psycore/lib/src/identifiers.dart` (planned) / `app/lib/shared/` |
| Python | `server/src/psychosims_server/identifiers.py` (planned) |

For Phase 0 the scheme is documented here; generators are implemented when the
first receipt/entity flow is built in Phase 3.
