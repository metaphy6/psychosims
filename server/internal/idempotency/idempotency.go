// Package idempotency implements server-side deduplication for mutating
// requests, the server half of the 3.0/3.4 exactly-once contract.
//
// Keys are scoped to an account and carry a bounded TTL. A GC process removes
// expired rows so the dedupe table cannot grow without limit.
package idempotency

import (
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
		ON CONFLICT (key) DO UPDATE SET
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

// CheckOrBegin returns an error if the idempotency key has already been used
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
