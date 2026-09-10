// Package offline implements the server-side Phase 3.4 offline receipt
// protocol: batched drain endpoint, ownership lease TTL on the server clock,
// and per-receipt reconciliation feedback.
package offline

import (
	"context"
	"crypto/sha256"
	"encoding/hex"
	"encoding/json"
	"errors"
	"fmt"
	"time"

	"psychosims.dev/server/internal/api"
	"psychosims.dev/server/internal/ctxutil"
	"psychosims.dev/server/internal/ownership"
	"psychosims.dev/server/internal/schemas"
	"psychosims.dev/server/internal/timeutil"
)

// BatchRequest submits multiple signed receipts at once.
type BatchRequest struct {
	Envelopes []schemas.SignedEnvelope `json:"envelopes"`
}

// ItemResult is the server verdict for one queued receipt.
type ItemResult struct {
	ID             string `json:"id"`
	IdempotencyKey string `json:"idempotency_key"`
	ProfileVersion int    `json:"profile_version,omitempty"`
	RewardStatus   string `json:"reward_status,omitempty"`
	RewardReason   string `json:"reward_reason,omitempty"`
	CertificateID  string `json:"certificate_id,omitempty"`
	XPAwarded      int    `json:"xp_awarded,omitempty"`
	StudyAwarded   int    `json:"study_points_awarded,omitempty"`
	CashAwarded    int64  `json:"cash_micros_awarded,omitempty"`
	Retryable      bool   `json:"retryable"`
	Status         string `json:"status"`
	Code           string `json:"code,omitempty"`
	Message        string `json:"message,omitempty"`
}

// BatchResponse returns the per-item results.
type BatchResponse struct {
	Results        []ItemResult `json:"results"`
	QueueDepthHint int          `json:"queue_depth_hint"`
	Cursor         string       `json:"cursor,omitempty"`
}

// Submitter applies one signed envelope to authoritative state.
type Submitter func(ctx context.Context, accountID string, env schemas.SignedEnvelope) (*schemas.SessionReceipt, error)

// Service wraps receipt validation with lease checking and batching.
type Service struct {
	submit     Submitter
	ownership  ownership.Repository
	clock      timeutil.Clock
	leaseWidth time.Duration
}

// NewService builds an offline reconciliation service.
func NewService(submit Submitter, ownershipRepo ownership.Repository, clock timeutil.Clock, leaseWidth time.Duration) *Service {
	return &Service{
		submit:     submit,
		ownership:  ownershipRepo,
		clock:      clock,
		leaseWidth: leaseWidth,
	}
}

// SubmitBatch validates each envelope in order and returns per-item feedback.
func (s *Service) SubmitBatch(ctx context.Context, accountID string, req BatchRequest) (BatchResponse, error) {
	if accountID == "" {
		return BatchResponse{}, api.NewUnauthorized("account id required")
	}

	if len(req.Envelopes) > 64 {
		return BatchResponse{}, api.NewUserError(api.CodeOutOfBounds, "at most 64 receipts per batch")
	}
	resp := BatchResponse{Results: make([]ItemResult, 0, len(req.Envelopes))}
	unresolved := false
	for _, env := range req.Envelopes {
		// Extract a display id from the canonical receipt bytes if possible.
		id := extractID(env.CanonicalReceiptBytes)
		result := ItemResult{ID: id}

		// The enclosing request key identifies the batch, not each receipt.
		// Submit authenticates these bytes and checks the lease atomically.
		var metadata struct {
			IdempotencyKey string `json:"idempotency_key"`
		}
		_ = json.Unmarshal(env.CanonicalReceiptBytes, &metadata)
		if !schemas.ValidIdentifier(metadata.IdempotencyKey) {
			metadata.IdempotencyKey = ""
		}
		result.IdempotencyKey = metadata.IdempotencyKey
		itemCtx := ctxutil.WithIdempotencyKey(ctx, metadata.IdempotencyKey)
		receipt, err := s.submit(itemCtx, accountID, env)
		if err != nil {
			result.Status = "rejected"
			var he api.HTTPError
			if errors.As(err, &he) {
				result.Code = string(he.Body.Code)
				result.Message = he.Body.Message
				result.Retryable = he.Status == 408 || he.Status == 429 || he.Status >= 500
			} else {
				result.Code = string(api.CodeInternalError)
				result.Message = "receipt could not be processed"
				result.Retryable = true
			}
			if result.Retryable {
				result.Status = "retryable"
				unresolved = true
				resp.QueueDepthHint++
			}
		} else {
			result.Status = "accepted"
			if schemas.ValidIdentifier(receipt.IdempotencyKey) {
				result.IdempotencyKey = receipt.IdempotencyKey
			}
		}
		// Cursor acknowledges only the contiguous resolved prefix. A later
		// accepted item cannot conceal an earlier transient failure.
		if !unresolved && result.IdempotencyKey != "" {
			resp.Cursor = result.IdempotencyKey
		}
		resp.Results = append(resp.Results, result)
	}

	return resp, nil
}

// CheckLease returns an error if the requested patient action is past lease.
func (s *Service) CheckLease(ctx context.Context, patientID string) error {
	if s.ownership == nil {
		return api.NewServiceUnavailable("ownership store unavailable")
	}
	rec, err := s.ownership.Get(ctx, patientID)
	if err != nil {
		return err
	}
	if rec.LeaseExpiresAt == nil {
		return api.NewConflict(api.CodeLeaseExpired, "ownership lease required")
	}
	if !s.clock.Now().Before(*rec.LeaseExpiresAt) {
		return api.NewError(409, api.ErrUser, api.CodeLeaseExpired, "ownership lease expired")
	}
	return nil
}

func extractID(canonical []byte) string {
	var metadata struct {
		ID string `json:"id"`
	}
	if json.Unmarshal(canonical, &metadata) == nil && schemas.ValidIdentifier(metadata.ID) {
		return metadata.ID
	}
	hash := sha256.Sum256(canonical)
	return hex.EncodeToString(hash[:16])
}

// ActionKind classifies a pending offline action for race resolution.
type ActionKind string

const (
	ActionCure     ActionKind = "cure"
	ActionTransfer ActionKind = "transfer"
	ActionClaim    ActionKind = "claim"
)

// RaceAction is one pending client action.
type RaceAction struct {
	AccountID    string
	PatientID    string
	Kind         ActionKind
	ClientTime   time.Time
	LeaseVersion int
}

// RaceResult is the server-arbitrated outcome of a race.
type RaceResult struct {
	WinnerAccountID string
	LoserAccountID  string
	Reason          string
}

// ResolveRace deterministically picks a winner between two pending offline
// actions on the same patient. The loser is reconciled, never silently dropped.
// Determinism comes from a content hash of stable inputs and the server clock.
func ResolveRace(a, b RaceAction, lease *ownership.Record, serverTime time.Time) RaceResult {
	// Lease expiry always wins: any action past lease expiry loses to a still-
	// valid action, or to the server if both are expired.
	aExpired := lease != nil && lease.LeaseExpiresAt != nil && serverTime.After(*lease.LeaseExpiresAt)
	bExpired := lease != nil && lease.LeaseExpiresAt != nil && serverTime.After(*lease.LeaseExpiresAt)

	if aExpired && !bExpired {
		return RaceResult{WinnerAccountID: b.AccountID, LoserAccountID: a.AccountID, Reason: "expired_lease"}
	}
	if bExpired && !aExpired {
		return RaceResult{WinnerAccountID: a.AccountID, LoserAccountID: b.AccountID, Reason: "expired_lease"}
	}
	if aExpired && bExpired {
		// Both expired: deterministic tie-break by account id.
		winner, loser := a.AccountID, b.AccountID
		if winner > loser {
			winner, loser = loser, winner
		}
		return RaceResult{WinnerAccountID: winner, LoserAccountID: loser, Reason: "both_expired_tiebreak"}
	}

	// Same-account double-action: latest lease version wins.
	if a.AccountID == b.AccountID {
		if a.LeaseVersion >= b.LeaseVersion {
			return RaceResult{WinnerAccountID: a.AccountID, LoserAccountID: b.AccountID, Reason: "same_account_latest_version"}
		}
		return RaceResult{WinnerAccountID: b.AccountID, LoserAccountID: a.AccountID, Reason: "same_account_latest_version"}
	}

	// Different accounts: deterministic content hash of stable inputs.
	scoreA := raceScore(a)
	scoreB := raceScore(b)
	if scoreA >= scoreB {
		return RaceResult{WinnerAccountID: a.AccountID, LoserAccountID: b.AccountID, Reason: "deterministic_score"}
	}
	return RaceResult{WinnerAccountID: b.AccountID, LoserAccountID: a.AccountID, Reason: "deterministic_score"}
}

func raceScore(a RaceAction) string {
	h := sha256.New()
	fmt.Fprintf(h, "%s|%s|%s|%d|%d", a.AccountID, a.PatientID, a.Kind, a.ClientTime.Unix(), a.LeaseVersion)
	return hex.EncodeToString(h.Sum(nil))
}
