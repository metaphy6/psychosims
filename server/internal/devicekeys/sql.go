package devicekeys

import (
	"bytes"
	"context"
	"crypto/rand"
	"crypto/sha256"
	"database/sql"
	"encoding/hex"
	"encoding/json"
	"errors"

	"psychosims.dev/server/internal/api"
	"psychosims.dev/server/internal/ctxutil"
)

type SQLRepository struct{ db *sql.DB }

func NewSQLRepository(db *sql.DB) *SQLRepository { return &SQLRepository{db: db} }

type rowScanner interface{ Scan(...any) error }

func scanKey(row rowScanner) (*Record, error) {
	r := &Record{}
	err := row.Scan(&r.ID, &r.AccountID, &r.PublicKey, &r.SuiteID, &r.CreatedAt, &r.RevokedAt)
	if errors.Is(err, sql.ErrNoRows) {
		return nil, nil
	}
	return r, err
}

const keyColumns = `id,account_id,public_key,suite_id,created_at,revoked_at`

func keyID() (string, error) {
	b := make([]byte, 16)
	if _, err := rand.Read(b); err != nil {
		return "", err
	}
	return "key_" + hex.EncodeToString(b), nil
}
func (r *SQLRepository) Register(ctx context.Context, account string, pub []byte, suite string) (string, error) {
	tx, err := r.db.BeginTx(ctx, nil)
	if err != nil {
		return "", err
	}
	defer tx.Rollback()
	var locked string
	if err = tx.QueryRowContext(ctx, `SELECT id FROM accounts WHERE id=$1 FOR UPDATE`, account).Scan(&locked); err != nil {
		return "", err
	}
	replay, hash, err := checkKeyRequest(ctx, tx, account, "", pub, suite)
	if err != nil {
		return "", err
	}
	if replay != "" {
		return replay, nil
	}
	rec, err := scanKey(tx.QueryRowContext(ctx, `SELECT `+keyColumns+` FROM device_keys WHERE account_id=$1 AND public_key=$2`, account, pub))
	if err != nil {
		return "", err
	}
	if rec != nil {
		if rec.RevokedAt != nil || rec.SuiteID != suite {
			return "", api.NewConflict(api.CodeConflict, "public key already registered with incompatible state")
		}
		if err := storeKeyRequest(ctx, tx, account, hash, rec.ID); err != nil {
			return "", err
		}
		return rec.ID, tx.Commit()
	}
	id, err := keyID()
	if err != nil {
		return "", err
	}
	if _, err = tx.ExecContext(ctx, `INSERT INTO device_keys(id,account_id,public_key,suite_id) VALUES($1,$2,$3,$4)`, id, account, pub, suite); err != nil {
		return "", err
	}
	if err := storeKeyRequest(ctx, tx, account, hash, id); err != nil {
		return "", err
	}
	return id, tx.Commit()
}
func (r *SQLRepository) Lookup(ctx context.Context, id string) (*Record, error) {
	return scanKey(r.db.QueryRowContext(ctx, `SELECT `+keyColumns+` FROM device_keys WHERE id=$1`, id))
}
func (r *SQLRepository) ListByAccount(ctx context.Context, account string) ([]Record, error) {
	rows, err := r.db.QueryContext(ctx, `SELECT `+keyColumns+` FROM device_keys WHERE account_id=$1 AND revoked_at IS NULL ORDER BY id`, account)
	if err != nil {
		return nil, err
	}
	defer rows.Close()
	out := []Record{}
	for rows.Next() {
		rec, err := scanKey(rows)
		if err != nil {
			return nil, err
		}
		out = append(out, *rec)
	}
	return out, rows.Err()
}
func (r *SQLRepository) ListRevoked(ctx context.Context) ([]RevocationEntry, error) {
	rows, err := r.db.QueryContext(ctx, `SELECT id,revoked_at FROM device_keys WHERE revoked_at IS NOT NULL UNION SELECT key_id,revoked_at FROM revoked_device_keys ORDER BY 1`)
	if err != nil {
		return nil, err
	}
	defer rows.Close()
	out := []RevocationEntry{}
	for rows.Next() {
		var rec RevocationEntry
		if err := rows.Scan(&rec.KeyID, &rec.RevokedAt); err != nil {
			return nil, err
		}
		out = append(out, rec)
	}
	return out, rows.Err()
}
func (r *SQLRepository) Revoke(ctx context.Context, account, id string) error {
	result, err := r.db.ExecContext(ctx, `UPDATE device_keys SET revoked_at=COALESCE(revoked_at,clock_timestamp()) WHERE id=$1 AND account_id=$2`, id, account)
	if err != nil {
		return err
	}
	n, err := result.RowsAffected()
	if err == nil && n == 0 {
		return api.NewNotFound("device key not found")
	}
	return err
}

// Replace revokes an explicitly selected account-owned key in the same
// transaction as its replacement. The old-key edge also makes retries stable.
func (r *SQLRepository) Replace(ctx context.Context, account, old string, pub []byte, suite string) (string, error) {
	tx, err := r.db.BeginTx(ctx, nil)
	if err != nil {
		return "", err
	}
	defer tx.Rollback()
	var locked string
	if err = tx.QueryRowContext(ctx, `SELECT id FROM accounts WHERE id=$1 FOR UPDATE`, account).Scan(&locked); err != nil {
		return "", err
	}
	replay, hash, err := checkKeyRequest(ctx, tx, account, old, pub, suite)
	if err != nil {
		return "", err
	}
	if replay != "" {
		return replay, nil
	}
	rec, err := scanKey(tx.QueryRowContext(ctx, `SELECT `+keyColumns+` FROM device_keys WHERE id=$1 AND account_id=$2 FOR UPDATE`, old, account))
	if err != nil {
		return "", err
	}
	if rec == nil {
		return "", api.NewNotFound("device key not found")
	}
	next, err := scanKey(tx.QueryRowContext(ctx, `SELECT `+keyColumns+` FROM device_keys WHERE replaces_key_id=$1`, old))
	if err != nil {
		return "", err
	}
	if next != nil {
		if !bytes.Equal(next.PublicKey, pub) || next.SuiteID != suite || next.RevokedAt != nil {
			return "", api.NewConflict(api.CodeConflict, "replacement already completed differently")
		}
		if err := storeKeyRequest(ctx, tx, account, hash, next.ID); err != nil {
			return "", err
		}
		return next.ID, tx.Commit()
	}
	if rec.RevokedAt != nil {
		return "", api.NewConflict(api.CodeConflict, "device key already revoked")
	}
	if bytes.Equal(rec.PublicKey, pub) {
		return "", api.NewUserError(api.CodeBadRequest, "replacement must use a new public key")
	}
	id, err := keyID()
	if err != nil {
		return "", err
	}
	if _, err = tx.ExecContext(ctx, `INSERT INTO device_keys(id,account_id,public_key,suite_id,replaces_key_id) VALUES($1,$2,$3,$4,$5)`, id, account, pub, suite, old); err != nil {
		return "", err
	}
	if _, err = tx.ExecContext(ctx, `UPDATE device_keys SET revoked_at=clock_timestamp() WHERE id=$1`, old); err != nil {
		return "", err
	}
	if err := storeKeyRequest(ctx, tx, account, hash, id); err != nil {
		return "", err
	}
	return id, tx.Commit()
}

func checkKeyRequest(ctx context.Context, tx *sql.Tx, account, old string, pub []byte, suite string) (string, []byte, error) {
	key := ctxutil.IdempotencyKey(ctx)
	if key == "" {
		return "", nil, nil
	}
	body, _ := json.Marshal(struct {
		Old   string
		Pub   []byte
		Suite string
	}{old, pub, suite})
	hash := sha256.Sum256(body)
	var id string
	var stored []byte
	err := tx.QueryRowContext(ctx, `SELECT key_id,request_hash FROM device_key_requests WHERE account_id=$1 AND operation_key=$2`, account, key).Scan(&id, &stored)
	if errors.Is(err, sql.ErrNoRows) {
		return "", hash[:], nil
	}
	if err != nil {
		return "", nil, err
	}
	if !bytes.Equal(stored, hash[:]) {
		return "", nil, api.NewConflict(api.CodeConflict, "device operation key already used differently")
	}
	return id, hash[:], nil
}
func storeKeyRequest(ctx context.Context, tx *sql.Tx, account string, hash []byte, id string) error {
	if len(hash) == 0 {
		return nil
	}
	_, err := tx.ExecContext(ctx, `INSERT INTO device_key_requests(account_id,operation_key,request_hash,key_id) VALUES($1,$2,$3,$4)`, account, ctxutil.IdempotencyKey(ctx), hash, id)
	return err
}
