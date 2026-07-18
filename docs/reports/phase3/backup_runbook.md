# Phase 3.2 Backup / Point-in-Time Recovery Runbook

**Scope:** authoritative profile + ledger store (managed Postgres).
**Target RPO:** ≤ 1 hour. **Target RTO:** ≤ 4 hours.

## Managed-Postgres PITR

1. Enable automated backups on the managed Postgres instance with a retention
   window of at least 7 days and a backup window outside peak play hours.
2. Enable point-in-time recovery (PITR / WAL archiving) so the database can be
   restored to any second within the retention window.
3. Store logical dumps (`pg_dump`) daily to object storage in a different
   availability zone / region for disaster recovery.

## Restore drill

1. Identify the last known good transaction time before the incident.
2. Create a new managed Postgres instance from the latest snapshot + WAL replay
   to the chosen PITR target.
3. Validate the new instance:
   - `SELECT` a sample of profile rows and ledger snapshots.
   - Replay ledger events for a sample account and confirm balances match the
     snapshot.
   - Run `go test ./...` against the restored instance.
4. Update the application DSN (by reference, never by value) to point to the
   restored instance.
5. Keep the old instance for 24 h before deletion in case rollback is needed.

## Erasure notes

Erasure requests (`profile.Repository.Erase`) zero the mutable profile snapshot
but **do not delete ledger events**. The ledger remains conservation-valid and
continues to reference only the pseudonymous account id.

## Automation status

The PITR interface and manual drill are in place. Automated backup cadence,
off-site copy encryption, and scheduled DR drills are tagged for the Phase 7.6
security hardening pass.
