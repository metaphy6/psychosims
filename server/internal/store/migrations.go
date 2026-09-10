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
		{
			Version:     6,
			Description: "scope deduplication and persist signed presence and memory class",
			Up: `
                -- Legacy v5 profiles predate card inventory. Grant only the same
                -- starter as first boot; preserve an explicit empty/revoked library.
                UPDATE profiles SET
                    payload = jsonb_set(jsonb_set(payload,'{owned_card_ids}','["open_question"]'::jsonb),'{version}',to_jsonb(version+1)),
                    version = version + 1,
                    updated_at = clock_timestamp()
                WHERE NOT (payload ? 'owned_card_ids');
                ALTER TABLE idempotency_keys DROP CONSTRAINT idempotency_keys_pkey;
                ALTER TABLE idempotency_keys ADD PRIMARY KEY(account_id, key);
                ALTER TABLE idempotency_keys ADD COLUMN request_hash BYTEA;
                ALTER TABLE presence ADD COLUMN suite_id TEXT NOT NULL DEFAULT '';
                ALTER TABLE presence ADD COLUMN signature BYTEA NOT NULL DEFAULT '';
                ALTER TABLE ownership_records ADD COLUMN memory_class TEXT NOT NULL DEFAULT 'stateless'
                    CHECK(memory_class IN ('stateless','social_chronic','persistent'));
                CREATE TABLE session_authorizations (
                    id TEXT PRIMARY KEY,
                    account_id TEXT NOT NULL REFERENCES accounts(id) ON DELETE CASCADE,
                    patient_id TEXT NOT NULL REFERENCES ownership_records(patient_id),
                    ownership_version INTEGER NOT NULL,
                    ruleset_version TEXT NOT NULL,
                    start_state_hash BYTEA NOT NULL,
                    expires_at TIMESTAMPTZ NOT NULL,
                    consumed_at TIMESTAMPTZ,
                    receipt_hash BYTEA,
                    receipt_bytes BYTEA,
                    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
                );
                CREATE UNIQUE INDEX session_authorizations_active_patient
                    ON session_authorizations(patient_id) WHERE consumed_at IS NULL;
            `,
			Down: `
                DROP TABLE session_authorizations;
                ALTER TABLE ownership_records DROP COLUMN memory_class;
                ALTER TABLE presence DROP COLUMN signature;
                ALTER TABLE presence DROP COLUMN suite_id;
                ALTER TABLE idempotency_keys DROP COLUMN request_hash;
                -- Fails atomically if different accounts now share a key; never discard data.
                ALTER TABLE idempotency_keys DROP CONSTRAINT idempotency_keys_pkey;
                ALTER TABLE idempotency_keys ADD PRIMARY KEY(key);
            `,
		},
		{
			Version:     7,
			Description: "durable provider identities auth sessions and key recovery",
			Up: `
                CREATE TABLE provider_identities (
                    provider TEXT NOT NULL CHECK(provider IN ('google','apple')),
                    subject TEXT NOT NULL CHECK(length(subject) BETWEEN 1 AND 255),
                    account_id TEXT NOT NULL REFERENCES accounts(id) ON DELETE CASCADE,
                    created_at TIMESTAMPTZ NOT NULL DEFAULT clock_timestamp(),
                    PRIMARY KEY(provider,subject)
                );
                CREATE TABLE auth_sessions (
                    id TEXT PRIMARY KEY,
                    account_id TEXT NOT NULL REFERENCES accounts(id) ON DELETE CASCADE,
                    issue_key TEXT NOT NULL,
                    role TEXT NOT NULL DEFAULT 'player',
                    initial_pair JSONB NOT NULL,
                    created_at TIMESTAMPTZ NOT NULL DEFAULT clock_timestamp(),
                    revoked_at TIMESTAMPTZ,
                    UNIQUE(account_id,issue_key)
                );
                CREATE TABLE refresh_tokens (
                    token_id TEXT PRIMARY KEY,
                    session_id TEXT NOT NULL REFERENCES auth_sessions(id) ON DELETE CASCADE,
                    token_digest BYTEA NOT NULL,
                    expires_at TIMESTAMPTZ NOT NULL,
                    consumed_key TEXT,
                    replacement_pair JSONB
                );
                CREATE TABLE oauth_states (
                    state TEXT PRIMARY KEY,
                    payload JSONB NOT NULL,
                    expires_at TIMESTAMPTZ NOT NULL
                );
                CREATE TABLE oauth_start_requests (
 operation_key TEXT PRIMARY KEY, request_hash BYTEA NOT NULL, state TEXT NOT NULL
);
CREATE TABLE oauth_exchange_results (
                    state TEXT PRIMARY KEY,
                    operation_key TEXT NOT NULL,
                    request_hash BYTEA NOT NULL,
                    account_id TEXT NOT NULL REFERENCES accounts(id) ON DELETE CASCADE
                );
                CREATE TABLE session_start_requests (
                    account_id TEXT NOT NULL REFERENCES accounts(id) ON DELETE CASCADE,
                    operation_key TEXT NOT NULL,
                    request_hash BYTEA NOT NULL,
                    response_payload JSONB NOT NULL,
                    PRIMARY KEY(account_id,operation_key)
                );
                ALTER TABLE device_keys ADD COLUMN replaces_key_id TEXT REFERENCES device_keys(id);
                CREATE TABLE device_key_requests (
                    account_id TEXT NOT NULL REFERENCES accounts(id) ON DELETE CASCADE,
                    operation_key TEXT NOT NULL,
                    request_hash BYTEA NOT NULL,
                    key_id TEXT NOT NULL REFERENCES device_keys(id),
                    PRIMARY KEY(account_id,operation_key)
                );
                CREATE UNIQUE INDEX device_keys_one_replacement ON device_keys(replaces_key_id) WHERE replaces_key_id IS NOT NULL;
            `,
			Down: `DROP TABLE device_key_requests; ALTER TABLE device_keys DROP COLUMN replaces_key_id; DROP TABLE session_start_requests; DROP TABLE oauth_exchange_results; DROP TABLE oauth_start_requests; DROP TABLE oauth_states; DROP TABLE refresh_tokens; DROP TABLE auth_sessions; DROP TABLE provider_identities;`,
		},
		maintenanceMigration(),
		outcomesMigration(),
	}
}
