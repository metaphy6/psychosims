// Package devicekeys implements the account binding for per-device signing keys
// (Phase 3.1 / 3.5). The server certifies a public key for an account; 3.3
// verifies that a receipt's signing_key_id resolves to a key registered to the
// authenticated account.
package devicekeys

import (
	"context"
	"crypto/ed25519"
	"errors"
	"fmt"
	"time"

	"psychosims.dev/server/internal/api"
)

// Record is a certified device public key.
type Record struct {
	ID        string    `json:"id"`
	AccountID string    `json:"account_id"`
	PublicKey []byte    `json:"public_key"`
	SuiteID   string    `json:"suite_id"`
	CreatedAt time.Time `json:"created_at"`
	RevokedAt *time.Time `json:"revoked_at,omitempty"`
}

// Repository abstracts device-key persistence.
type Repository interface {
	// Register records a new key for an account.
	Register(ctx context.Context, accountID string, pub []byte, suiteID string) (string, error)
	// Lookup returns the key record for a key id, or nil.
	Lookup(ctx context.Context, keyID string) (*Record, error)
	// ListByAccount returns active keys for an account.
	ListByAccount(ctx context.Context, accountID string) ([]Record, error)
	// ListRevoked returns all revoked keys for the revocation list.
	ListRevoked(ctx context.Context) ([]RevocationEntry, error)
	// Revoke marks a key as revoked.
	Revoke(ctx context.Context, accountID, keyID string) error
}

// RateLimiter restricts provisioning frequency per account.
type RateLimiter interface {
	Allow(accountID string) bool
}

// Service certifies and resolves device keys.
type Service struct {
	repo      Repository
	limiter   RateLimiter
	rotations *RotationPolicy
}

// NewService builds a device-key service.
func NewService(repo Repository) *Service {
	return &Service{repo: repo}
}

// WithRateLimiter attaches a provisioning rate limiter.
func (s *Service) WithRateLimiter(l RateLimiter) *Service {
	s.limiter = l
	return s
}

// WithRotationPolicy attaches the suite rotation window policy.
func (s *Service) WithRotationPolicy(r *RotationPolicy) *Service {
	s.rotations = r
	return s
}

// Provision certifies a new public key bound to an account, with a suite id and
// rate-limit check.
func (s *Service) Provision(ctx context.Context, accountID string, pub []byte, suiteID string) (string, error) {
	if s.limiter != nil && !s.limiter.Allow(accountID) {
		return "", api.NewRateLimited(60)
	}
	return s.Register(ctx, accountID, pub, suiteID)
}

// Recover re-provisions a new key for an account (e.g. reinstall / device-
// switch) and optionally revokes an existing active key.
func (s *Service) Recover(ctx context.Context, accountID string, pub []byte, suiteID string, revokeOld bool) (newID string, revokedID string, err error) {
	newID, err = s.Provision(ctx, accountID, pub, suiteID)
	if err != nil {
		return "", "", err
	}
	if revokeOld {
		keys, err := s.repo.ListByAccount(ctx, accountID)
		if err != nil {
			return newID, "", err
		}
		for _, k := range keys {
			if k.ID != newID && k.RevokedAt == nil {
				if err := s.repo.Revoke(ctx, accountID, k.ID); err == nil {
					return newID, k.ID, nil
				}
			}
		}
	}
	return newID, "", nil
}

// VerifyRecord checks a key record against the rotation policy: a record signed
// under the previous suite is still acceptable within its overlap window.
func (s *Service) VerifyRecord(rec *Record, now time.Time) bool {
	if rec.RevokedAt != nil {
		return false
	}
	if s.rotations == nil {
		return true
	}
	return s.rotations.Valid(rec.SuiteID, now)
}

// Register validates and certifies a public key for an account.
func (s *Service) Register(ctx context.Context, accountID string, pub []byte, suiteID string) (string, error) {
	if accountID == "" {
		return "", api.NewUnauthorized("account id required")
	}
	if suiteID == "" {
		return "", api.NewUserError(api.CodeBadRequest, "suite id required")
	}
	if len(pub) != ed25519.PublicKeySize {
		return "", api.NewUserError(api.CodeBadRequest, "invalid ed25519 public key length")
	}
	return s.repo.Register(ctx, accountID, pub, suiteID)
}

// Lookup returns a key record by id (no account check).
func (s *Service) Lookup(ctx context.Context, keyID string) (*Record, error) {
	return s.repo.Lookup(ctx, keyID)
}

// ResolveForAccount returns the public key record if and only if the key is
// registered to the given account and not revoked.
func (s *Service) ResolveForAccount(ctx context.Context, accountID, keyID string) (*Record, error) {
	rec, err := s.repo.Lookup(ctx, keyID)
	if err != nil {
		return nil, api.NewInternalError("key lookup failed: " + err.Error())
	}
	if rec == nil {
		return nil, api.NewUserError(api.CodeInvalidSignature, "unknown device key")
	}
	if rec.AccountID != accountID {
		return nil, api.NewUserError(api.CodeInvalidSignature, "device key not registered to this account")
	}
	if rec.RevokedAt != nil {
		return nil, api.NewUserError(api.CodeInvalidSignature, "device key revoked")
	}
	return rec, nil
}
// RotationPolicy describes overlapping validity windows for signature suites.
type RotationPolicy struct {
	Active   string
	Previous string
	PreviousValidUntil time.Time
}

// Valid reports whether suiteID is accepted at now.
func (p *RotationPolicy) Valid(suiteID string, now time.Time) bool {
	if suiteID == p.Active {
		return true
	}
	if suiteID == p.Previous && now.Before(p.PreviousValidUntil) {
		return true
	}
	return false
}
// InMemoryRepository is a test implementation.
type InMemoryRepository struct {
	records map[string]*Record
	byAccount map[string][]string
}

// NewInMemoryRepository creates a test repository.
func NewInMemoryRepository() *InMemoryRepository {
	return &InMemoryRepository{
		records:   make(map[string]*Record),
		byAccount: make(map[string][]string),
	}
}

// Register implements Repository.
func (r *InMemoryRepository) Register(ctx context.Context, accountID string, pub []byte, suiteID string) (string, error) {
	id := fmt.Sprintf("key_%d", len(r.records)+1)
	rec := &Record{
		ID:        id,
		AccountID: accountID,
		PublicKey: append([]byte(nil), pub...),
		SuiteID:   suiteID,
		CreatedAt: time.Now().UTC(),
	}
	r.records[id] = rec
	r.byAccount[accountID] = append(r.byAccount[accountID], id)
	return id, nil
}

// Lookup implements Repository.
func (r *InMemoryRepository) Lookup(ctx context.Context, keyID string) (*Record, error) {
	return r.records[keyID], nil
}

// ListByAccount implements Repository.
func (r *InMemoryRepository) ListByAccount(ctx context.Context, accountID string) ([]Record, error) {
	var out []Record
	for _, id := range r.byAccount[accountID] {
		out = append(out, *r.records[id])
	}
	return out, nil
}

// ListRevoked implements Repository.
func (r *InMemoryRepository) ListRevoked(ctx context.Context) ([]RevocationEntry, error) {
	var out []RevocationEntry
	for _, rec := range r.records {
		if rec.RevokedAt != nil {
			out = append(out, RevocationEntry{KeyID: rec.ID, RevokedAt: *rec.RevokedAt})
		}
	}
	return out, nil
}

// Revoke implements Repository.
func (r *InMemoryRepository) Revoke(ctx context.Context, accountID, keyID string) error {
	rec, ok := r.records[keyID]
	if !ok {
		return errors.New("key not found")
	}
	if rec.AccountID != accountID {
		return errors.New("key belongs to another account")
	}
	now := time.Now().UTC()
	rec.RevokedAt = &now
	return nil
}
