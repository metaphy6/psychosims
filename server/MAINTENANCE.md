# Local retention and account erasure

`cmd/psy-maintenance` is an explicit local operator tool. It has no HTTP route,
scheduler, deployment hook, or production execution in this slice. It defaults
to a read-only preview and requires an already migrated database at version 8 or
later. It does not apply migrations, even in preview mode. It accepts only an
explicit loopback PostgreSQL URL in `PSY_MAINTENANCE_DATABASE_DSN`; credentials
and database errors are omitted from its structured diagnostics.

From `server/`, with that environment variable supplied securely:

```bash
go run ./cmd/psy-maintenance gc
go run ./cmd/psy-maintenance gc --apply --batch-size=250
go run ./cmd/psy-maintenance erase-account --account=account_identifier
go run ./cmd/psy-maintenance erase-account --account=account_identifier \
  --journal-dir=/path/to/private/erasure-journal --apply
```

The journal path is chosen by the operator and must be preserved independently
of database backups. These commands are examples, not instructions to erase a
real account during development. Tests use disposable databases and temporary
journals only.

## Engineering retention defaults

These settings implement bounded cleanup; they are not a legal retention policy
or a claim of compliance. The existing phase-3 policy's audit/archive timelines,
account-request workflow, and legal review remain separate work.

| Data | Current treatment |
| --- | --- |
| Expired OAuth state and start responses | Delete after actual expiry plus the retry grace; old starts cannot produce authority without a fresh provider verification. |
| Refresh records and replacement claims | Delete only after both the original and any replacement tokens expire, plus the grace. Live rotation/retry results survive. |
| Initial auth-session claims | Compact to an empty object only after their tokens expire, the grace elapses, and all refresh rows are gone. Keep the revoked session and issue-key marker until account erasure. |
| Session-start responses | Clear the expired payload after the grace; keep its request hash and retired operation-key marker. The same operation cannot issue another authorization. |
| Expired, unused session authorization | Delete after the grace. Its session-start operation marker remains. |
| Accepted structured receipt projection | Clear after 90 days; keep the original signed-byte hash, accepted authorization identity, verdict, and financial history. |
| Expired receipt response cache | Delete after expiry plus the grace. The permanent accepted authorization/hash still prevents a second acceptance. |
| OAuth exchange and device operation markers | Keep minimal replay metadata until account erasure. |
| Device keys | No periodic deletion yet: removing revoked-key fingerprints without a replacement rejection protocol could permit re-enrollment. |
| Ledger, certified-cure records, audit and erasure markers | Preserve; no automatic time-based deletion in this slice. |

The grace defaults to 24 hours (`--retry-grace`, allowed 1 hour–30 days).
Receipt projection retention is configurable from 1–365 days
(`--receipt-retention`, default `2160h`). Cleanup follows actual refresh-token
expiry, which can exceed 24 hours; it does not apply the older policy's
incompatible blanket 24-hour token TTL.

Each invocation selects at most `--batch-size` candidates per data class
(default 250, maximum 1000), skips locked candidates/accounts, and commits all
cleanup plus one aggregate audit record in a transaction. A backlog requires
repeated explicit invocations. The whole command has a 30-second deadline,
configurable from 1 second to 5 minutes. Preview counts show bounded current
eligibility; concurrent work and dependencies between cleanup classes can
change the eventual counts. An error rolls back that invocation and reports
`applied: false`.

An `account_legal_holds` row excludes the account's associated records from
cleanup and refuses erasure. Account locks serialize incoming holds with cleanup
and erasure. The hold table is an engineering enforcement mechanism; granting
or removing a legal hold is not exposed as a user API here.

## Erasure and restore protocol

Erasure removes provider links, profile, presence, auth/refresh sessions, device
public keys and account operation responses. It records unlinked revoked key
IDs for the existing revocation feed, clears accepted receipt projection bytes,
deletes unused authorizations, and archives nonterminal ownership records with
a new ownership version. Terminal ownership tombstones remain terminal.

The account identifier, accepted receipt hash/verdict, ledger/snapshots,
certified-cure history, and immutable audit remain pseudonymous and linkable;
they are **not anonymous**. An immutable account fence rejects subsequent
authority writes, including writes already waiting when erasure commits.
Erasure is transactional and idempotent; deadlock/serialization conflicts are
retried at most three times within the command deadline. No raw dialogue is
written to the erasure audit or journal.

Before applying erasure, the command writes and fsyncs a private journal intent
and every ancestor directory up to the filesystem root, including when reusing
an existing intent. A failed durability barrier refuses the database operation.
The intent contains only the account identifier, schema
version, and deterministic erasure operation ID. The directory must be private
(`0700`), files private (`0600`), and records must pass strict schema/size checks.
Malformed, partial or symlinked records, duplicate fields and case aliases fail
closed. Only the three exact schema field names are allowed. Existing valid intents are
reused. The journal must be independently backed up and kept at least as long as
any database backup that could restore prior authority.

Restore an older database into an isolated local target, keep it unavailable to
clients, migrate it to the current schema, and reapply **every** preserved
journal partition before considering it usable:

```bash
go run ./cmd/psy-maintenance reapply-erasures --journal-dir=/private/journal
go run ./cmd/psy-maintenance reapply-erasures --journal-dir=/private/journal --apply
```

The command validates at most 1000 records per directory (`--limit` can lower
this bound) and rejects overflow without partial loading. Larger journals need
separate complete partitions, all replayed before traffic. Replay is per-account
transactional, stops on the first failure, and reports completed/total counts;
repeat the same partition after repairing the cause. An account absent from an
older backup receives a minimal erasure fence. Automatic deployment admission,
remote backup lifecycle, client cache/OS-key deletion, consent handling and
history-feed orchestration remain outside this local operator tool.

## Acceptance gates

`server/scripts/postgres_test.sh` from the repository root runs actual PostgreSQL
tests with the race detector: accepted receipt replay after compaction, live
refresh replay, retired start rejection, rollback, legal holds, bounded batches,
waiting-write erasure fencing, and the built local command.

`scripts/local_restore_drill.sh` additionally performs a real `pg_dump` and
`pg_restore` of a database taken before erasure. The test first demonstrates
that the old backup contains usable old authority, then reapplies the separate
journal and verifies access/refresh/key revocation, accepted-hash retention,
unchanged ledger sum, and a valid audit chain. It creates and removes only its
own disposable local container/databases. This demonstrates local restore
correctness, not a production recovery-time objective.
