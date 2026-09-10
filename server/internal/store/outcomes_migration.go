package store

func outcomesMigration() Migration {
	return Migration{Version: 9, Description: "pinned certified outcomes and immutable reward verdicts", Up: `
ALTER TABLE session_authorizations ADD COLUMN certificate_id TEXT NOT NULL DEFAULT '';
ALTER TABLE session_authorizations ADD COLUMN catalog_sha256 TEXT NOT NULL DEFAULT '';
ALTER TABLE session_authorizations ADD COLUMN accepted_verdict JSONB;
CREATE TABLE certified_cures (
 account_id TEXT NOT NULL REFERENCES accounts(id),
 case_id TEXT NOT NULL,
 receipt_id TEXT NOT NULL UNIQUE REFERENCES session_authorizations(id),
 certificate_id TEXT NOT NULL,
 accepted_at TIMESTAMPTZ NOT NULL,
 xp INTEGER NOT NULL CHECK(xp>=0),
 study_points INTEGER NOT NULL CHECK(study_points>=0),
 cash_micros BIGINT NOT NULL CHECK(cash_micros>=0),
 PRIMARY KEY(account_id,case_id)
);
CREATE INDEX certified_cures_window ON certified_cures(account_id,accepted_at);
CREATE TRIGGER active_account_guard BEFORE INSERT OR UPDATE ON certified_cures FOR EACH ROW EXECUTE FUNCTION require_active_account();
`, Down: `
DO $$ BEGIN IF EXISTS(SELECT 1 FROM certified_cures) THEN RAISE EXCEPTION 'cannot roll back certified reward history'; END IF; END $$;
DROP TABLE certified_cures;
ALTER TABLE session_authorizations DROP COLUMN accepted_verdict;
ALTER TABLE session_authorizations DROP COLUMN catalog_sha256;
ALTER TABLE session_authorizations DROP COLUMN certificate_id;
`}
}
