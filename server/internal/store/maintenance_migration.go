package store

import "strings"

// These guards serialize authority writes with an account's erasure fence.
// Audit rows intentionally remain appendable and immutable history is retained.
var guardedAccountTables = []string{"profiles", "ledger_events", "ledger_snapshots", "ownership_records", "device_keys", "presence", "provider_identities", "auth_sessions", "oauth_exchange_results", "session_start_requests", "device_key_requests", "session_authorizations", "idempotency_keys", "account_legal_holds"}

func maintenanceMigration() Migration {
	up := `
ALTER TABLE auth_sessions ADD COLUMN retired_at TIMESTAMPTZ;
ALTER TABLE session_start_requests ADD COLUMN retired_at TIMESTAMPTZ;
ALTER TABLE session_start_requests ALTER COLUMN response_payload DROP NOT NULL;
ALTER TABLE oauth_start_requests ADD COLUMN created_at TIMESTAMPTZ NOT NULL DEFAULT clock_timestamp();
CREATE INDEX auth_sessions_retention ON auth_sessions(created_at) WHERE retired_at IS NULL;
CREATE INDEX refresh_tokens_retention ON refresh_tokens(expires_at);
CREATE INDEX refresh_tokens_session_expiry ON refresh_tokens(session_id,expires_at);
CREATE INDEX oauth_states_retention ON oauth_states(expires_at);
CREATE INDEX oauth_start_retention ON oauth_start_requests(created_at);
CREATE INDEX session_authorizations_retention ON session_authorizations(consumed_at) WHERE receipt_bytes IS NOT NULL;
CREATE INDEX session_authorizations_expired ON session_authorizations(expires_at) WHERE consumed_at IS NULL;
CREATE TABLE account_legal_holds (
 account_id TEXT PRIMARY KEY REFERENCES accounts(id) ON DELETE CASCADE,
 created_at TIMESTAMPTZ NOT NULL DEFAULT clock_timestamp()
);
CREATE TABLE account_erasures (
 account_id TEXT PRIMARY KEY REFERENCES accounts(id) ON DELETE CASCADE,
 erasure_id TEXT NOT NULL UNIQUE,
 erased_at TIMESTAMPTZ NOT NULL DEFAULT clock_timestamp()
);
CREATE TABLE revoked_device_keys (
 key_id TEXT PRIMARY KEY,
 revoked_at TIMESTAMPTZ NOT NULL
);
CREATE FUNCTION require_active_account() RETURNS trigger LANGUAGE plpgsql AS $$
DECLARE target TEXT; locked TEXT;
BEGIN
 target := to_jsonb(NEW)->>'account_id';
 IF TG_TABLE_NAME='account_legal_holds' THEN
  SELECT id INTO locked FROM accounts WHERE id=target FOR UPDATE;
 ELSE
  SELECT id INTO locked FROM accounts WHERE id=target FOR SHARE;
 END IF;
 IF locked IS NULL OR EXISTS(SELECT 1 FROM account_erasures WHERE account_id=target) THEN
  RAISE EXCEPTION 'account authority unavailable' USING ERRCODE='23514';
 END IF;
 RETURN NEW;
END $$;
-- A fresh statement after locking observes a hold committed before the lock.
-- Pending holds/erasures have the exclusive lock and are skipped, not waited on.
CREATE FUNCTION maintenance_account_unheld(target TEXT) RETURNS BOOLEAN LANGUAGE plpgsql VOLATILE AS $$
BEGIN
 PERFORM id FROM accounts WHERE id=target FOR SHARE SKIP LOCKED;
 IF NOT FOUND THEN RETURN FALSE; END IF;
 RETURN NOT EXISTS(SELECT 1 FROM account_legal_holds WHERE account_id=target);
END $$;
CREATE FUNCTION protect_erased_account() RETURNS trigger LANGUAGE plpgsql AS $$
DECLARE target TEXT;
BEGIN
 IF TG_OP='DELETE' THEN target:=OLD.id; ELSE target:=NEW.id; END IF;
 IF EXISTS(SELECT 1 FROM account_erasures WHERE account_id=target) THEN
  RAISE EXCEPTION 'account erasure is permanent' USING ERRCODE='23514';
 END IF;
 IF TG_OP='DELETE' THEN RETURN OLD; ELSE RETURN NEW; END IF;
END $$;
CREATE TRIGGER accounts_erasure_fence BEFORE INSERT OR UPDATE OR DELETE ON accounts FOR EACH ROW EXECUTE FUNCTION protect_erased_account();
CREATE FUNCTION immutable_erasure_marker() RETURNS trigger LANGUAGE plpgsql AS $$
BEGIN RAISE EXCEPTION 'erasure marker is immutable' USING ERRCODE='23514'; END $$;
CREATE TRIGGER erasure_marker_immutable BEFORE UPDATE OR DELETE ON account_erasures FOR EACH ROW EXECUTE FUNCTION immutable_erasure_marker();
`
	var triggers, drops strings.Builder
	for _, table := range guardedAccountTables {
		triggers.WriteString("CREATE TRIGGER active_account_guard BEFORE INSERT OR UPDATE ON " + table + " FOR EACH ROW EXECUTE FUNCTION require_active_account();\n")
		drops.WriteString("DROP TRIGGER active_account_guard ON " + table + ";\n")
	}
	down := `DO $$ BEGIN IF EXISTS(SELECT 1 FROM account_erasures) THEN RAISE EXCEPTION 'cannot roll back applied erasures'; END IF; END $$;` + drops.String() + `
DROP TRIGGER accounts_erasure_fence ON accounts;
DROP FUNCTION protect_erased_account();
DROP TABLE account_erasures;
DROP FUNCTION immutable_erasure_marker();
DROP FUNCTION require_active_account();
DROP FUNCTION maintenance_account_unheld(TEXT);
DROP TABLE account_legal_holds;
DROP TABLE revoked_device_keys;
DROP INDEX auth_sessions_retention;
DROP INDEX refresh_tokens_retention;
DROP INDEX refresh_tokens_session_expiry;
DROP INDEX oauth_states_retention;
DROP INDEX oauth_start_retention;
DROP INDEX session_authorizations_retention;
DROP INDEX session_authorizations_expired;
ALTER TABLE auth_sessions DROP COLUMN retired_at;
-- Refuse destructive rollback if compacted responses no longer exist.
ALTER TABLE session_start_requests ALTER COLUMN response_payload SET NOT NULL;
ALTER TABLE session_start_requests DROP COLUMN retired_at;
ALTER TABLE oauth_start_requests DROP COLUMN created_at;
`
	return Migration{Version: 8, Description: "bounded retention and permanent account erasure fences", Up: up + triggers.String(), Down: down}
}
