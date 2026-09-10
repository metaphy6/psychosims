package server

import (
	"bytes"
	"context"
	"crypto/sha256"
	"database/sql"
	"encoding/hex"
	"encoding/json"
	"errors"

	"psychosims.dev/server/internal/api"
	"psychosims.dev/server/internal/identity"
	"psychosims.dev/server/internal/tokens"
)

func (s *Server) exchange(ctx context.Context, state, code, verifier, key string) (tokens.Pair, error) {
	requestHash := sha256.Sum256([]byte(state + "\x00" + code + "\x00" + verifier))
	stateHash := sha256.Sum256([]byte(state))
	issueKey := "oauth:" + hex.EncodeToString(stateHash[:])
	tx, err := s.online.db.BeginTx(ctx, nil)
	if err != nil {
		return tokens.Pair{}, err
	}
	defer tx.Rollback()
	// Lock even before the first result exists; parallel retries cannot exchange
	// the one-use provider code twice. No raw code or provider token is persisted.
	if _, err = tx.ExecContext(ctx, `SELECT pg_advisory_xact_lock(hashtextextended($1,736004))`, state); err != nil {
		return tokens.Pair{}, err
	}
	var storedKey, account string
	var storedHash []byte
	err = tx.QueryRowContext(ctx, `SELECT operation_key,request_hash,account_id FROM oauth_exchange_results WHERE state=$1`, state).Scan(&storedKey, &storedHash, &account)
	if err == nil {
		if storedKey != key || !bytes.Equal(storedHash, requestHash[:]) {
			return tokens.Pair{}, api.NewUnauthorized("authorization state already consumed")
		}
		return s.online.tokens.IssuePairInTx(ctx, tx, account, issueKey)
	}
	if !errors.Is(err, sql.ErrNoRows) {
		return tokens.Pair{}, err
	}
	var body []byte
	if err = tx.QueryRowContext(ctx, `SELECT payload FROM oauth_states WHERE state=$1 AND expires_at>clock_timestamp() FOR UPDATE`, state).Scan(&body); err != nil {
		if errors.Is(err, sql.ErrNoRows) {
			err = api.NewUnauthorized("unknown or expired authorization state")
		}
		return tokens.Pair{}, err
	}
	var session identity.AuthSession
	if err = json.Unmarshal(body, &session); err != nil {
		return tokens.Pair{}, err
	}
	verified, err := s.online.identity.VerifyExchange(ctx, session, code, verifier)
	if err != nil {
		return tokens.Pair{}, err
	}
	account, err = identity.ResolveVerifiedInTx(ctx, tx, verified)
	if err != nil {
		return tokens.Pair{}, err
	}
	pair, err := s.online.tokens.IssuePairInTx(ctx, tx, account, issueKey)
	if err != nil {
		return tokens.Pair{}, err
	}
	deleted, err := tx.ExecContext(ctx, `DELETE FROM oauth_states WHERE state=$1 AND expires_at>clock_timestamp()`, state)
	if err != nil {
		return tokens.Pair{}, err
	}
	n, err := deleted.RowsAffected()
	if err != nil {
		return tokens.Pair{}, err
	}
	if n != 1 {
		return tokens.Pair{}, api.NewUnauthorized("authorization state expired during exchange")
	}
	if _, err = tx.ExecContext(ctx, `INSERT INTO oauth_exchange_results(state,operation_key,request_hash,account_id) VALUES($1,$2,$3,$4)`, state, key, requestHash[:], account); err != nil {
		return tokens.Pair{}, err
	}
	if err = tx.Commit(); err != nil {
		return tokens.Pair{}, err
	}
	return pair, nil
}
