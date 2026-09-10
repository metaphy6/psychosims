// Package idempotency implements server-side deduplication for mutating
// requests, the server half of the 3.0/3.4 exactly-once contract.
//
// Keys are scoped to an account and carry a bounded TTL. A GC process removes
// expired rows so the dedupe table cannot grow without limit.
package idempotency

import (
	"bytes"
	"context"
	"crypto/sha256"
	"database/sql"
	"fmt"
	"net/http"
	"time"

	"psychosims.dev/server/internal/api"
	"psychosims.dev/server/internal/ctxutil"
)

// Repository abstracts idempotency-key storage.
type Repository interface {
	// Lookup returns the stored response hash (or nil) and true if the key exists.
	Lookup(ctx context.Context, accountID, key string) ([]byte, bool, error)
	// Store records a key and its response hash.
	Store(ctx context.Context, accountID, key string, responseHash []byte, ttl time.Duration) error
	// GC removes expired keys.
	GC(ctx context.Context, before time.Time) (int64, error)
}

// MemoryRepository is an in-memory implementation for tests.
type MemoryRepository struct {
	entries map[string]memoryEntry
}

type memoryEntry struct {
	accountID    string
	responseHash []byte
	expiresAt    time.Time
}

// NewMemoryRepository creates a new in-memory repository.
func NewMemoryRepository() *MemoryRepository {
	return &MemoryRepository{entries: make(map[string]memoryEntry)}
}

func key(accountID, key string) string { return accountID + "::" + key }

// Lookup implements Repository.
func (r *MemoryRepository) Lookup(ctx context.Context, accountID, k string) ([]byte, bool, error) {
	e, ok := r.entries[key(accountID, k)]
	if !ok {
		return nil, false, nil
	}
	if time.Now().After(e.expiresAt) {
		delete(r.entries, key(accountID, k))
		return nil, false, nil
	}
	return e.responseHash, true, nil
}

// Store implements Repository.
func (r *MemoryRepository) Store(ctx context.Context, accountID, k string, responseHash []byte, ttl time.Duration) error {
	r.entries[key(accountID, k)] = memoryEntry{
		accountID:    accountID,
		responseHash: responseHash,
		expiresAt:    time.Now().Add(ttl),
	}
	return nil
}

// GC implements Repository.
func (r *MemoryRepository) GC(ctx context.Context, before time.Time) (int64, error) {
	var n int64
	for k, e := range r.entries {
		if e.expiresAt.Before(before) {
			delete(r.entries, k)
			n++
		}
	}
	return n, nil
}

// SQLRepository stores idempotency keys in Postgres.
type SQLRepository struct {
	db *sql.DB
}

// NewSQLRepository creates a Postgres-backed repository.
func NewSQLRepository(db *sql.DB) *SQLRepository {
	return &SQLRepository{db: db}
}

// Lookup implements Repository.
func (r *SQLRepository) Lookup(ctx context.Context, accountID, k string) ([]byte, bool, error) {
	var hash []byte
	err := r.db.QueryRowContext(ctx, `
		SELECT response_hash FROM idempotency_keys
		WHERE key = $1 AND account_id = $2 AND expires_at > NOW()
	`, k, accountID).Scan(&hash)
	if err == sql.ErrNoRows {
		return nil, false, nil
	}
	if err != nil {
		return nil, false, err
	}
	return hash, true, nil
}

// Store implements Repository.
func (r *SQLRepository) Store(ctx context.Context, accountID, k string, responseHash []byte, ttl time.Duration) error {
	expiresAt := time.Now().Add(ttl)
	_, err := r.db.ExecContext(ctx, `
		INSERT INTO idempotency_keys (key, account_id, response_hash, expires_at)
		VALUES ($1, $2, $3, $4)
		ON CONFLICT (account_id, key) DO UPDATE SET
			response_hash = EXCLUDED.response_hash,
			expires_at = EXCLUDED.expires_at
	`, k, accountID, responseHash, expiresAt)
	return err
}

// GC implements Repository.
func (r *SQLRepository) GC(ctx context.Context, before time.Time) (int64, error) {
	res, err := r.db.ExecContext(ctx, `DELETE FROM idempotency_keys WHERE expires_at < $1`, before)
	if err != nil {
		return 0, err
	}
	return res.RowsAffected()
}

// Service wraps a Repository with the request-context seam.
type Service struct {
	repo       Repository
	defaultTTL time.Duration
}

// NewService builds a Service.
func NewService(repo Repository, defaultTTL time.Duration) *Service {
	return &Service{repo: repo, defaultTTL: defaultTTL}
}

// CheckOrBegin is a legacy read-only preflight, not a reservation. Mutations
// must use BeginInTx. It returns an error if the key has already been used
// and the stored response matches the current request. The bool indicates
// whether the caller should execute the request (true) or return a cached
// result (false).
func (s *Service) CheckOrBegin(ctx context.Context) (bool, []byte, error) {
	accountID := ctxutil.AccountID(ctx)
	if accountID == "" {
		return false, nil, api.NewUnauthorized("account id required for idempotency")
	}
	key := ctxutil.IdempotencyKey(ctx)
	if key == "" {
		return false, nil, api.NewUserError(api.CodeBadRequest, "idempotency key required")
	}

	stored, found, err := s.repo.Lookup(ctx, accountID, key)
	if err != nil {
		return false, nil, api.NewInternalError("idempotency lookup failed: " + err.Error())
	}
	if found {
		return false, stored, api.NewError(http.StatusConflict, api.ErrUser, api.CodeIdempotentReplay,
			"idempotency key already used")
	}
	return true, nil, nil
}

// Record stores the response hash for the current request's idempotency key.
func (s *Service) Record(ctx context.Context, responseBody []byte) error {
	accountID := ctxutil.AccountID(ctx)
	key := ctxutil.IdempotencyKey(ctx)
	if accountID == "" || key == "" {
		return fmt.Errorf("account id and idempotency key required")
	}
	hash := sha256.Sum256(responseBody)
	return s.repo.Store(ctx, accountID, key, hash[:], s.defaultTTL)
}

// GC removes expired idempotency keys older than before.
func (s *Service) GC(ctx context.Context, before time.Time) (int64, error) {
	return s.repo.GC(ctx, before)
}

// BeginInTx atomically reserves an account-scoped key. Concurrent callers wait
// for the owning transaction; failed transactions leave no reservation behind.
func (s *Service) BeginInTx(ctx context.Context, tx *sql.Tx, accountID, k string, requestHash []byte) (bool, error) {
	if accountID == "" || k == "" {
		return false, api.NewUserError(api.CodeBadRequest, "account and idempotency key required")
	}
	ttl := s.defaultTTL
	if ttl <= 0 {
		ttl = 24 * time.Hour
	}
	res, err := tx.ExecContext(ctx, `INSERT INTO idempotency_keys(account_id,key,request_hash,response_hash,expires_at)
        VALUES($1,$2,$3,$3,$4) ON CONFLICT(account_id,key) DO NOTHING`, accountID, k, requestHash, time.Now().Add(ttl))
	if err != nil {
		return false, err
	}
	n, err := res.RowsAffected()
	if err != nil {
		return false, err
	}
	if n == 1 {
		return true, nil
	}
	var previous []byte
	if err := tx.QueryRowContext(ctx, `SELECT request_hash FROM idempotency_keys WHERE account_id=$1 AND key=$2`, accountID, k).Scan(&previous); err != nil {
		return false, err
	}
	if !bytes.Equal(previous, requestHash) {
		return false, api.NewConflict(api.CodeConflict, "idempotency key reused with different request")
	}
	return false, nil
}
