# server/

> Authoritative server control plane for Psychosims.

This module owns identity, profiles/progression, receipt validation, ownership
arbitration, matchmaking, content signing, economy ledger, moderation, and
macro-event seeding.

## Runtime

Go 1.26+. See [`ADR-0006`](../docs/design/ADR-0006-server-runtime-go.md) for the
runtime decision (superseding ADR-0003). No third-party web framework is used;
the control plane is built on the standard library.

## Layout

- `go.mod` — module definition (`psychosims.dev/server`).
- `cmd/psy-server/` — the server entrypoint (`main`).
- `internal/server/` — authenticated HTTP composition, trusted catalog and reconciliation.
- `internal/schemas/` — Go structs mirroring the Dart `packages/psychemas/` contract.
- `internal/psylog/` — cross-stack structured logger (see [`docs/code/LOGGING.md`](../docs/code/LOGGING.md)).

## Run

```bash
go run ./cmd/psy-server   # from server/, with the local configuration below
```

The executable opens PostgreSQL, applies migrations and composes durable identity,
session-token, device-key, profile, authorization and receipt services. It listens
on `127.0.0.1:8080` by default and fails startup when required configuration is
missing. Set `PSY_DATABASE_DSN`, `PSY_TOKEN_SECRET_FILE` (a private `0600` file
containing at least 32 secret bytes), and at least one of `PSY_GOOGLE_CLIENT_ID`
or `PSY_APPLE_CLIENT_ID`. The stable token secret derives separate token, OAuth
state and case-seed keys. Keep that file outside version control.

`PSY_CATALOG_MANIFESTS` is a comma-separated list of existing manifest paths;
the default from `server/` is `../content/manifests/siege_brumosis.json`.
Checksums follow the shared manifest loader. Browser authorization additionally
uses explicitly registered `PSY_OAUTH_STEAM_REDIRECT_URI` or
`PSY_OAUTH_DIRECT_REDIRECT_URI` and, where required by the provider,
`PSY_GOOGLE_CLIENT_SECRET_FILE` / `PSY_APPLE_CLIENT_SECRET_FILE`. There is no
runtime fixture verifier, invented redirect, client account override or random
production signing-secret fallback. These settings do not register or deploy
anything with a provider.

## Develop

```bash
make server.build          # go build ./...
make server.test           # go test ./...
make server.lint           # go vet + gofmt check
make server.format         # gofmt -w
make server.certified      # actual local PostgreSQL certified reward/replay tests
```

See [`docs/code/ARCHITECTURE.md`](../docs/code/ARCHITECTURE.md) for the
trust-boundary contract and [`docs/code/SHARED_SCHEMAS.md`](../docs/code/SHARED_SCHEMAS.md)
for the Dart↔Go schema alignment discipline.

## Real PostgreSQL acceptance gate

From the repository root, run `server/scripts/postgres_test.sh`. It uses the
existing pinned PostgreSQL image (digest recorded in that script)
with `--pull=never`, creates a unique loopback-only disposable container and
removes it on exit. It runs all Go packages with `-race -tags=postgres`; the
PostgreSQL tests do not skip when the database is unavailable. A manually
supplied `PSY_TEST_DATABASE_DSN` must name a **disposable** database because the
tests truncate data, migrate down/up, and inject transaction failures.

The suite invokes successful `receipts.Service.Submit`, concurrent retries,
cross-account identical keys, cache expiry/replay, forced audit rollback,
first boot, presence signature round trips, memory-class enforcement and
concurrent/failed migrations. Component-only `make server.test` remains useful
but does not replace this gate.

The expanded gate covers concurrent first sign-in, durable token rotation and
revocation across reconstructed services, forced rotation/key-recovery rollback,
actual TLS JWKS and OAuth-code exchange fixtures, authenticated HTTP receipt
delivery and a built server executable's readiness/graceful shutdown.
`make server.integration` (`server/scripts/postgres_test.sh --flutter`) is the separate cross-stack gate:
it invokes `flutter test test_http/control_plane_http_test.dart` against its own
local Go HTTP server and disposable PostgreSQL database. Its provider adapter
exists only in the explicitly tagged test binary. Ordinary Go tests do not
silently skip a missing Flutter or database prerequisite. The gate runs isolated
held and certified 100-turn sessions, checks encrypted restart and receipt replay,
and independently checks the authoritative profile, cured ownership and balanced
XP/study/cash ledger. CI invokes this cross-stack gate explicitly.

## HTTP contracts and trust

The routes follow [NETWORKING.md](../docs/code/NETWORKING.md). Byte fields use
base64; receipt signatures cover the exact received bytes. Errors use `kind`,
`code`, `message` and `request_id`. Request identifiers are bounded to 128 ASCII
identifier characters; unsupported explicit API versions, unknown fields,
duplicate JSON keys, non-object bodies and unsupported compression fail closed.
IP throttling uses the socket peer and ignores untrusted forwarding headers.
Requests and dependency probes have deadlines; no bearer account is taken from
caller-populated context in the executable composition.

Auth responses contain `account_id`, `access_token`, `refresh_token`,
`token_type: "Bearer"`, and RFC3339 `access_expires_at` / `refresh_expires_at`.
All issued HTTP sessions have the server-selected player role. Refresh rotation
with the same old token and operation key returns its original pair; a different
key cannot consume that token again. Logout durably revokes the whole session,
including rotated tokens, and an identical logout retry remains successful.

Browser starts replay the same live state/nonce for the same operation key and
PKCE parameters; changed parameters or a consumed/expired start require a new
operation. Provider outages return a retryable 503 with sanitized diagnostics.
Browser exchanges bind the stored provider, registered redirect, nonce and S256
verifier. State consumption, identity resolution, session creation and replay
metadata commit together, so a lost successful HTTP response can be replayed
with the same state/code/verifier/operation key. If a provider consumes its
one-use code but its own response is lost before the local transaction commits,
the client must start a fresh authorization flow. Provider codes and raw tokens
are not persisted. Verification follows [Google's OIDC checks](https://developers.google.com/identity/openid-connect/openid-connect)
and [Apple's identity checks](https://developer.apple.com/documentation/signinwithapple/verifying-a-user),
using bounded HTTPS JWKS fetches, signature/issuer/audience/expiry/nonce validation
and exact configured token endpoints. Apple code redirects request no profile
scopes and use query response mode, as specified by [Apple’s other-platform
authorization contract](https://developer.apple.com/documentation/signinwithapple/incorporating-sign-in-with-apple-into-other-platforms).

Device enrollment returns its account-bound registry record. Explicit recovery
supplies `replaces_key_id` and atomically revokes that key with replacement.
`GET /v1/public-keys` currently publishes stable ETag/TTL revocation metadata;
its server verification-key list is empty until a server signing-key contract
is configured. Registry acceptance does not claim hardware-backed client custody.

Session starts accept only `case_id` and `card_ids`; the catalog and profile
supply the catalog `case_id`, manifest checksum, axes (whole values from 0 to 100), controller
defaults, positive seed, owned library and patient assignment. Start-operation
retries return the same permit even after receipt acceptance. Accepted receipts
return their ID/idempotency key, `status: "accepted"`, the original accepted
`profile_version`, `retryable: false` and the durable `reward_status`.
An unproven receipt remains `held_unproven`. A matching operator-certified
completion returns `certified`, or `certified_unrewarded` with a bounded policy
reason. Award fields are `xp_awarded`, `study_points_awarded` and
`cash_micros_awarded` (omitted means zero). Retries never recompute the verdict
from a later profile, catalog or policy.
Batch results classify transient failures as `retryable`, preserve ordered
per-item identities, and never advance the cursor beyond an unresolved prefix.
The client fetches boot after acceptance for full authoritative balances.

Interoperability fixtures are
[`signed_ed25519_v1.json`](../test_fixtures/receipts/signed_ed25519_v1.json)
(Dart producer) and
[`reconciliation.json`](internal/server/testdata/reconciliation.json)
(Go producer). Their tests verify exact signatures and wire structure.

## Authoritative session acceptance

`receipts.Service.Authorize` is a trusted routing seam: the caller selects the
case start from the server catalog and must already have an assigned, live
ownership lease. It checks the authoritative profile's `owned_card_ids` and
returns `{id, patient_id, ruleset_version, start_state, expires_at}`. Use its
`id` as receipt `id`; the existing receipt schema stays at `0.3.0`. Never expose
an endpoint that forwards a client's arbitrary start state into `Authorize`.

Acceptance locks and checks the account, profile, session authorization and
patient lease. Profile version, permanent consumed-session evidence,
account-scoped idempotency and audit commit together. Exact retries succeed
without another mutation, including after short-lived idempotency GC; altered
reuse fails. Server profile creation uses version zero as an explicit create
operation. Missing/legacy ownership memory classes fail closed to `stateless`.

Schema `0.3.0` alone does not prove terminal gameplay. The service rejects
client ledger mutations and retains no raw dialogue. Optional operator-pinned
Dart compiler outcomes certify a finite subset of exact starts and action/delta
sequences. Unmatched paths remain unproven even if the client reports success;
offline career awards are not server entitlement.

To enable a reviewed local certificate artifact, explicitly set
`PSY_OUTCOME_CATALOG_PATH` and `PSY_OUTCOME_CATALOG_SHA256` (raw lowercase SHA256
of the exact file, including its newline). The artifact comes from
`tools/compile_outcomes.dart`; the normal Dart gate verifies source/fixture
consistency with `--check`. `PSY_OUTCOME_REVOKED_PROOFS` is an optional comma-
separated list of raw proof SHA256 IDs. No client can supply a trusted artifact.
A missing path/pin leaves certification disabled; mismatched pins, unsupported
metadata, duplicate JSON keys, altered proof digests and incorrect actual
receipt/envelope sizes fail startup. Source hashes are provenance, not runtime
simulation or a signature; operator review of the pinned build is the trust root.

Session authorization selects the certified seed and exact permitted inventory
snapshot only when every required card is owned and the ordered loadout matches.
It stores certificate and artifact identity in the durable grant. Such permits
carry `reward_status: conditional_certified`, `certificate_id` and
`catalog_sha256`; they promise eligibility for the supported path, not a payout.
Acceptance rechecks the current pinned catalog and exact typed evidence inside
its transaction. A changed/withdrawn/revoked artifact cannot pay an outstanding
grant. Already accepted receipts keep their original verdict on restart/replay.

A certified cure derives rewards from bounded server configuration, writes paired
recipient/system-source ledger entries, updates the primitive profile, marks
ownership cured, and records once-per-account/case history atomically with the
receipt and audit. Cooldown, rolling-window count/amount caps, economy kill switch
and balance ceilings may withhold rewards while still recording the proven cure.
Default base rewards match current progression values (100 XP, 3 study points);
cash is zero. Explicit local engineering limits are five cures/500 XP/15 study
per rolling 24 hours and a one-minute minimum interval. They are not a tuned
full economy, difficulty scaling, collusion detector or proof of human play.

Configuration overrides: `PSY_CURE_XP`, `PSY_CURE_STUDY`,
`PSY_CURE_CASH_MICROS`, `PSY_CURE_MAX_PER_WINDOW`, `PSY_CURE_XP_PER_WINDOW`,
`PSY_CURE_STUDY_PER_WINDOW`, `PSY_CURE_CASH_PER_WINDOW`, `PSY_CURE_WINDOW` and
`PSY_CURE_MINIMUM_INTERVAL`. `PSY_ECONOMY_ENABLED=false` withholds new rewards.
Amounts, durations and aggregate limits are validated; no configuration can
broaden the 120-action/1,024-delta/131,072-canonical-byte protocol bounds.
The HTTP/base64 envelope and 524,288-byte batch budgets are separate.

Migration 6 backfills only legacy profiles that lack `owned_card_ids`, granting
`open_question` and bumping their profile version so boot caches refresh. An
explicit empty inventory remains empty. Authorization renewal invalidates
unconsumed grants whose owner, ownership version, or expiry is stale. Receipt
and grant writers use the same grant-before-ownership lock order. Expiry checks
read PostgreSQL's actual clock after ownership locks and again after receipt
writes; time spent waiting does not extend a lease. Every receipt rejection
attempts a separate audit append after rollback, recording a structured code
and receipt-byte hash without retaining raw rejected receipt fields.

Session start renews an expired lease only for the same account's owned catalog
instance with an unchanged memory class. Renewal advances its ownership version;
old unfinished grants become stale, while accepted receipt tombstones remain
available for exact replay. Terminal states and foreign ownership fail closed.

Private bearer verification reserves a peer-IP allowance before querying the
session store. Failed authentication consumes this allowance; successful checks
retain the separate account request budget. The failure gate holds at most 4096
peers and expires idle records after the configured window. Dependency outages
release admission without charging an authentication failure.

Durable receipts accept bounded ASCII identifiers (`A-Z`, `a-z`, `0-9`, `_`, `-`,
`.`, `:`, at most 128 bytes), known action/delta/controller enum values, bounded
start-state axes, and bounded card collections. Invalid receipt identifiers are
never echoed as batch item identifiers or cursors. Signature verification uses
exact received bytes and propagates the request context through key lookup;
accepted storage contains only the validated structured receipt projection.

`PSY_HTTP_MAX_IN_FLIGHT` defaults to 64 and accepts 1–4096. Executable HTTP
composition shares that admission counter across handlers, before bearer/SQL
work. Excess work returns 503 with Retry-After; `/health` remains available
because it performs no downstream work. Cancellation releases the reservation.
HTTP request counts, status counts and latency histograms use bounded metric
aggregates; request paths, query parameters and arbitrary methods are not logged.

`server/scripts/postgres_test.sh --load` runs the explicitly tagged local load,
saturation and executable cold-start gate against its own disposable database.
The [measurement protocol and results](../docs/reports/2026-09-10-local-control-plane-load.md)
state the thresholds and scope; this lightweight local pass does not establish
production capacity or a cloud SLO.
