# Local database recovery evidence — 2026-09-10

The actual PostgreSQL logical-backup drill passed. A fresh service built from
the restored database retained its profile, device signing key, audit chain,
receipt authorization and deduplication records. Replaying the same signed
receipt left the profile and audit counts unchanged. Active sessions remained
valid, revoked access and refresh tokens stayed rejected, and an incorrect
external runtime signing secret could not validate a restored token.

This verifies recovery of a small synthetic fixture on this Linux development
host. It does not establish production RPO/RTO, point-in-time recovery, cloud
backup custody, large-database throughput or certified payout recovery. The
original replay fixture exercises an unproven receipt; the later erasure drill
also checks preservation of a synthetic ledger balance.

## Reproduce

Run `make server.restore` after the pinned PostgreSQL image is locally available.
The command starts its own temporary local container, creates separate source and
restore databases, runs the Go integration test with the race detector, and
removes only its own container and temporary files. It never chooses an existing
database from the environment. Missing Docker/image/Go prerequisites fail the
gate. No cloud connection, deployment or release is involved.

- Script: [local_restore_drill.sh](../../scripts/local_restore_drill.sh).
- Assertions: [backup_restore_test.go](../../server/internal/integration/backup_restore_test.go).
- Image: `postgres@sha256:20edbde7749f822887a1a022ad526fde0a47d6b2be9a8364433605cf65099416`.
- Source command: `go test -race -tags=postgres,restore -count=1 -run '^TestPostgresLogicalBackupRestore' -v ./internal/integration`.

## Observed result

Run `local-restore-drill--20260910T120510Z-786876`, exit 0:

| Observation | Result |
| --- | ---: |
| Custom-format backup bytes | 36,216 |
| Dump duration | 93 ms |
| Restore duration | 84 ms |
| Post-restore assertions | 10 ms |
| Recovered audit-chain rows | 1 |
| Receipt replay protection | Passed |
| Access and refresh revocation | Passed |

The backup SHA-256 was
`d5604d3a97724d0b105b8a5ff9bd47e353eb75740f3a3f11842cab17bfd49115`.
The checksum is checked again after writing and reading the private temporary
backup. This is corruption detection, not a backup signature. Database contents
and generated fixture keys vary between runs; the hash is evidence for this run,
not a promised reproducible database dump.

The database backup deliberately excludes the runtime token-signing secret.
Recovering real sessions requires separately protected recovery of that secret.
Production encryption, off-host storage, retention, restore scheduling, larger
fixtures and point-in-time recovery remain deployment-readiness work.

## Erasure journal recovery

The expanded run `privacy-restore-drill--20260910T132114Z-1085478`, exit 0,
passed both the original recovery test and
[privacy_restore_test.go](../../server/internal/integration/privacy_restore_test.go).
The latter created a 54,899-byte pre-erasure dump, erased the source account,
restored the old dump into a separate database and first demonstrated that its
old bearer authority worked. Reapplying the independently retained, fsynced
erasure journal then rejected access and refresh tokens and device keys,
removed the profile and provider links, and preserved the accepted receipt hash,
valid audit chain and synthetic ledger sum of 7.

This makes the restore ordering observable: a restored database stays isolated
until every retained journal partition has been applied successfully. The
journal is outside the database dump and must survive at least as long as any
backup that could restore earlier authority. See the implemented local
[maintenance procedure](../../server/MAINTENANCE.md) for limits, dry runs,
legal holds and the exact data retained. Client erasure, production custody and
legal policy approval remain separate acceptance work.
