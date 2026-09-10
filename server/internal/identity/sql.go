package identity

import (
	"bytes"
	"context"
	"crypto/sha256"
	"database/sql"
	"encoding/json"
	"errors"

	"psychosims.dev/server/internal/api"
	"psychosims.dev/server/internal/ctxutil"
)

// SQLRepository binds provider subjects to accounts without storing email or tokens.
type SQLRepository struct{ db *sql.DB }

func NewSQLRepository(db *sql.DB) *SQLRepository { return &SQLRepository{db: db} }
func (r *SQLRepository) FindByProvider(ctx context.Context, provider, subject string) (string, error) {
	var id string
	err := r.db.QueryRowContext(ctx, `SELECT account_id FROM provider_identities WHERE provider=$1 AND subject=$2`, provider, subject).Scan(&id)
	if errors.Is(err, sql.ErrNoRows) {
		return "", nil
	}
	return id, err
}
func (r *SQLRepository) CreateAccount(ctx context.Context) (string, error) {
	id, err := generateAccountID()
	if err != nil {
		return "", err
	}
	_, err = r.db.ExecContext(ctx, `INSERT INTO accounts(id) VALUES($1)`, id)
	return id, err
}
func (r *SQLRepository) GetAccount(ctx context.Context, id string) (*Account, error) {
	a := &Account{}
	err := r.db.QueryRowContext(ctx, `SELECT id,created_at,updated_at FROM accounts WHERE id=$1`, id).Scan(&a.ID, &a.CreatedAt, &a.UpdatedAt)
	return a, err
}
func (r *SQLRepository) LinkProvider(ctx context.Context, account string, p ProviderIdentity) error {
	result, err := r.db.ExecContext(ctx, `INSERT INTO provider_identities(provider,subject,account_id) VALUES($1,$2,$3) ON CONFLICT(provider,subject) DO UPDATE SET account_id=provider_identities.account_id WHERE provider_identities.account_id=EXCLUDED.account_id`, p.Provider, p.ProviderID, account)
	if err != nil {
		return err
	}
	n, err := result.RowsAffected()
	if err == nil && n == 0 {
		return api.NewConflict(api.CodeConflict, "provider identity already linked to another account")
	}
	return err
}

// ResolveVerified serializes a provider subject before creation so concurrent
// first sign-ins cannot leave orphan accounts or race account linking.
func (r *SQLRepository) ResolveVerified(ctx context.Context, p ProviderIdentity) (string, error) {
	tx, err := r.db.BeginTx(ctx, nil)
	if err != nil {
		return "", err
	}
	defer tx.Rollback()
	id, err := ResolveVerifiedInTx(ctx, tx, p)
	if err != nil {
		return "", err
	}
	return id, tx.Commit()
}

// ResolveVerifiedInTx creates or reads a verified identity inside the caller's
// transaction. It never accepts an unverified HTTP account identifier.
func ResolveVerifiedInTx(ctx context.Context, tx *sql.Tx, p ProviderIdentity) (string, error) {
	if p.ProviderID == "" || len(p.ProviderID) > 255 {
		return "", api.NewUnauthorized("invalid provider subject")
	}
	var err error
	if _, err = tx.ExecContext(ctx, `SELECT pg_advisory_xact_lock(hashtextextended($1,736003))`, providerKey(p.Provider, p.ProviderID)); err != nil {
		return "", err
	}
	var id string
	err = tx.QueryRowContext(ctx, `SELECT account_id FROM provider_identities WHERE provider=$1 AND subject=$2`, p.Provider, p.ProviderID).Scan(&id)
	if errors.Is(err, sql.ErrNoRows) {
		id, err = generateAccountID()
		if err != nil {
			return "", err
		}
		if _, err = tx.ExecContext(ctx, `INSERT INTO accounts(id) VALUES($1)`, id); err != nil {
			return "", err
		}
		if _, err = tx.ExecContext(ctx, `INSERT INTO provider_identities(provider,subject,account_id) VALUES($1,$2,$3)`, p.Provider, p.ProviderID, id); err != nil {
			return "", err
		}
	} else if err != nil {
		return "", err
	}
	return id, nil
}

// SQLStateStore keeps browser handshakes across process restarts. Consume is a
// single DELETE RETURNING, so only one caller can exchange a state.
type SQLStateStore struct{ db *sql.DB }

func NewSQLStateStore(db *sql.DB) *SQLStateStore { return &SQLStateStore{db: db} }
func (s *SQLStateStore) Create(ctx context.Context, session AuthSession) error {
	body, err := json.Marshal(session)
	if err != nil {
		return err
	}
	_, err = s.db.ExecContext(ctx, `INSERT INTO oauth_states(state,payload,expires_at) VALUES($1,$2,$3)`, session.State, body, session.ExpiresAt)
	return err
}
func (s *SQLStateStore) Peek(ctx context.Context, state string) (*AuthSession, error) {
	return s.read(ctx, `SELECT payload FROM oauth_states WHERE state=$1 AND expires_at>clock_timestamp()`, state)
}
func (s *SQLStateStore) Consume(ctx context.Context, state string) (*AuthSession, error) {
	return s.read(ctx, `DELETE FROM oauth_states WHERE state=$1 AND expires_at>clock_timestamp() RETURNING payload`, state)
}
func (s *SQLStateStore) read(ctx context.Context, query, state string) (*AuthSession, error) {
	var b []byte
	if err := s.db.QueryRowContext(ctx, query, state).Scan(&b); err != nil {
		return nil, err
	}
	var session AuthSession
	if err := json.Unmarshal(b, &session); err != nil {
		return nil, err
	}
	return &session, nil
}

// CreateOrReplay preserves the nonce/state after a lost HTTP response. A start
// key is bound to its provider, redirect and PKCE challenge, never to an IP.
func (s *SQLStateStore) CreateOrReplay(ctx context.Context, session AuthSession) (AuthSession, error) {
	operation := ctxutil.IdempotencyKey(ctx)
	if operation == "" {
		return session, s.Create(ctx, session)
	}
	body, _ := json.Marshal(struct{ Provider, Redirect, Challenge, Method string }{session.Provider, session.RedirectURI, session.CodeChallenge, session.CodeChallengeMethod})
	hash := sha256.Sum256(body)
	tx, err := s.db.BeginTx(ctx, nil)
	if err != nil {
		return AuthSession{}, err
	}
	defer tx.Rollback()
	if _, err = tx.ExecContext(ctx, `SELECT pg_advisory_xact_lock(hashtextextended($1,736005))`, operation); err != nil {
		return AuthSession{}, err
	}
	var storedHash []byte
	var state string
	err = tx.QueryRowContext(ctx, `SELECT request_hash,state FROM oauth_start_requests WHERE operation_key=$1`, operation).Scan(&storedHash, &state)
	if err == nil {
		if !bytes.Equal(storedHash, hash[:]) {
			return AuthSession{}, api.NewConflict(api.CodeConflict, "authorization start key already used differently")
		}
		var payload []byte
		if err = tx.QueryRowContext(ctx, `SELECT payload FROM oauth_states WHERE state=$1 AND expires_at>clock_timestamp()`, state).Scan(&payload); errors.Is(err, sql.ErrNoRows) {
			return AuthSession{}, api.NewConflict(api.CodeConflict, "authorization start already consumed or expired; start a new operation")
		}
		if err != nil {
			return AuthSession{}, err
		}
		err = json.Unmarshal(payload, &session)
		return session, err
	}
	if !errors.Is(err, sql.ErrNoRows) {
		return AuthSession{}, err
	}
	payload, _ := json.Marshal(session)
	if _, err = tx.ExecContext(ctx, `INSERT INTO oauth_states(state,payload,expires_at) VALUES($1,$2,$3)`, session.State, payload, session.ExpiresAt); err != nil {
		return AuthSession{}, err
	}
	if _, err = tx.ExecContext(ctx, `INSERT INTO oauth_start_requests(operation_key,request_hash,state) VALUES($1,$2,$3)`, operation, hash[:], session.State); err != nil {
		return AuthSession{}, err
	}
	return session, tx.Commit()
}
