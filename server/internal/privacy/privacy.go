// Package privacy implements a local operator erasure protocol. Identity links
// and mutable authority are removed; pseudonymous audit/ledger and anti-replay
// tombstones remain. This is not a claim of anonymity or legal compliance.
package privacy

import (
	"context"
	"crypto/sha256"
	"database/sql"
	"encoding/hex"
	"errors"
	"fmt"
	"time"

	"github.com/lib/pq"
	"psychosims.dev/server/internal/audit"
	"psychosims.dev/server/internal/schemas"
)

var ErrLegalHold = errors.New("account has a legal hold")
var ErrAccountNotFound = errors.New("account not found")

type Report struct {
	Applied       bool             `json:"applied"`
	AlreadyErased bool             `json:"already_erased"`
	Counts        map[string]int64 `json:"counts"`
}
type Service struct {
	db      *sql.DB
	auditor audit.Appender
}

func NewService(db *sql.DB, a audit.Appender) *Service { return &Service{db: db, auditor: a} }
func erasureID(account string) string {
	h := sha256.Sum256([]byte("account-erasure-v1\x00" + account))
	return hex.EncodeToString(h[:])
}

var deletedTables = []string{"provider_identities", "profiles", "presence", "oauth_exchange_results", "device_key_requests", "session_start_requests", "auth_sessions", "idempotency_keys"}

// Erase is transactional and idempotent. The local command must persist an
// Intent outside database backups before calling apply=true. Concurrent writes
// take an account share lock in DB triggers and cannot pass the committed fence.
func (s *Service) Erase(ctx context.Context, account string, apply bool) (Report, error) {
	return s.eraseWithRetry(ctx, account, apply, false)
}

func (s *Service) eraseWithRetry(ctx context.Context, account string, apply, restore bool) (Report, error) {
	if !schemas.ValidIdentifier(account) {
		return Report{}, errors.New("invalid account identifier")
	}
	if s.db == nil || s.auditor == nil {
		return Report{}, errors.New("privacy dependencies required")
	}
	var report Report
	var err error
	for attempt := 0; attempt < 3; attempt++ {
		report, err = s.erase(ctx, account, apply, restore)
		var pg *pq.Error
		if !errors.As(err, &pg) || (pg.Code != "40P01" && pg.Code != "40001") {
			break
		}
		if ctx.Err() != nil {
			return report, ctx.Err()
		}
	}
	return report, err
}

func (s *Service) erase(ctx context.Context, account string, apply, restore bool) (Report, error) {
	report := Report{Counts: map[string]int64{}}
	tx, err := s.db.BeginTx(ctx, &sql.TxOptions{ReadOnly: !apply})
	if err != nil {
		return report, err
	}
	defer tx.Rollback()
	var locked string
	query := `SELECT id FROM accounts WHERE id=$1`
	if apply {
		query += ` FOR UPDATE`
	}
	err = tx.QueryRowContext(ctx, query, account).Scan(&locked)
	if errors.Is(err, sql.ErrNoRows) && restore && !apply {
		report.Counts["account_fence"] = 1
		return report, tx.Rollback()
	}
	if errors.Is(err, sql.ErrNoRows) && restore && apply {
		if _, err = tx.ExecContext(ctx, `INSERT INTO accounts(id) VALUES($1)`, account); err != nil {
			return report, err
		}
	} else if errors.Is(err, sql.ErrNoRows) {
		return report, ErrAccountNotFound
	} else if err != nil {
		return report, err
	}
	if err = tx.QueryRowContext(ctx, `SELECT EXISTS(SELECT 1 FROM account_erasures WHERE account_id=$1)`, account).Scan(&report.AlreadyErased); err != nil {
		return report, err
	}
	if report.AlreadyErased {
		err = tx.Rollback()
		report.Applied = apply && err == nil
		return report, err
	}
	var held bool
	if err = tx.QueryRowContext(ctx, `SELECT EXISTS(SELECT 1 FROM account_legal_holds WHERE account_id=$1)`, account).Scan(&held); err != nil {
		return report, err
	}
	if held {
		return report, ErrLegalHold
	}
	for _, table := range deletedTables {
		var n int64
		if err = tx.QueryRowContext(ctx, `SELECT COUNT(*) FROM `+table+` WHERE account_id=$1`, account).Scan(&n); err != nil {
			return report, err
		}
		report.Counts[table] = n
	}
	// Count first so dry-run reports every affected class without writes or locks.
	for name, query := range map[string]string{
		"device_keys":               `SELECT count(*) FROM device_keys WHERE account_id=$1`,
		"unconsumed_authorizations": `SELECT count(*) FROM session_authorizations WHERE account_id=$1 AND consumed_at IS NULL`,
		"receipt_payloads":          `SELECT count(*) FROM session_authorizations WHERE account_id=$1 AND receipt_bytes IS NOT NULL`,
		"ownership_records":         `SELECT count(*) FROM ownership_records WHERE account_id=$1 AND state NOT IN ('cured','archived')`,
	} {
		var n int64
		if err = tx.QueryRowContext(ctx, query, account).Scan(&n); err != nil {
			return report, err
		}
		report.Counts[name] = n
	}
	if !apply {
		return report, tx.Rollback()
	}
	// Cleanup precedes marker insertion under the exclusive account lock, so
	// ordinary guard triggers permit cleanup but block concurrent new authority.
	if _, err = tx.ExecContext(ctx, `INSERT INTO revoked_device_keys(key_id,revoked_at) SELECT id,COALESCE(revoked_at,clock_timestamp()) FROM device_keys WHERE account_id=$1 ON CONFLICT(key_id) DO NOTHING`, account); err != nil {
		return report, err
	}
	for _, table := range deletedTables {
		if _, err = tx.ExecContext(ctx, `DELETE FROM `+table+` WHERE account_id=$1`, account); err != nil {
			return report, err
		}
	}
	for _, query := range []string{
		`DELETE FROM device_keys WHERE account_id=$1`,
		`DELETE FROM session_authorizations WHERE account_id=$1 AND consumed_at IS NULL`,
		`UPDATE session_authorizations SET receipt_bytes=NULL WHERE account_id=$1 AND receipt_bytes IS NOT NULL`,
		`UPDATE ownership_records SET state='archived',version=version+1,lease_expires_at=NULL,updated_at=clock_timestamp() WHERE account_id=$1 AND state NOT IN ('cured','archived')`,
	} {
		if _, err = tx.ExecContext(ctx, query, account); err != nil {
			return report, err
		}
	}
	if err = s.auditor.Append(ctx, tx, audit.Record{AccountID: account, CorrelationID: erasureID(account), Action: "account_erase", EntityType: "account", EntityID: account, Outcome: "identity_unlinked"}); err != nil {
		return report, err
	}
	if _, err = tx.ExecContext(ctx, `INSERT INTO account_erasures(account_id,erasure_id) VALUES($1,$2)`, account, erasureID(account)); err != nil {
		return report, err
	}
	err = tx.Commit()
	report.Applied = err == nil
	return report, err
}

// ApplyIntent is the mandatory post-restore fence replay, including accounts
// absent from an older backup. A separately preserved intent never restores PII.
func (s *Service) ApplyIntent(ctx context.Context, intent Intent, apply bool) (Report, error) {
	if err := intent.Validate(); err != nil {
		return Report{}, err
	}
	return s.eraseWithRetry(ctx, intent.AccountID, apply, true)
}

// Retention and erasure requests need an operator deadline, never background
// work with an unbounded context. This helper is shared by the local command.
func Deadline(parent context.Context, limit time.Duration) (context.Context, context.CancelFunc, error) {
	if limit < time.Second || limit > 5*time.Minute {
		return nil, nil, fmt.Errorf("invalid maintenance timeout")
	}
	ctx, cancel := context.WithTimeout(parent, limit)
	return ctx, cancel, nil
}
