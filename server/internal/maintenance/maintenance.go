// Package maintenance compacts expired operational data without removing the
// permanent identifiers needed to refuse replay of material operations.
package maintenance

import (
	"context"
	"database/sql"
	"errors"
	"fmt"
	"time"

	"psychosims.dev/server/internal/audit"
)

type Policy struct {
	RetryGrace       time.Duration
	ReceiptRetention time.Duration
	BatchSize        int
}

func DefaultPolicy() Policy {
	return Policy{RetryGrace: 24 * time.Hour, ReceiptRetention: 90 * 24 * time.Hour, BatchSize: 250}
}
func (p Policy) Validate() error {
	if p.RetryGrace < time.Hour || p.RetryGrace > 30*24*time.Hour || p.ReceiptRetention < 24*time.Hour || p.ReceiptRetention > 365*24*time.Hour || p.BatchSize < 1 || p.BatchSize > 1000 {
		return errors.New("invalid retention policy")
	}
	return nil
}

type Report struct {
	Applied   bool             `json:"applied"`
	Counts    map[string]int64 `json:"counts"`
	BatchSize int              `json:"batch_size"`
}
type Service struct {
	db      *sql.DB
	auditor audit.Appender
}

func NewService(db *sql.DB, auditor audit.Appender) *Service {
	return &Service{db: db, auditor: auditor}
}

type operation struct {
	name, table, predicate, update string
	receipt                        bool
	account                        bool
}

var operations = []operation{
	{name: "oauth_states", table: "oauth_states", predicate: `t.expires_at<$1`},
	{name: "oauth_start_requests", table: "oauth_start_requests", predicate: `t.created_at<$1 AND NOT EXISTS(SELECT 1 FROM oauth_states s WHERE s.state=t.state AND s.expires_at>=$1)`},
	{name: "refresh_tokens", table: "refresh_tokens", predicate: `t.expires_at<$1 AND (t.replacement_pair IS NULL OR (to_timestamp((t.replacement_pair->'access'->>'expires_at')::bigint)<$1 AND to_timestamp((t.replacement_pair->'refresh'->>'expires_at')::bigint)<$1))`},
	{name: "auth_session_claims", table: "auth_sessions", account: true, predicate: `t.retired_at IS NULL AND t.created_at<$1 AND to_timestamp((t.initial_pair->'access'->>'expires_at')::bigint)<$1 AND to_timestamp((t.initial_pair->'refresh'->>'expires_at')::bigint)<$1 AND NOT EXISTS(SELECT 1 FROM refresh_tokens r WHERE r.session_id=t.id)`, update: `initial_pair='{}'::jsonb,retired_at=clock_timestamp(),revoked_at=COALESCE(t.revoked_at,clock_timestamp())`},
	{name: "session_start_payloads", table: "session_start_requests", account: true, predicate: `t.retired_at IS NULL AND (t.response_payload->>'expires_at')::timestamptz<$1`, update: `response_payload=NULL,retired_at=clock_timestamp()`},
	{name: "expired_authorizations", table: "session_authorizations", account: true, predicate: `t.consumed_at IS NULL AND t.expires_at<$1`},
	{name: "receipt_payloads", table: "session_authorizations", account: true, receipt: true, predicate: `t.consumed_at<$1 AND t.receipt_bytes IS NOT NULL`, update: `receipt_bytes=NULL`},
	{name: "idempotency_keys", table: "idempotency_keys", account: true, predicate: `t.expires_at<$1`},
}

// Collect executes one bounded batch per class. Dry-run uses a read-only
// transaction. Large backlogs require repeated explicit invocations; locks held
// by live requests are skipped. Audit/ledger and accepted grant hashes survive.
func (s *Service) Collect(ctx context.Context, p Policy, apply bool) (Report, error) {
	report := Report{Counts: map[string]int64{}, BatchSize: p.BatchSize}
	if err := p.Validate(); err != nil {
		return report, err
	}
	if s.db == nil || s.auditor == nil {
		return report, errors.New("maintenance dependencies required")
	}
	tx, err := s.db.BeginTx(ctx, &sql.TxOptions{ReadOnly: !apply})
	if err != nil {
		return report, err
	}
	defer tx.Rollback()
	var now time.Time
	if err = tx.QueryRowContext(ctx, `SELECT clock_timestamp()`).Scan(&now); err != nil {
		return report, err
	}
	var total int64
	for _, op := range operations {
		cutoff := now.Add(-p.RetryGrace)
		if op.receipt {
			cutoff = now.Add(-p.ReceiptRetention)
		}
		where := op.predicate
		guard := "TRUE"
		if op.account {
			where += ` AND NOT EXISTS(SELECT 1 FROM account_legal_holds h WHERE h.account_id=t.account_id)`
			guard = `maintenance_account_unheld(t.account_id)`
		} else if op.name == "refresh_tokens" {
			where += ` AND NOT EXISTS(SELECT 1 FROM auth_sessions s JOIN account_legal_holds h ON h.account_id=s.account_id WHERE s.id=t.session_id)`
			guard = `EXISTS(SELECT 1 FROM auth_sessions s WHERE s.id=t.session_id AND maintenance_account_unheld(s.account_id))`
		}
		selected := `SELECT t.ctid FROM ` + op.table + ` t WHERE ` + where + ` ORDER BY t.ctid LIMIT $2`
		var n int64
		if !apply {
			err = tx.QueryRowContext(ctx, `SELECT COUNT(*) FROM (`+selected+`) candidates`, cutoff, p.BatchSize).Scan(&n)
		} else {
			selected += ` FOR UPDATE OF t SKIP LOCKED`
			// Materialize the bounded, locked candidate set before the volatile
			// account lock function; a sort must never lock the whole backlog.
			candidates := `SELECT t.ctid FROM ` + op.table + ` t JOIN eligible e ON t.ctid=e.ctid WHERE ` + guard
			command := `DELETE FROM ` + op.table + ` t USING candidates c WHERE t.ctid=c.ctid`
			if op.update != "" {
				command = `UPDATE ` + op.table + ` t SET ` + op.update + ` FROM candidates c WHERE t.ctid=c.ctid`
			}
			var result sql.Result
			result, err = tx.ExecContext(ctx, `WITH eligible AS MATERIALIZED (`+selected+`), candidates AS MATERIALIZED (`+candidates+`) `+command, cutoff, p.BatchSize)
			if err == nil {
				n, err = result.RowsAffected()
			}
		}
		if err != nil {
			return report, fmt.Errorf("retention %s: %w", op.name, err)
		}
		report.Counts[op.name] = n
		total += n
	}
	if !apply {
		return report, tx.Rollback()
	}
	if total > 0 {
		if err = s.auditor.Append(ctx, tx, audit.Record{AccountID: "maintenance", CorrelationID: "retention", Action: "retention_compact", EntityType: "operational_records", EntityID: "bounded_batch", Outcome: fmt.Sprintf("rows_%d", total)}); err != nil {
			return report, err
		}
	}
	err = tx.Commit()
	report.Applied = err == nil
	return report, err
}
