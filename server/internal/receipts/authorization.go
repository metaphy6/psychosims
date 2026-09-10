package receipts

import (
	"bytes"
	"context"
	"crypto/sha256"
	"database/sql"
	"encoding/json"
	"time"

	"psychosims.dev/server/internal/api"
	"psychosims.dev/server/internal/canonicaljson"
	"psychosims.dev/server/internal/ctxutil"
	"psychosims.dev/server/internal/profile"
	"psychosims.dev/server/internal/schemas"
)

// Authorization binds a server-selected case start to an account and a live lease.
// ID is used unchanged as SessionReceipt.ID; no receipt schema change is needed.
// Schema 0.3 lacks verifiable terminal evidence, so acceptance awards no currency.
type Authorization struct {
	ID             string                    `json:"id"`
	PatientID      string                    `json:"patient_id"`
	RulesetVersion string                    `json:"ruleset_version"`
	StartState     schemas.SessionStartState `json:"start_state"`
	ExpiresAt      time.Time                 `json:"expires_at"`
	CertificateID  string                    `json:"certificate_id,omitempty"`
	CatalogSHA256  string                    `json:"catalog_sha256,omitempty"`
}

// Authorize is an internal trusted routing seam. Its start state must come from
// the server's case catalog, never be forwarded verbatim from an HTTP caller.
func (s *Service) Authorize(ctx context.Context, accountID, patientID, ruleset string, start schemas.SessionStartState) (*Authorization, error) {
	return s.authorize(ctx, accountID, patientID, ruleset, start, nil, "")
}

// AuthorizeRequest atomically binds a public start operation to its original
// response, including after its receipt was consumed. requestHash hashes only
// the bounded caller request, not mutable profile or lease state.
func (s *Service) AuthorizeRequest(ctx context.Context, accountID, patientID, ruleset string, start schemas.SessionStartState, requestHash []byte) (*Authorization, error) {
	return s.authorize(ctx, accountID, patientID, ruleset, start, requestHash, "")
}

// ReplayAuthorization resolves an authenticated operation before mutable catalog,
// inventory or ownership checks. A cured case cannot invalidate its original
// successful start response; retired operations retain a durable refusal marker.
func (s *Service) ReplayAuthorization(ctx context.Context, accountID string, requestHash []byte) (*Authorization, error) {
	key := ctxutil.IdempotencyKey(ctx)
	if accountID == "" {
		return nil, api.NewUnauthorized("account id required")
	}
	if key == "" || len(requestHash) != 32 {
		return nil, api.NewUserError(api.CodeBadRequest, "invalid session request identity")
	}
	var stored, body []byte
	var retired sql.NullTime
	err := s.store.QueryRowContext(ctx, `SELECT request_hash,response_payload,retired_at FROM session_start_requests WHERE account_id=$1 AND operation_key=$2`, accountID, key).Scan(&stored, &body, &retired)
	if err == sql.ErrNoRows {
		return nil, nil
	}
	if err != nil {
		return nil, err
	}
	if !bytes.Equal(stored, requestHash) {
		return nil, api.NewConflict(api.CodeConflict, "session request key already used differently")
	}
	if retired.Valid {
		return nil, api.NewConflict(api.CodeConflict, "session request retired; begin a new operation")
	}
	var result Authorization
	if err = json.Unmarshal(body, &result); err != nil {
		return nil, err
	}
	return &result, nil
}

// AuthorizeCertifiedRequest is operator-catalog-only, never a client certificate.
func (s *Service) AuthorizeCertifiedRequest(ctx context.Context, accountID, patientID, ruleset string, start schemas.SessionStartState, requestHash []byte, certificateID string) (*Authorization, error) {
	return s.authorize(ctx, accountID, patientID, ruleset, start, requestHash, certificateID)
}
func (s *Service) authorize(ctx context.Context, accountID, patientID, ruleset string, start schemas.SessionStartState, requestHash []byte, certificateID string) (*Authorization, error) {
	if accountID == "" {
		return nil, api.NewUnauthorized("account id required")
	}
	if s.validator.ruleset == nil || !s.validator.ruleset.IsKnown(ruleset) || s.validator.ruleset.IsSunset(ruleset, time.Now().UTC()) {
		return nil, api.NewUserError(api.CodeUnknownRuleset, "ruleset unavailable")
	}
	tx, err := s.store.BeginTx(ctx, nil)
	if err != nil {
		return nil, err
	}
	defer tx.Rollback()
	prof, err := profile.NewSQLRepositoryTx(tx).Get(ctx, accountID)
	if err != nil {
		return nil, err
	}
	key := ctxutil.IdempotencyKey(ctx)
	if len(requestHash) > 0 {
		if key == "" || len(requestHash) != 32 {
			return nil, api.NewUserError(api.CodeBadRequest, "invalid session request identity")
		}
		var storedHash, body []byte
		var retired sql.NullTime
		err := tx.QueryRowContext(ctx, `SELECT request_hash,response_payload,retired_at FROM session_start_requests WHERE account_id=$1 AND operation_key=$2`, accountID, key).Scan(&storedHash, &body, &retired)
		if err == nil {
			if !bytes.Equal(storedHash, requestHash) {
				return nil, api.NewConflict(api.CodeConflict, "session request key already used differently")
			}
			if retired.Valid {
				return nil, api.NewConflict(api.CodeConflict, "session request retired; begin a new operation")
			}
			var result Authorization
			if err := json.Unmarshal(body, &result); err != nil {
				return nil, err
			}
			return &result, nil
		}
		if err != sql.ErrNoRows {
			return nil, err
		}
	}
	if err := validateEntitlements(prof, start, nil); err != nil {
		return nil, err
	}
	catalogHash := ""
	if certificateID != "" {
		if s.outcomes == nil {
			return nil, api.NewConflict(api.CodeConflict, "certified catalog unavailable")
		}
		permit, ok := s.outcomes.Select(start.CaseID, start.ManifestChecksum, ruleset, start.Loadout.CardIds, prof.OwnedCardIDs, start.InitialAxes, start.Controllers)
		candidate, _ := canonicaljson.Marshal(permit.StartState)
		actual, _ := canonicaljson.Marshal(start)
		if !ok || permit.ProofID != certificateID || !bytes.Equal(candidate, actual) {
			return nil, api.NewConflict(api.CodeConflict, "certified start unavailable")
		}
		catalogHash = s.outcomes.ArtifactSHA256()
	}
	// Match Submit's grant-before-ownership lock order, including grants held
	// by an old owner, so renewing stale grants cannot deadlock acceptance.
	var pendingID string
	err = tx.QueryRowContext(ctx, `SELECT id FROM session_authorizations WHERE patient_id=$1 AND consumed_at IS NULL FOR UPDATE`, patientID).Scan(&pendingID)
	if err != nil && err != sql.ErrNoRows {
		return nil, err
	}
	version, expires, err := checkOwnership(ctx, tx, accountID, patientID)
	if err != nil {
		return nil, err
	}
	canon, err := canonicaljson.Marshal(start)
	if err != nil {
		return nil, err
	}
	hash := sha256.Sum256(canon)
	// A previous owner, lease generation or expired grant must not reserve the
	// active slot. Consumed grants remain permanent deduplication evidence.
	if _, err = tx.ExecContext(ctx, `DELETE FROM session_authorizations WHERE patient_id=$1 AND consumed_at IS NULL
        AND (expires_at<=clock_timestamp() OR account_id<>$2 OR ownership_version<>$3)`, patientID, accountID, version); err != nil {
		return nil, err
	}
	var a Authorization
	var oldHash []byte
	err = tx.QueryRowContext(ctx, `SELECT id,ruleset_version,start_state_hash,expires_at,certificate_id,catalog_sha256 FROM session_authorizations WHERE patient_id=$1 AND account_id=$2 AND consumed_at IS NULL`, patientID, accountID).Scan(&a.ID, &a.RulesetVersion, &oldHash, &a.ExpiresAt, &a.CertificateID, &a.CatalogSHA256)
	if err == nil {
		if a.RulesetVersion != ruleset || !bytes.Equal(hash[:], oldHash) || a.CertificateID != certificateID || a.CatalogSHA256 != catalogHash {
			return nil, api.NewConflict(api.CodeConflict, "active session differs; reconcile before starting another")
		}
		a.PatientID = patientID
		a.StartState = start
		if err := storeStartRequest(ctx, tx, accountID, key, requestHash, &a); err != nil {
			return nil, err
		}
		return &a, tx.Commit()
	}
	if err != sql.ErrNoRows {
		return nil, err
	}
	a = Authorization{ID: ctxutil.GenerateID(), PatientID: patientID, RulesetVersion: ruleset, StartState: start, ExpiresAt: expires, CertificateID: certificateID, CatalogSHA256: catalogHash}
	_, err = tx.ExecContext(ctx, `INSERT INTO session_authorizations(id,account_id,patient_id,ownership_version,ruleset_version,start_state_hash,expires_at,certificate_id,catalog_sha256) VALUES($1,$2,$3,$4,$5,$6,$7,$8,$9)`, a.ID, accountID, patientID, version, ruleset, hash[:], expires, certificateID, catalogHash)
	if err != nil {
		return nil, err
	}
	if err := storeStartRequest(ctx, tx, accountID, key, requestHash, &a); err != nil {
		return nil, err
	}
	if err = tx.Commit(); err != nil {
		return nil, err
	}
	return &a, nil
}

func storeStartRequest(ctx context.Context, tx *sql.Tx, account, key string, hash []byte, a *Authorization) error {
	if len(hash) == 0 {
		return nil
	}
	body, err := json.Marshal(a)
	if err != nil {
		return err
	}
	_, err = tx.ExecContext(ctx, `INSERT INTO session_start_requests(account_id,operation_key,request_hash,response_payload) VALUES($1,$2,$3,$4)`, account, key, hash, body)
	return err
}

func checkOwnership(ctx context.Context, tx *sql.Tx, accountID, patientID string) (int, time.Time, error) {
	var owner, state string
	var version int
	var expires sql.NullTime
	err := tx.QueryRowContext(ctx, `SELECT account_id,state,version,lease_expires_at FROM ownership_records WHERE patient_id=$1 FOR UPDATE`, patientID).Scan(&owner, &state, &version, &expires)
	if err == sql.ErrNoRows {
		return 0, time.Time{}, api.NewConflict(api.CodeConflict, "patient not assigned")
	}
	if err != nil {
		return 0, time.Time{}, err
	}
	if owner != accountID || state != "owned" {
		return 0, time.Time{}, api.NewConflict(api.CodeConflict, "patient is not owned by this account")
	}
	if !expires.Valid {
		return 0, time.Time{}, api.NewConflict(api.CodeLeaseExpired, "ownership lease required")
	}
	// NOW() is fixed at transaction start, and even a SELECT projection can be
	// evaluated before FOR UPDATE waits. Read the actual clock after the lock.
	if err := requireUnexpired(ctx, tx, expires.Time, "ownership lease expired"); err != nil {
		return 0, time.Time{}, err
	}
	return version, expires.Time, nil
}

func validateEntitlements(prof *profile.PrimitiveProfile, start schemas.SessionStartState, actions []schemas.InteractionPattern) error {
	owned := map[string]bool{}
	for _, c := range prof.OwnedCardIDs {
		owned[c] = true
	}
	if len(start.Loadout.CardIds) == 0 || len(start.Loadout.CardIds) > 6 || start.Loadout.SlotCap < 1 || start.Loadout.SlotCap > 6 || len(start.Loadout.CardIds) > start.Loadout.SlotCap {
		return api.NewUserError(api.CodeOutOfBounds, "invalid loadout size")
	}
	equipped := map[string]bool{}
	for _, c := range start.Loadout.CardIds {
		if !owned[c] || equipped[c] {
			return api.NewUserError(api.CodeInvalidLedger, "loadout card not entitled or duplicated")
		}
		equipped[c] = true
	}
	for _, c := range start.Library.OwnedCardIds {
		if !owned[c] {
			return api.NewUserError(api.CodeInvalidLedger, "submitted library exceeds authoritative entitlement")
		}
	}
	for _, a := range actions {
		if !equipped[string(a)] {
			return api.NewUserError(api.CodeInvalidLedger, "action is not equipped")
		}
	}
	return nil
}

func requireUnexpired(ctx context.Context, tx *sql.Tx, expires time.Time, message string) error {
	var valid bool
	if err := tx.QueryRowContext(ctx, `SELECT clock_timestamp() < $1`, expires).Scan(&valid); err != nil {
		return err
	}
	if !valid {
		return api.NewConflict(api.CodeLeaseExpired, message)
	}
	return nil
}
