package store

// Migrations returns the ordered schema migrations for the authoritative store.
//
// Every migration is backward-compatible (expand-then-contract) so a rolling
// deploy never breaks an in-flight older instance. Each migration includes a
// Down script for rollback.
func Migrations() []Migration {
	return []Migration{
		{
			Version:     1,
			Description: "create idempotency_keys table",
			Up: `
				CREATE TABLE idempotency_keys (
					key TEXT PRIMARY KEY,
					account_id TEXT NOT NULL,
					response_hash BYTEA,
					created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
					expires_at TIMESTAMPTZ NOT NULL DEFAULT NOW() + INTERVAL '24 hours'
				);
				CREATE INDEX idx_idempotency_keys_expires_at ON idempotency_keys(expires_at);
			`,
			Down: `
				DROP INDEX IF EXISTS idx_idempotency_keys_expires_at;
				DROP TABLE IF EXISTS idempotency_keys;
			`,
		},
		{
			Version:     2,
			Description: "create accounts and profiles tables",
			Up: `
				CREATE TABLE accounts (
					id TEXT PRIMARY KEY,
					created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
					updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
				);
				CREATE TABLE profiles (
					account_id TEXT PRIMARY KEY REFERENCES accounts(id) ON DELETE CASCADE,
					version INTEGER NOT NULL DEFAULT 1,
					payload JSONB NOT NULL,
					updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
				);
			`,
			Down: `
				DROP TABLE IF EXISTS profiles;
				DROP TABLE IF EXISTS accounts;
			`,
		},
		{
			Version:     3,
			Description: "create ledger tables",
			Up: `
				CREATE TABLE ledger_events (
					id BIGSERIAL PRIMARY KEY,
					account_id TEXT NOT NULL REFERENCES accounts(id) ON DELETE CASCADE,
					idempotency_key TEXT NOT NULL,
					kind TEXT NOT NULL,
					currency TEXT NOT NULL,
					amount_micros BIGINT NOT NULL,
					reason_key TEXT NOT NULL,
					server_time TIMESTAMPTZ NOT NULL DEFAULT NOW(),
					UNIQUE(account_id, idempotency_key)
				);
				CREATE INDEX idx_ledger_events_account_id ON ledger_events(account_id, server_time);
				CREATE TABLE ledger_snapshots (
					account_id TEXT PRIMARY KEY REFERENCES accounts(id) ON DELETE CASCADE,
					version INTEGER NOT NULL,
					balances JSONB NOT NULL,
					snapshot_time TIMESTAMPTZ NOT NULL DEFAULT NOW()
				);
			`,
			Down: `
				DROP TABLE IF EXISTS ledger_snapshots;
				DROP TABLE IF EXISTS ledger_events;
			`,
		},
		{
			Version:     4,
			Description: "create ownership and audit tables",
			Up: `
				CREATE TABLE ownership_records (
					patient_id TEXT PRIMARY KEY,
					account_id TEXT NOT NULL REFERENCES accounts(id) ON DELETE CASCADE,
					state TEXT NOT NULL,
					version INTEGER NOT NULL DEFAULT 1,
					lease_expires_at TIMESTAMPTZ,
					updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
				);
				CREATE INDEX idx_ownership_records_account_id ON ownership_records(account_id);
				CREATE TABLE audit_log (
					id BIGSERIAL PRIMARY KEY,
					account_id TEXT NOT NULL,
					correlation_id TEXT NOT NULL,
					action TEXT NOT NULL,
					entity_type TEXT NOT NULL,
					entity_id TEXT NOT NULL,
					outcome TEXT NOT NULL,
					prev_hash BYTEA NOT NULL,
					row_hash BYTEA NOT NULL,
					server_time TIMESTAMPTZ NOT NULL DEFAULT NOW()
				);
				CREATE INDEX idx_audit_log_account_id ON audit_log(account_id, server_time);
			`,
			Down: `
				DROP TABLE IF EXISTS audit_log;
				DROP TABLE IF EXISTS ownership_records;
			`,
		},
		{
			Version:     5,
			Description: "create device keys and presence tables",
			Up: `
				CREATE TABLE device_keys (
					id TEXT PRIMARY KEY,
					account_id TEXT NOT NULL REFERENCES accounts(id) ON DELETE CASCADE,
					public_key BYTEA NOT NULL,
					suite_id TEXT NOT NULL,
					revoked_at TIMESTAMPTZ,
					created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
					UNIQUE(account_id, public_key)
				);
				CREATE INDEX idx_device_keys_account_id ON device_keys(account_id);
				CREATE TABLE presence (
					account_id TEXT PRIMARY KEY REFERENCES accounts(id) ON DELETE CASCADE,
					status TEXT NOT NULL,
					last_seen TIMESTAMPTZ NOT NULL DEFAULT NOW(),
					etag TEXT NOT NULL DEFAULT ''
				);
			`,
			Down: `
				DROP TABLE IF EXISTS presence;
				DROP TABLE IF EXISTS device_keys;
			`,
		},
	}
}
