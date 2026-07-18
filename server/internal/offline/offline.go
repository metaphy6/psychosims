// Package offline implements the server-side Phase 3.4 offline receipt
// protocol: batched drain endpoint, ownership lease TTL on the server clock,
// and per-receipt reconciliation feedback.
package offline

import (
	"context"
	"crypto/sha256"
	"encoding/hex"
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
	ID      string `json:"id"`
	Status  string `json:"status"`
	Code    string `json:"code,omitempty"`
	Message string `json:"message,omitempty"`
}

// BatchResponse returns the per-item results.
type BatchResponse struct {
	Results     []ItemResult `json:"results"`
	QueueDepthHint int       `json:"queue_depth_hint"`
	Cursor      string       `json:"cursor,omitempty"`
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

	resp := BatchResponse{Results: make([]ItemResult, 0, len(req.Envelopes))}
	for _, env := range req.Envelopes {
		// Extract a display id from the canonical receipt bytes if possible.
		id := extractID(env.CanonicalReceiptBytes)
		result := ItemResult{ID: id}

		receipt, err := s.submit(ctx, accountID, env)
		if err != nil {
			result.Status = "rejected"
			if he, ok := err.(api.HTTPError); ok {
				result.Code = string(he.Body.Code)
				result.Message = he.Body.Message
			} else {
				result.Code = string(api.CodeInternalError)
				result.Message = err.Error()
			}
		} else {
			result.Status = "accepted"
			// Update cursor to the last accepted receipt id.
			resp.Cursor = receipt.IdempotencyKey
		}
		resp.Results = append(resp.Results, result)
	}

	return resp, nil
}

// CheckLease returns an error if the requested patient action is past lease.
func (s *Service) CheckLease(ctx context.Context, patientID string) error {
	if s.ownership == nil {
		return nil
	}
	rec, err := s.ownership.Get(ctx, patientID)
	if err != nil {
		return nil // no record means no lease violation
	}
	if rec.LeaseExpiresAt == nil {
		return nil
	}
	if s.clock.Now().After(*rec.LeaseExpiresAt) {
		return api.NewError(409, api.ErrUser, api.CodeLeaseExpired, "ownership lease expired")
	}
	return nil
}

func extractID(canonical []byte) string {
	// Best-effort: the canonical JSON contains "id":"..."
	var id string
	fmt.Sscanf(string(canonical), `{"id":"%[^"]"`, &id)
	if id == "" {
		id = ctxutil.GenerateID()
	}
	return id
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
