// Package presence implements Phase 3.5 server-signed presence records and the
// revocation list seam.
package presence

import (
	"context"
	"crypto/ed25519"
	"crypto/sha256"
	"database/sql"
	"encoding/hex"
	"fmt"
	"time"

	"psychosims.dev/server/internal/api"
)

// Record is a server-signed presence row.
type Record struct {
	AccountID string    `json:"account_id"`
	Status    string    `json:"status"`
	SuiteID   string    `json:"suite_id"`
	ETag      string    `json:"etag"`
	LastSeen  time.Time `json:"last_seen"`
	Signature []byte    `json:"signature,omitempty"`
}

// Repository abstracts presence persistence.
type Repository interface {
	Get(ctx context.Context, accountID string) (*Record, error)
	Upsert(ctx context.Context, rec *Record) error
	ListByStatus(ctx context.Context, status string) ([]Record, error)
}

// SQLRepository is the Postgres-backed presence store.
type SQLRepository struct {
	db *sql.DB
}

// NewSQLRepository creates a presence repository.
func NewSQLRepository(db *sql.DB) *SQLRepository {
	return &SQLRepository{db: db}
}

// Get implements Repository.
func (r *SQLRepository) Get(ctx context.Context, accountID string) (*Record, error) {
	row := r.db.QueryRowContext(ctx, `SELECT status, last_seen, etag FROM presence WHERE account_id = $1`, accountID)
	var rec Record
	rec.AccountID = accountID
	if err := row.Scan(&rec.Status, &rec.LastSeen, &rec.ETag); err != nil {
		if err == sql.ErrNoRows {
			return nil, api.NewNotFound("presence not found")
		}
		return nil, err
	}
	return &rec, nil
}

// Upsert implements Repository.
func (r *SQLRepository) Upsert(ctx context.Context, rec *Record) error {
	_, err := r.db.ExecContext(ctx, `
		INSERT INTO presence (account_id, status, suite_id, last_seen, etag)
		VALUES ($1, $2, $3, $4, $5)
		ON CONFLICT (account_id) DO UPDATE SET
			status = EXCLUDED.status,
			suite_id = EXCLUDED.suite_id,
			last_seen = EXCLUDED.last_seen,
			etag = EXCLUDED.etag
	`, rec.AccountID, rec.Status, rec.SuiteID, rec.LastSeen, rec.ETag)
	return err
}

// ListByStatus implements Repository.
func (r *SQLRepository) ListByStatus(ctx context.Context, status string) ([]Record, error) {
	rows, err := r.db.QueryContext(ctx, `SELECT account_id, status, suite_id, last_seen, etag FROM presence WHERE status = $1`, status)
	if err != nil {
		return nil, err
	}
	defer rows.Close()
	var out []Record
	for rows.Next() {
		var rec Record
		if err := rows.Scan(&rec.AccountID, &rec.Status, &rec.SuiteID, &rec.LastSeen, &rec.ETag); err != nil {
			return nil, err
		}
		out = append(out, rec)
	}
	return out, rows.Err()
}

// Service signs and verifies presence records.
type Service struct {
	repo   Repository
	signer ed25519.PrivateKey
}

// NewService builds a presence service.
func NewService(repo Repository, signer ed25519.PrivateKey) *Service {
	return &Service{repo: repo, signer: signer}
}

// Set updates presence and returns a signed record.
func (s *Service) Set(ctx context.Context, accountID, status, suiteID string) (*Record, error) {
	rec := &Record{
		AccountID: accountID,
		Status:    status,
		SuiteID:   suiteID,
		LastSeen:  time.Now().UTC(),
		ETag:      generateETag(),
	}
	rec.Signature = ed25519.Sign(s.signer, canonicalBytes(rec))
	if err := s.repo.Upsert(ctx, rec); err != nil {
		return nil, err
	}
	return rec, nil
}

// Verify checks a presence record signature.
func (s *Service) Verify(pub ed25519.PublicKey, rec *Record) bool {
	return ed25519.Verify(pub, canonicalBytes(rec), rec.Signature)
}

func canonicalBytes(rec *Record) []byte {
	return []byte(fmt.Sprintf("%s|%s|%s|%s|%d", rec.AccountID, rec.Status, rec.SuiteID, rec.ETag, rec.LastSeen.Unix()))
}

func generateETag() string {
	h := sha256.Sum256([]byte(time.Now().UTC().String()))
	return hex.EncodeToString(h[:8])
}

// InMemoryRepository is a test implementation.
type InMemoryRepository struct {
	records map[string]*Record
}

// NewInMemoryRepository creates a test repository.
func NewInMemoryRepository() *InMemoryRepository {
	return &InMemoryRepository{records: make(map[string]*Record)}
}

// Get implements Repository.
func (r *InMemoryRepository) Get(ctx context.Context, accountID string) (*Record, error) {
	rec, ok := r.records[accountID]
	if !ok {
		return nil, api.NewNotFound("presence not found")
	}
	return rec, nil
}

// Upsert implements Repository.
func (r *InMemoryRepository) Upsert(ctx context.Context, rec *Record) error {
	r.records[rec.AccountID] = rec
	return nil
}

// ListByStatus implements Repository.
func (r *InMemoryRepository) ListByStatus(ctx context.Context, status string) ([]Record, error) {
	var out []Record
	for _, rec := range r.records {
		if rec.Status == status {
			out = append(out, *rec)
		}
	}
	return out, nil
}
