# Phase 3.7 Migration Runbook

## Pre-conditions

- Phase 2 services are stable and `make verify` passes.
- Target DB user has `CREATE`, `ALTER`, `INDEX`, and `USAGE` permissions.
- Backup of the existing SQL store is complete and a restore test succeeded.

## Schema migrations

Use forward-only, backward-compatible migrations:

1. Add new Phase 3 tables (`device_keys`, `revocation_list`, `ownership_leases`,
   `audit_chain`, `ledger`, `rulesets`, `flags`) alongside Phase 2 tables.
2. Add nullable columns; backfill with default values before enforcing `NOT NULL`.
3. Create indexes after the initial bulk load or when the table is small.
4. Validate with `server/scripts/migrate_test.sh` against a staging copy.

## Service cutover

1. Deploy the new binary in canary (5%).
2. Monitor `/ready`, validation latency, 5xx rate, and dead-letter queue depth.
3. Promote to 50%, then 100% over at least 30 minutes.
4. Keep the previous image version available for instant rollback.

## Rollback

- If error rate exceeds 1% or `/ready` stays unhealthy for > 60 s, rollback the
  image tag.
- Do not run reverse migrations unless a schema contraction step has already been
  applied and verified safe.

## Verification

Run the Phase 3 showcase scripts:

```bash
make showcase.phase3
```

Then run the final mechanical gate:

```bash
cd /home/tech/code/psychosims/server && go test ./... && go vet ./...
make verify
```
