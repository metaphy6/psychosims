// Package tokens implements the session-token lifecycle for Phase 3.1:
// short-lived access tokens + refresh-token rotation with server-side revocation.
//
// The format is a compact signed token (HMAC-SHA256) rather than a full JWT, to
// avoid an external dependency while preserving the required properties.
package tokens

import (
	"crypto/hmac"
	"crypto/rand"
	"crypto/sha256"
	"encoding/base64"
	"encoding/hex"
	"encoding/json"
	"errors"
	"fmt"
	"strings"
	"time"
)

var (
	// ErrInvalidToken is returned when a token is malformed or its signature invalid.
	ErrInvalidToken = errors.New("invalid token")
	// ErrTokenExpired is returned when a token has passed its expiry.
	ErrTokenExpired = errors.New("token expired")
	// ErrTokenRevoked is returned when a token has been revoked server-side.
	ErrTokenRevoked = errors.New("token revoked")
)

// TokenKind distinguishes access tokens from refresh tokens.
type TokenKind string

const (
	KindAccess  TokenKind = "access"
	KindRefresh TokenKind = "refresh"
)

// Claims is the parsed content of a token.
type Claims struct {
	SessionID string    `json:"session_id,omitempty"`
	AccountID string    `json:"account_id"`
	Kind      TokenKind `json:"kind"`
	TokenID   string    `json:"token_id"`
	IssuedAt  int64     `json:"issued_at"`
	ExpiresAt int64     `json:"expires_at"`
	Role      string    `json:"role"`
}

// Manager issues, verifies, and rotates session tokens.
type Manager struct {
	secret      []byte
	accessTTL   time.Duration
	refreshTTL  time.Duration
	revoked     map[string]time.Time // token_id -> revoked_at
	usedRefresh map[string]bool      // token_id -> true
}

// NewManager builds a token manager. secret must be 32+ bytes.
func NewManager(secret []byte, accessTTL, refreshTTL time.Duration) *Manager {
	if len(secret) < 32 {
		panic("token manager secret must be at least 32 bytes")
	}
	return &Manager{
		secret:      append([]byte(nil), secret...),
		accessTTL:   accessTTL,
		refreshTTL:  refreshTTL,
		revoked:     make(map[string]time.Time),
		usedRefresh: make(map[string]bool),
	}
}

// IssuePair generates a new access/refresh token pair for an account.
func (m *Manager) IssuePair(accountID, role string) (access, refresh string, err error) {
	now := time.Now().UTC()
	accessID, err := generateID()
	if err != nil {
		return "", "", err
	}
	refreshID, err := generateID()
	if err != nil {
		return "", "", err
	}

	access, err = m.sign(Claims{
		AccountID: accountID,
		Kind:      KindAccess,
		TokenID:   accessID,
		IssuedAt:  now.Unix(),
		ExpiresAt: now.Add(m.accessTTL).Unix(),
		Role:      role,
	})
	if err != nil {
		return "", "", err
	}

	refresh, err = m.sign(Claims{
		AccountID: accountID,
		Kind:      KindRefresh,
		TokenID:   refreshID,
		IssuedAt:  now.Unix(),
		ExpiresAt: now.Add(m.refreshTTL).Unix(),
		Role:      role,
	})
	if err != nil {
		return "", "", err
	}

	return access, refresh, nil
}

// Verify parses and validates an access token, returning its claims.
func (m *Manager) Verify(accessToken string) (Claims, error) {
	claims, err := m.parse(accessToken)
	if err != nil {
		return Claims{}, err
	}
	if claims.Kind != KindAccess {
		return Claims{}, ErrInvalidToken
	}
	if time.Now().UTC().After(time.Unix(claims.ExpiresAt, 0)) {
		return Claims{}, ErrTokenExpired
	}
	if m.isRevoked(claims.TokenID) {
		return Claims{}, ErrTokenRevoked
	}
	return claims, nil
}

// Rotate consumes a refresh token and issues a new pair, marking the old refresh
// token as used so replay is rejected.
func (m *Manager) Rotate(refreshToken string) (access, refresh string, err error) {
	claims, err := m.parse(refreshToken)
	if err != nil {
		return "", "", err
	}
	if claims.Kind != KindRefresh {
		return "", "", ErrInvalidToken
	}
	if time.Now().UTC().After(time.Unix(claims.ExpiresAt, 0)) {
		return "", "", ErrTokenExpired
	}
	if m.isRevoked(claims.TokenID) || m.usedRefresh[claims.TokenID] {
		return "", "", ErrTokenRevoked
	}
	m.usedRefresh[claims.TokenID] = true
	return m.IssuePair(claims.AccountID, claims.Role)
}

// Revoke marks a token id as revoked.
func (m *Manager) Revoke(tokenID string) {
	m.revoked[tokenID] = time.Now().UTC()
}

// RevokeAccount revokes all tokens for an account. In production this queries
// the token store; here it is a stub seam.
func (m *Manager) RevokeAccount(accountID string) {
	_ = accountID
}

func (m *Manager) isRevoked(tokenID string) bool {
	_, ok := m.revoked[tokenID]
	return ok
}

func (m *Manager) sign(claims Claims) (string, error) {
	payload, err := json.Marshal(claims)
	if err != nil {
		return "", err
	}
	h := hmac.New(sha256.New, m.secret)
	if _, err := h.Write(payload); err != nil {
		return "", err
	}
	sig := hex.EncodeToString(h.Sum(nil))
	return base64.RawURLEncoding.EncodeToString(payload) + "." + sig, nil
}

func (m *Manager) parse(token string) (Claims, error) {
	parts := strings.Split(token, ".")
	if len(parts) != 2 {
		return Claims{}, ErrInvalidToken
	}
	payload, err := base64.RawURLEncoding.DecodeString(parts[0])
	if err != nil {
		return Claims{}, ErrInvalidToken
	}
	h := hmac.New(sha256.New, m.secret)
	if _, err := h.Write(payload); err != nil {
		return Claims{}, err
	}
	wantSig := hex.EncodeToString(h.Sum(nil))
	if !hmac.Equal([]byte(wantSig), []byte(parts[1])) {
		return Claims{}, ErrInvalidToken
	}
	var claims Claims
	if err := json.Unmarshal(payload, &claims); err != nil {
		return Claims{}, ErrInvalidToken
	}
	return claims, nil
}

func generateID() (string, error) {
	b := make([]byte, 16)
	if _, err := rand.Read(b); err != nil {
		return "", fmt.Errorf("generate token id: %w", err)
	}
	return hex.EncodeToString(b), nil
}
