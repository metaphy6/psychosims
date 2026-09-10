// Package receipts implements Phase 3.3 session receipt validation:
// verify-in-place signature checking, plausibility bounds, ledger conservation,
// idempotent dedupe, and atomic profile/ledger/ownership mutation.
package receipts

import (
	"bytes"
	"context"
	"crypto/ed25519"
	"crypto/sha256"
	"database/sql"
	"encoding/hex"
	"encoding/json"
	"fmt"
	"time"

	"psychosims.dev/server/internal/api"
	"psychosims.dev/server/internal/audit"
	"psychosims.dev/server/internal/canonicaljson"
	"psychosims.dev/server/internal/config"
	"psychosims.dev/server/internal/crypto"
	"psychosims.dev/server/internal/ctxutil"
	"psychosims.dev/server/internal/devicekeys"
	"psychosims.dev/server/internal/idempotency"
	"psychosims.dev/server/internal/outcomes"
	"psychosims.dev/server/internal/profile"
	"psychosims.dev/server/internal/ruleset"
	"psychosims.dev/server/internal/schemas"
)

// LedgerAppender records ledger events inside a receipt transaction.
type LedgerAppender interface {
	Append(ctx context.Context, tx *sql.Tx, accountID string, events []schemas.LedgerEvent) error
}

// Validator validates signed session receipts.
type Validator struct {
	verifier     *crypto.Verifier
	profileRepo  profile.Repository
	ledger       LedgerAppender
	idempotency  *idempotency.Service
	deviceKeySvc *devicekeys.Service
	cfg          *Limits
	ruleset      *ruleset.Registry
}

// WithRuleset attaches a ruleset registry so the validator can reject unknown
// or sunset versions.
func (v *Validator) WithRuleset(r *ruleset.Registry) *Validator {
	v.ruleset = r
	return v
}

// Limits bounds per-receipt validation.
type Limits struct {
	MaxActions      int
	MaxDeltas       int
	MaxLedgerEvents int
	MaxDeltaMillis  int
	MinDeltaMillis  int
}

// DefaultLimits returns production validation bounds.
func DefaultLimits() Limits {
	return Limits{
		MaxActions:      schemas.MaxReceiptActions,
		MaxDeltas:       schemas.MaxReceiptDeltas,
		MaxLedgerEvents: 64,
		MaxDeltaMillis:  1000,
		MinDeltaMillis:  -1000,
	}
}

// NewValidator builds a receipt validator.
func NewVerifier(
	verifier *crypto.Verifier,
	profileRepo profile.Repository,
	ledger LedgerAppender,
	idem *idempotency.Service,
	deviceKeySvc *devicekeys.Service,
	cfg *Limits,
) *Validator {
	return &Validator{
		verifier:     verifier,
		profileRepo:  profileRepo,
		ledger:       ledger,
		idempotency:  idem,
		deviceKeySvc: deviceKeySvc,
		cfg:          cfg,
	}
}

// ValidateRequest is the incoming receipt validation request.
type ValidateRequest struct {
	AccountID string                 `json:"account_id"`
	Envelope  schemas.SignedEnvelope `json:"envelope"`
}

// Validate checks a signed envelope and, on acceptance, returns the parsed
// receipt for the caller to commit atomically.
func (v *Validator) Validate(ctx context.Context, accountID string, env schemas.SignedEnvelope) (*schemas.SessionReceipt, error) {
	// Canonical bytes have their own protocol cap, independent of HTTP/base64
	// envelope budgets. Reject before signature lookup, SQL or JSON parsing.
	if len(env.CanonicalReceiptBytes) > schemas.MaxCanonicalReceiptBytes {
		return nil, api.NewPayloadTooLarge(schemas.MaxCanonicalReceiptBytes)
	}
	if accountID == "" {
		return nil, api.NewUnauthorized("account id required")
	}

	// 1. Verify signature over exact received bytes before parsing enforced fields.
	if err := v.verifier.VerifyEnvelopeContext(ctx, env); err != nil {
		return nil, err
	}

	// 2. Verify signer is registered to this account.
	_, err := v.deviceKeySvc.ResolveForAccount(ctx, accountID, env.SigningKeyID)
	if err != nil {
		return nil, err
	}

	// 3. Parse the receipt defensively.
	var receipt schemas.SessionReceipt
	if err := canonicaljson.DecodeInto(env.CanonicalReceiptBytes, &receipt); err != nil {
		return nil, api.NewMalformedPayload("invalid receipt")
	}
	if err := validateStructuredFields(receipt); err != nil {
		return nil, err
	}

	// 4. Schema version and idempotency checks.
	if receipt.SchemaVersion != schemas.CurrentReceiptSchemaVersion {
		return nil, api.NewUserError(api.CodeUnknownRuleset, "unsupported receipt schema version")
	}
	if v.ruleset != nil {
		if !v.ruleset.IsKnown(receipt.RulesetVersion) {
			return nil, api.NewUserError(api.CodeUnknownRuleset, "unknown ruleset version")
		}
		if v.ruleset.IsSunset(receipt.RulesetVersion, time.Now().UTC()) {
			return nil, api.NewUserError(api.CodeSunsetRuleset, "ruleset version is sunset")
		}
	}
	if receipt.IdempotencyKey == "" {
		return nil, api.NewUserError(api.CodeBadRequest, "receipt missing idempotency key")
	}

	// 5. Structural bounds.
	if len(receipt.Actions) > v.cfg.MaxActions || len(receipt.Actions) > schemas.MaxReceiptActions {
		return nil, api.NewUserError(api.CodeOutOfBounds, "too many actions")
	}
	if len(receipt.Deltas) > v.cfg.MaxDeltas || len(receipt.Deltas) > schemas.MaxReceiptDeltas {
		return nil, api.NewUserError(api.CodeOutOfBounds, "too many deltas")
	}
	if len(receipt.LedgerEvents) > v.cfg.MaxLedgerEvents {
		return nil, api.NewUserError(api.CodeOutOfBounds, "too many ledger events")
	}

	// 6. Loadout membership: every action references a card in the start-state library.
	owned := make(map[string]bool)
	for _, cid := range receipt.StartState.Library.OwnedCardIds {
		owned[cid] = true
	}
	for _, action := range receipt.Actions {
		if !owned[string(action)] {
			return nil, api.NewUserError(api.CodeInvalidLedger, "action references unowned card")
		}
	}

	// 7. Delta plausibility bounds.
	for _, d := range receipt.Deltas {
		if d.DeltaMillis > v.cfg.MaxDeltaMillis || d.DeltaMillis < v.cfg.MinDeltaMillis {
			return nil, api.NewUserError(api.CodeOutOfBounds, fmt.Sprintf("delta %d out of bounds", d.DeltaMillis))
		}
	}

	// 8. Ledger conservation: sum of all event amounts must be zero per currency.
	if err := checkLedgerConservation(receipt.LedgerEvents); err != nil {
		return nil, err
	}

	return &receipt, nil
}

// checkLedgerConservation verifies no currency is minted or destroyed.
func checkLedgerConservation(events []schemas.LedgerEvent) error {
	sums := make(map[schemas.CurrencyType]int64)
	for _, ev := range events {
		sums[ev.Currency] += int64(ev.AmountMicros)
	}
	for _, sum := range sums {
		if sum != 0 {
			return api.NewUserError(api.CodeInvalidLedger, "ledger not conserved")
		}
	}
	return nil
}

// Service wires the validator to the atomic commit path.
type Service struct {
	validator      *Validator
	store          *sql.DB
	idempotency    *idempotency.Service
	auditor        audit.Appender
	signals        SignalStore
	outcomes       *outcomes.Catalog
	rewardPolicy   config.CureRewardPolicy
	rewardsEnabled bool
}

// NewService builds the receipt service.
func NewService(validator *Validator, store *sql.DB, idem *idempotency.Service, auditor audit.Appender, signals SignalStore) *Service {
	return &Service{validator: validator, store: store, idempotency: idem, auditor: auditor, signals: signals}
}

// Submit validates and atomically commits a receipt, recording every outcome on
// the audit trail. Unprocessable receipts are sent to the dead-letter path
// (recorded reason + structured error) instead of being silently dropped.
func (s *Service) Submit(ctx context.Context, accountID string, env schemas.SignedEnvelope) (accepted *schemas.SessionReceipt, submitErr error) {
	// Registered before the transaction's rollback defer: every rejection is
	// audited only after its reservation and any mutations release their locks.
	defer func() {
		if submitErr != nil {
			s.recordDeadLetter(ctx, accountID, env, submitErr)
		}
	}()
	receipt, err := s.validator.Validate(ctx, accountID, env)
	if err != nil {
		return nil, err
	}
	if ctxAccount := ctxutil.AccountID(ctx); ctxAccount != "" && ctxAccount != accountID {
		return nil, api.NewUnauthorized("account context mismatch")
	}
	if k := ctxutil.IdempotencyKey(ctx); k != "" && k != receipt.IdempotencyKey {
		return nil, api.NewUserError(api.CodeBadRequest, "idempotency header does not match receipt")
	}
	if receipt.ID == "" || receipt.PatientID == "" || receipt.TurnCount < 1 || receipt.TurnCount != len(receipt.Actions) {
		return nil, api.NewUserError(api.CodeBadRequest, "invalid receipt identity or turn count")
	}
	// 0.3 has no verifiable terminal outcome contract. A conserved client ledger
	// still cannot authorize earnings or sinks; hold rewards until server rules
	// can derive them from supported terminal evidence.
	if len(receipt.LedgerEvents) != 0 {
		return nil, api.NewUserError(api.CodeInvalidLedger, "schema 0.3 receipts cannot authorize economy mutations")
	}
	if s.store == nil || s.auditor == nil || s.idempotency == nil {
		return nil, api.NewServiceUnavailable("receipt persistence not configured")
	}
	tx, err := s.store.BeginTx(ctx, nil)
	if err != nil {
		return nil, err
	}
	defer tx.Rollback()
	hash := sha256.Sum256(env.CanonicalReceiptBytes)
	execute, err := s.idempotency.BeginInTx(ctx, tx, accountID, receipt.IdempotencyKey, hash[:])
	if err != nil {
		return nil, err
	}
	if !execute {
		return receipt, nil
	}
	profRepo := profile.NewSQLRepositoryTx(tx)
	prof, err := profRepo.Get(ctx, accountID)
	if err != nil {
		return nil, err
	}
	var patient, rules, certificateID, catalogHash string
	var expected, previous []byte
	var version int
	var expires time.Time
	var consumed sql.NullTime
	err = tx.QueryRowContext(ctx, `SELECT patient_id,ruleset_version,start_state_hash,ownership_version,expires_at,consumed_at,receipt_hash,certificate_id,catalog_sha256
	        FROM session_authorizations WHERE id=$1 AND account_id=$2 FOR UPDATE`, receipt.ID, accountID).Scan(&patient, &rules, &expected, &version, &expires, &consumed, &previous, &certificateID, &catalogHash)
	if err == sql.ErrNoRows {
		return nil, api.NewConflict(api.CodeConflict, "server session authorization required")
	}
	if err != nil {
		return nil, err
	}
	if consumed.Valid {
		if !bytes.Equal(hash[:], previous) {
			return nil, api.NewConflict(api.CodeConflict, "session already consumed by another receipt")
		}
		// Even after short-lived deduplication GC, the permanent authorization
		// remains a receipt tombstone and restores the cache without paying again.
		if err = tx.Commit(); err != nil {
			return nil, err
		}
		return receipt, nil
	}
	if patient != receipt.PatientID || rules != receipt.RulesetVersion {
		return nil, api.NewConflict(api.CodeConflict, "receipt differs from session authorization")
	}
	startBytes, err := canonicaljson.Marshal(receipt.StartState)
	if err != nil {
		return nil, err
	}
	startHash := sha256.Sum256(startBytes)
	if !bytes.Equal(expected, startHash[:]) {
		return nil, api.NewConflict(api.CodeConflict, "receipt start state differs from authorization")
	}
	if err = validateEntitlements(prof, receipt.StartState, receipt.Actions); err != nil {
		return nil, err
	}
	currentVersion, leaseExpires, err := checkOwnership(ctx, tx, accountID, receipt.PatientID)
	if err != nil {
		return nil, err
	}
	if currentVersion != version {
		return nil, api.NewConflict(api.CodeConflict, "ownership changed since session authorization")
	}
	if err := requireUnexpired(ctx, tx, expires, "session authorization expired"); err != nil {
		return nil, err
	}
	if s.validator.ledger != nil {
		if err = s.validator.ledger.Append(ctx, tx, accountID, receipt.LedgerEvents); err != nil {
			return nil, err
		}
	}
	verdict, err := s.applyCertified(ctx, tx, prof, receipt, certificateID, catalogHash)
	if err != nil {
		return nil, err
	}
	if err = profRepo.Update(ctx, prof); err != nil {
		return nil, err
	}
	verdict.ProfileVersion = prof.Version
	verdictBytes, err := json.Marshal(verdict)
	if err != nil {
		return nil, err
	}
	// Authenticate exact wire bytes above, but retain only supported structured
	// fields. Additive unknown fields may contain dialogue and are not durable data.
	structured, err := canonicaljson.Marshal(receipt)
	if err != nil {
		return nil, err
	}
	if _, err = tx.ExecContext(ctx, `UPDATE session_authorizations SET consumed_at=clock_timestamp(),receipt_hash=$1,receipt_bytes=$2,accepted_verdict=$4 WHERE id=$3`, hash[:], structured, receipt.ID, verdictBytes); err != nil {
		return nil, err
	}
	if err = s.auditor.Append(ctx, tx, audit.Record{AccountID: accountID, CorrelationID: receipt.CorrelationID, Action: "receipt_accept", EntityType: "receipt", EntityID: receipt.ID, Outcome: "accepted"}); err != nil {
		return nil, err
	}
	// The audit append may itself wait on another writer. Recheck after all
	// potentially blocking writes so lock contention cannot extend acceptance.
	deadline := expires
	if leaseExpires.Before(deadline) {
		deadline = leaseExpires
	}
	if err := requireUnexpired(ctx, tx, deadline, "session lease expired before acceptance"); err != nil {
		return nil, err
	}
	if err = tx.Commit(); err != nil {
		return nil, api.NewInternalError("receipt commit failed")
	}
	// Telemetry is non-authoritative and emitted only after durable acceptance.
	if s.signals != nil {
		_ = s.signals.Record(ctx, deriveSignals(accountID, *receipt))
	}
	return receipt, nil
}

func (s *Service) recordDeadLetter(ctx context.Context, accountID string, env schemas.SignedEnvelope, reason error) {
	if s.auditor == nil {
		return
	}
	correlationID := ctxutil.CorrelationID(ctx)
	if !schemas.ValidIdentifier(correlationID) {
		correlationID = ""
	}
	outcome := string(api.CodeInternalError)
	if he, ok := reason.(api.HTTPError); ok {
		outcome = string(he.Body.Code)
	}
	wireHash := sha256.Sum256(env.CanonicalReceiptBytes)
	_ = s.auditor.AppendDirect(ctx, audit.Record{
		AccountID:     accountID,
		CorrelationID: correlationID,
		Action:        "receipt_reject",
		EntityType:    "receipt",
		EntityID:      hex.EncodeToString(wireHash[:]),
		Outcome:       outcome,
	})
}

// NewVerifierFromDeviceKeys builds a crypto.Verifier that resolves keys via the device-key service.
func NewVerifierFromDeviceKeys(svc *devicekeys.Service) *crypto.Verifier {
	return crypto.NewContextVerifier(func(ctx context.Context, signingKeyID string) (ed25519.PublicKey, error) {
		rec, err := svc.Lookup(ctx, signingKeyID)
		if err != nil {
			return nil, err
		}
		if rec == nil {
			return nil, crypto.ErrKeyNotFound
		}
		return rec.PublicKey, nil
	})
}
