// Package audit implements the hash-chained append-only audit trail for Phase 3.3.
package audit

import (
	"context"
	"crypto/sha256"
	"database/sql"
	"fmt"
	"time"
)

// Record is one row in the audit trail.
type Record struct {
	ID            int64     `json:"id"`
	AccountID     string    `json:"account_id"`
	CorrelationID string    `json:"correlation_id"`
	Action        string    `json:"action"`
	EntityType    string    `json:"entity_type"`
	EntityID      string    `json:"entity_id"`
	Outcome       string    `json:"outcome"`
	PrevHash      []byte    `json:"prev_hash"`
	RowHash       []byte    `json:"row_hash"`
	ServerTime    time.Time `json:"server_time"`
}

// Appender is the audit-trail writer interface.
type Appender interface {
	Append(ctx context.Context, tx *sql.Tx, rec Record) error
	AppendDirect(ctx context.Context, rec Record) error
	ValidateChain(ctx context.Context) ([]Record, error)
}

// SQLAppender writes records to the audit trail.
type SQLAppender struct {
	db *sql.DB
}

// NewAppender builds a SQL audit appender.
func NewAppender(db *sql.DB) *SQLAppender { return &SQLAppender{db: db} }

// AppendDirect records an action in its own transaction. Use this for audit
// events that occur before a caller-managed transaction exists.
func (a *SQLAppender) AppendDirect(ctx context.Context, rec Record) error {
	tx, err := a.db.BeginTx(ctx, nil)
	if err != nil {
		return err
	}
	if err := a.Append(ctx, tx, rec); err != nil {
		_ = tx.Rollback()
		return err
	}
	return tx.Commit()
}

// Append records an action inside the supplied transaction. It chains the new
// row to the most recent audit row in the table at commit time.
func (a *SQLAppender) Append(ctx context.Context, tx *sql.Tx, rec Record) error {
	prevHash, err := a.lastHash(ctx, tx)
	if err != nil {
		return err
	}
	rec.PrevHash = prevHash
	rec.ServerTime = time.Now().UTC()
	rec.RowHash = hashRecord(rec)

	_, err = tx.ExecContext(ctx, `
		INSERT INTO audit_log (account_id, correlation_id, action, entity_type, entity_id, outcome, prev_hash, row_hash, server_time)
		VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9)
	`, rec.AccountID, rec.CorrelationID, rec.Action, rec.EntityType, rec.EntityID, rec.Outcome, rec.PrevHash, rec.RowHash, rec.ServerTime)
	return err
}

func (a *SQLAppender) lastHash(ctx context.Context, tx *sql.Tx) ([]byte, error) {
	var hash []byte
	row := tx.QueryRowContext(ctx, `SELECT row_hash FROM audit_log ORDER BY id DESC LIMIT 1`)
	if err := row.Scan(&hash); err != nil {
		if err == sql.ErrNoRows {
			return make([]byte, sha256.Size), nil
		}
		return nil, err
	}
	return hash, nil
}

// ValidateChain reads the entire audit log and verifies every row hash and the
// chain linkage. It returns the records on success.
func (a *SQLAppender) ValidateChain(ctx context.Context) ([]Record, error) {
	rows, err := a.db.QueryContext(ctx, `
		SELECT id, account_id, correlation_id, action, entity_type, entity_id, outcome, prev_hash, row_hash, server_time
		FROM audit_log ORDER BY id ASC
	`)
	if err != nil {
		return nil, err
	}
	defer rows.Close()

	var out []Record
	var prevHash []byte
	for rows.Next() {
		var rec Record
		if err := rows.Scan(&rec.ID, &rec.AccountID, &rec.CorrelationID, &rec.Action, &rec.EntityType, &rec.EntityID, &rec.Outcome, &rec.PrevHash, &rec.RowHash, &rec.ServerTime); err != nil {
			return nil, err
		}
		want := hashRecord(rec)
		if string(want) != string(rec.RowHash) {
			return nil, fmt.Errorf("row %d hash mismatch", rec.ID)
		}
		if len(out) > 0 && string(rec.PrevHash) != string(prevHash) {
			return nil, fmt.Errorf("row %d chain break", rec.ID)
		}
		prevHash = rec.RowHash
		out = append(out, rec)
	}
	return out, rows.Err()
}

func hashRecord(rec Record) []byte {
	h := sha256.New()
	fmt.Fprintf(h, "%s|%s|%s|%s|%s|%s|%x|%d",
		rec.AccountID, rec.CorrelationID, rec.Action, rec.EntityType, rec.EntityID, rec.Outcome, rec.PrevHash, rec.ServerTime.Unix())
	return h.Sum(nil)
}

// MemoryAppender is an in-memory audit appender for tests.
type MemoryAppender struct {
	records []Record
}

// NewMemoryAppender creates a test appender.
func NewMemoryAppender() *MemoryAppender { return &MemoryAppender{} }

// AppendDirect records a row in memory.
func (m *MemoryAppender) AppendDirect(ctx context.Context, rec Record) error {
	return m.Append(ctx, nil, rec)
}

// Append records a row in memory.
func (m *MemoryAppender) Append(ctx context.Context, tx *sql.Tx, rec Record) error {
	rec.ID = int64(len(m.records) + 1)
	rec.ServerTime = time.Now().UTC()
	var prevHash []byte
	if len(m.records) > 0 {
		prevHash = m.records[len(m.records)-1].RowHash
	} else {
		prevHash = make([]byte, sha256.Size)
	}
	rec.PrevHash = prevHash
	rec.RowHash = hashRecord(rec)
	m.records = append(m.records, rec)
	return nil
}

// ValidateChain verifies the in-memory chain.
func (m *MemoryAppender) ValidateChain(ctx context.Context) ([]Record, error) {
	var prevHash []byte
	for i, rec := range m.records {
		want := hashRecord(rec)
		if string(want) != string(rec.RowHash) {
			return nil, fmt.Errorf("row %d hash mismatch", rec.ID)
		}
		if i > 0 && string(rec.PrevHash) != string(prevHash) {
			return nil, fmt.Errorf("row %d chain break", rec.ID)
		}
		prevHash = rec.RowHash
	}
	return append([]Record(nil), m.records...), nil
}

// Records returns a copy of the in-memory rows.
func (m *MemoryAppender) Records() []Record {
	return append([]Record(nil), m.records...)
}
