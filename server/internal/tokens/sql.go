package tokens

import (
	"context"
	"crypto/hmac"
	"crypto/sha256"
	"database/sql"
	"encoding/json"
	"errors"
	"time"
)

// Pair is the stable wire response. Neither raw token is stored in PostgreSQL.
type Pair struct {
	AccountID        string    `json:"account_id"`
	AccessToken      string    `json:"access_token"`
	RefreshToken     string    `json:"refresh_token"`
	TokenType        string    `json:"token_type"`
	AccessExpiresAt  time.Time `json:"access_expires_at"`
	RefreshExpiresAt time.Time `json:"refresh_expires_at"`
}
type pairClaims struct {
	Access  Claims `json:"access"`
	Refresh Claims `json:"refresh"`
}

// SQLManager binds access and refresh tokens to a durable, revocable session.
// A retried rotation reconstructs the same signed response from stored claims;
// the old refresh digest and operation key must both match.
type SQLManager struct {
	db    *sql.DB
	codec *Manager
}

func NewSQLManager(db *sql.DB, secret []byte, accessTTL, refreshTTL time.Duration) *SQLManager {
	return &SQLManager{db: db, codec: NewManager(secret, accessTTL, refreshTTL)}
}
func (m *SQLManager) newClaims(account, session, role string) (pairClaims, error) {
	a, err := generateID()
	if err != nil {
		return pairClaims{}, err
	}
	r, err := generateID()
	if err != nil {
		return pairClaims{}, err
	}
	now := time.Now().UTC().Truncate(time.Second)
	return pairClaims{Access: Claims{SessionID: session, AccountID: account, Kind: KindAccess, TokenID: a, IssuedAt: now.Unix(), ExpiresAt: now.Add(m.codec.accessTTL).Unix(), Role: role}, Refresh: Claims{SessionID: session, AccountID: account, Kind: KindRefresh, TokenID: r, IssuedAt: now.Unix(), ExpiresAt: now.Add(m.codec.refreshTTL).Unix(), Role: role}}, nil
}
func (m *SQLManager) encode(p pairClaims) (Pair, error) {
	a, err := m.codec.sign(p.Access)
	if err != nil {
		return Pair{}, err
	}
	r, err := m.codec.sign(p.Refresh)
	if err != nil {
		return Pair{}, err
	}
	return Pair{AccountID: p.Access.AccountID, AccessToken: a, RefreshToken: r, TokenType: "Bearer", AccessExpiresAt: time.Unix(p.Access.ExpiresAt, 0).UTC(), RefreshExpiresAt: time.Unix(p.Refresh.ExpiresAt, 0).UTC()}, nil
}
func (m *SQLManager) storeRefresh(ctx context.Context, tx *sql.Tx, p pairClaims) error {
	pair, err := m.encode(p)
	if err != nil {
		return err
	}
	digest := sha256.Sum256([]byte(pair.RefreshToken))
	_, err = tx.ExecContext(ctx, `INSERT INTO refresh_tokens(token_id,session_id,token_digest,expires_at) VALUES($1,$2,$3,$4)`, p.Refresh.TokenID, p.Refresh.SessionID, digest[:], pair.RefreshExpiresAt)
	return err
}
func (m *SQLManager) IssuePair(ctx context.Context, account, key string) (Pair, error) {
	tx, err := m.db.BeginTx(ctx, nil)
	if err != nil {
		return Pair{}, err
	}
	defer tx.Rollback()
	pair, err := m.IssuePairInTx(ctx, tx, account, key)
	if err != nil {
		return Pair{}, err
	}
	if err := tx.Commit(); err != nil {
		return Pair{}, err
	}
	return pair, nil
}

// IssuePairInTx lets verified identity creation, one-use OAuth state and the
// returned session commit together. Callers own commit/rollback.
func (m *SQLManager) IssuePairInTx(ctx context.Context, tx *sql.Tx, account, key string) (Pair, error) {
	if account == "" || key == "" || len(key) > 256 {
		return Pair{}, ErrInvalidToken
	}
	var err error
	var locked string
	if err = tx.QueryRowContext(ctx, `SELECT id FROM accounts WHERE id=$1 FOR UPDATE`, account).Scan(&locked); err != nil {
		return Pair{}, err
	}
	var body []byte
	var revoked, retired sql.NullTime
	err = tx.QueryRowContext(ctx, `SELECT initial_pair,revoked_at,retired_at FROM auth_sessions WHERE account_id=$1 AND issue_key=$2`, account, key).Scan(&body, &revoked, &retired)
	if err == nil {
		if retired.Valid {
			return Pair{}, ErrTokenExpired
		}
		if revoked.Valid {
			return Pair{}, ErrTokenRevoked
		}
		var p pairClaims
		if err = json.Unmarshal(body, &p); err != nil {
			return Pair{}, err
		}
		if time.Now().Unix() >= p.Refresh.ExpiresAt {
			return Pair{}, ErrTokenExpired
		}
		return m.encode(p)
	}
	if !errors.Is(err, sql.ErrNoRows) {
		return Pair{}, err
	}
	session, err := generateID()
	if err != nil {
		return Pair{}, err
	}
	p, err := m.newClaims(account, session, "player")
	if err != nil {
		return Pair{}, err
	}
	body, err = json.Marshal(p)
	if err != nil {
		return Pair{}, err
	}
	if _, err = tx.ExecContext(ctx, `INSERT INTO auth_sessions(id,account_id,issue_key,role,initial_pair) VALUES($1,$2,$3,$4,$5)`, session, account, key, "player", body); err != nil {
		return Pair{}, err
	}
	if err = m.storeRefresh(ctx, tx, p); err != nil {
		return Pair{}, err
	}
	return m.encode(p)
}
func (m *SQLManager) parse(token string, kind TokenKind, allowExpired bool) (Claims, error) {
	if len(token) > 4096 {
		return Claims{}, ErrInvalidToken
	}
	c, err := m.codec.parse(token)
	if err != nil {
		return Claims{}, err
	}
	if c.Kind != kind || c.AccountID == "" || c.SessionID == "" || c.TokenID == "" || c.IssuedAt <= 0 || c.ExpiresAt <= c.IssuedAt || c.IssuedAt > time.Now().Unix()+30 {
		return Claims{}, ErrInvalidToken
	}
	if !allowExpired && time.Now().Unix() >= c.ExpiresAt {
		return Claims{}, ErrTokenExpired
	}
	return c, nil
}
func (m *SQLManager) Verify(ctx context.Context, token string) (Claims, error) {
	c, err := m.parse(token, KindAccess, false)
	if err != nil {
		return Claims{}, err
	}
	var account, role string
	var revoked sql.NullTime
	err = m.db.QueryRowContext(ctx, `SELECT account_id,role,revoked_at FROM auth_sessions WHERE id=$1`, c.SessionID).Scan(&account, &role, &revoked)
	if errors.Is(err, sql.ErrNoRows) {
		return Claims{}, ErrInvalidToken
	}
	if err != nil {
		return Claims{}, err
	}
	if revoked.Valid {
		return Claims{}, ErrTokenRevoked
	}
	if c.AccountID != account || c.Role != role {
		return Claims{}, ErrInvalidToken
	}
	return c, nil
}
func (m *SQLManager) Rotate(ctx context.Context, token, key string) (Pair, error) {
	c, err := m.parse(token, KindRefresh, false)
	if err != nil {
		return Pair{}, err
	}
	if key == "" || len(key) > 128 {
		return Pair{}, ErrInvalidToken
	}
	tx, err := m.db.BeginTx(ctx, nil)
	if err != nil {
		return Pair{}, err
	}
	defer tx.Rollback()
	var account, role string
	var revoked sql.NullTime
	if err = tx.QueryRowContext(ctx, `SELECT account_id,role,revoked_at FROM auth_sessions WHERE id=$1 FOR UPDATE`, c.SessionID).Scan(&account, &role, &revoked); err != nil {
		return Pair{}, err
	}
	if revoked.Valid {
		return Pair{}, ErrTokenRevoked
	}
	if c.AccountID != account || c.Role != role {
		return Pair{}, ErrInvalidToken
	}
	var digest, body []byte
	var consumed sql.NullString
	var expiry time.Time
	if err = tx.QueryRowContext(ctx, `SELECT token_digest,expires_at,consumed_key,replacement_pair FROM refresh_tokens WHERE token_id=$1 AND session_id=$2 FOR UPDATE`, c.TokenID, c.SessionID).Scan(&digest, &expiry, &consumed, &body); err != nil {
		return Pair{}, err
	}
	want := sha256.Sum256([]byte(token))
	if !hmac.Equal(digest, want[:]) {
		return Pair{}, ErrInvalidToken
	}
	// Recheck actual wall clock after locks, not the transaction start timestamp.
	if !time.Now().Before(expiry) {
		return Pair{}, ErrTokenExpired
	}
	if consumed.Valid {
		if consumed.String != key {
			return Pair{}, ErrTokenRevoked
		}
		var p pairClaims
		if err = json.Unmarshal(body, &p); err != nil {
			return Pair{}, err
		}
		return m.encode(p)
	}
	p, err := m.newClaims(account, c.SessionID, role)
	if err != nil {
		return Pair{}, err
	}
	body, err = json.Marshal(p)
	if err != nil {
		return Pair{}, err
	}
	if err = m.storeRefresh(ctx, tx, p); err != nil {
		return Pair{}, err
	}
	if _, err = tx.ExecContext(ctx, `UPDATE refresh_tokens SET consumed_key=$2,replacement_pair=$3 WHERE token_id=$1`, c.TokenID, key, body); err != nil {
		return Pair{}, err
	}
	if err = tx.Commit(); err != nil {
		return Pair{}, err
	}
	return m.encode(p)
}

// Logout permits an already revoked signed access token only for repeating the
// same revocation. It never authorizes another route or creates a new session.
func (m *SQLManager) Logout(ctx context.Context, token string) error {
	c, err := m.parse(token, KindAccess, true)
	if err != nil {
		return err
	}
	result, err := m.db.ExecContext(ctx, `UPDATE auth_sessions SET revoked_at=COALESCE(revoked_at,clock_timestamp()) WHERE id=$1 AND account_id=$2 AND role=$3`, c.SessionID, c.AccountID, c.Role)
	if err != nil {
		return err
	}
	n, err := result.RowsAffected()
	if err == nil && n != 1 {
		return ErrInvalidToken
	}
	return err
}
func (m *SQLManager) RevokeAccount(ctx context.Context, account string) error {
	_, err := m.db.ExecContext(ctx, `UPDATE auth_sessions SET revoked_at=COALESCE(revoked_at,clock_timestamp()) WHERE account_id=$1`, account)
	return err
}
