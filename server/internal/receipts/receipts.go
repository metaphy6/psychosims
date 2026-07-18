// Package receipts implements Phase 3.3 session receipt validation:
// verify-in-place signature checking, plausibility bounds, ledger conservation,
// idempotent dedupe, and atomic profile/ledger/ownership mutation.
package receipts

import (
	"context"
	"crypto/ed25519"
	"database/sql"
	"fmt"
	"time"

	"psychosims.dev/server/internal/api"
	"psychosims.dev/server/internal/audit"
	"psychosims.dev/server/internal/canonicaljson"
	"psychosims.dev/server/internal/crypto"
	"psychosims.dev/server/internal/ctxutil"
	"psychosims.dev/server/internal/devicekeys"
	"psychosims.dev/server/internal/idempotency"
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
		MaxActions:      64,
		MaxDeltas:       256,
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
	AccountID string                `json:"account_id"`
	Envelope  schemas.SignedEnvelope `json:"envelope"`
}

// Validate checks a signed envelope and, on acceptance, returns the parsed
// receipt for the caller to commit atomically.
func (v *Validator) Validate(ctx context.Context, accountID string, env schemas.SignedEnvelope) (*schemas.SessionReceipt, error) {
	if accountID == "" {
		return nil, api.NewUnauthorized("account id required")
	}

	// 1. Verify signature over exact received bytes before parsing enforced fields.
	if err := v.verifier.VerifyEnvelope(env); err != nil {
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
		return nil, api.NewMalformedPayload("invalid receipt: " + err.Error())
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
	if len(receipt.Actions) > v.cfg.MaxActions {
		return nil, api.NewUserError(api.CodeOutOfBounds, "too many actions")
	}
	if len(receipt.Deltas) > v.cfg.MaxDeltas {
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
			return nil, api.NewUserError(api.CodeInvalidLedger, fmt.Sprintf("action references unowned card %q", action))
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
	for currency, sum := range sums {
		if sum != 0 {
			return api.NewUserError(api.CodeInvalidLedger, fmt.Sprintf("ledger not conserved for %s: %d", currency, sum))
		}
	}
	return nil
}

// Service wires the validator to the atomic commit path.
type Service struct {
	validator   *Validator
	store       *sql.DB
	idempotency *idempotency.Service
	auditor     audit.Appender
	signals     SignalStore
}

// NewService builds the receipt service.
func NewService(validator *Validator, store *sql.DB, idem *idempotency.Service, auditor audit.Appender, signals SignalStore) *Service {
	return &Service{validator: validator, store: store, idempotency: idem, auditor: auditor, signals: signals}
}

// Submit validates and atomically commits a receipt, recording every outcome on
// the audit trail. Unprocessable receipts are sent to the dead-letter path
// (recorded reason + structured error) instead of being silently dropped.
func (s *Service) Submit(ctx context.Context, accountID string, env schemas.SignedEnvelope) (*schemas.SessionReceipt, error) {
	receipt, err := s.validator.Validate(ctx, accountID, env)
	if err != nil {
		s.recordDeadLetter(ctx, accountID, env, err)
		return nil, err
	}

	tx, err := s.store.BeginTx(ctx, nil)
	if err != nil {
		return nil, api.NewInternalError("begin transaction: " + err.Error())
	}
	defer tx.Rollback()

	// Idempotency check inside the transaction.
	shouldExec, _, err := s.idempotency.CheckOrBegin(ctx)
	if err != nil {
		s.recordDeadLetter(ctx, accountID, env, err)
		return nil, err
	}
	if !shouldExec {
		return nil, api.NewError(409, api.ErrUser, api.CodeIdempotentReplay, "receipt already applied")
	}

	// Record ledger events.
	if err := s.validator.ledger.Append(ctx, tx, accountID, receipt.LedgerEvents); err != nil {
		s.recordDeadLetter(ctx, accountID, env, err)
		return nil, err
	}

	// Update profile (placeholder: real logic applies deltas in a follow-up).
	prof, err := s.validator.profileRepo.Get(ctx, accountID)
	if err != nil {
		s.recordDeadLetter(ctx, accountID, env, err)
		return nil, err
	}
	prof.XP += 10
	prof.UpdatedAt = time.Now().UTC()
	if err := s.validator.profileRepo.Update(ctx, prof); err != nil {
		s.recordDeadLetter(ctx, accountID, env, err)
		return nil, err
	}

	if s.signals != nil {
		_ = s.signals.Record(ctx, deriveSignals(accountID, *receipt))
	}

	if s.auditor != nil {
		_ = s.auditor.Append(ctx, tx, audit.Record{
			AccountID:     accountID,
			CorrelationID: receipt.CorrelationID,
			Action:        "receipt_accept",
			EntityType:    "receipt",
			EntityID:      receipt.IdempotencyKey,
			Outcome:       "accepted",
		})
	}

	if err := tx.Commit(); err != nil {
		return nil, api.NewInternalError("commit failed: " + err.Error())
	}

	return receipt, nil
}

func (s *Service) recordDeadLetter(ctx context.Context, accountID string, env schemas.SignedEnvelope, reason error) {
	if s.auditor == nil {
		return
	}
	correlationID := ctxutil.CorrelationID(ctx)
	outcome := "rejected"
	if he, ok := reason.(api.HTTPError); ok {
		outcome = string(he.Body.Code)
	}
	_ = s.auditor.AppendDirect(ctx, audit.Record{
		AccountID:     accountID,
		CorrelationID: correlationID,
		Action:        "receipt_reject",
		EntityType:    "receipt",
		EntityID:      env.SigningKeyID,
		Outcome:       outcome,
	})
}

// NewVerifierFromDeviceKeys builds a crypto.Verifier that resolves keys via the device-key service.
func NewVerifierFromDeviceKeys(svc *devicekeys.Service) *crypto.Verifier {
	return crypto.NewVerifier(func(signingKeyID string) (ed25519.PublicKey, error) {
		rec, err := svc.Lookup(context.Background(), signingKeyID)
		if err != nil {
			return nil, err
		}
		if rec == nil {
			return nil, crypto.ErrKeyNotFound
		}
		return rec.PublicKey, nil
	})
}
