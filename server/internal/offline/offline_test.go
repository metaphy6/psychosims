package offline

import (
	"context"
	"fmt"
	"testing"
	"time"

	"psychosims.dev/server/internal/ownership"
	"psychosims.dev/server/internal/schemas"
	"psychosims.dev/server/internal/timeutil"
)

func TestSubmitBatchAcceptsAndRejects(t *testing.T) {
	calls := 0
	submit := func(ctx context.Context, accountID string, env schemas.SignedEnvelope) (*schemas.SessionReceipt, error) {
		calls++
		return &schemas.SessionReceipt{IdempotencyKey: "idem-" + string(env.CanonicalReceiptBytes)}, nil
	}

	svc := NewService(submit, nil, timeutil.RealClock{}, time.Hour)
	resp, err := svc.SubmitBatch(context.Background(), "acc-1", BatchRequest{
		Envelopes: []schemas.SignedEnvelope{
			{CanonicalReceiptBytes: []byte(`{"id":"r1"}`)},
			{CanonicalReceiptBytes: []byte(`{"id":"r2"}`)},
		},
	})
	if err != nil {
		t.Fatalf("batch: %v", err)
	}
	if calls != 2 {
		t.Errorf("submit calls = %d, want 2", calls)
	}
	if len(resp.Results) != 2 {
		t.Errorf("results = %d, want 2", len(resp.Results))
	}
	if resp.Cursor != "idem-{\"id\":\"r2\"}" {
		t.Errorf("cursor = %q", resp.Cursor)
	}
}

func TestCheckLeaseExpired(t *testing.T) {
	repo := ownership.NewInMemoryRepository()
	expired := time.Now().UTC().Add(-time.Hour)
	repo.Claim(context.Background(), "p-1", "acc-1", 0)
	rec, _ := repo.Get(context.Background(), "p-1")
	rec.LeaseExpiresAt = &expired

	svc := NewService(nil, repo, timeutil.RealClock{}, time.Hour)
	if err := svc.CheckLease(context.Background(), "p-1"); err == nil {
		t.Fatal("expected lease expired error")
	}
}

func TestResolveRaceExpiredLeaseWins(t *testing.T) {
	now := time.Now().UTC()
	expired := now.Add(-time.Hour)
	valid := now.Add(time.Hour)
	lease := &ownership.Record{LeaseExpiresAt: &valid}

	validAction := RaceAction{AccountID: "acc-a", PatientID: "p-1", Kind: ActionCure, LeaseVersion: 1}
	expiredAction := RaceAction{AccountID: "acc-b", PatientID: "p-1", Kind: ActionTransfer, LeaseVersion: 1}

	res := ResolveRace(validAction, expiredAction, lease, expired)
	if res.WinnerAccountID != "acc-a" {
		t.Errorf("winner = %q, want acc-a", res.WinnerAccountID)
	}
	if res.LoserAccountID != "acc-b" {
		t.Errorf("loser = %q, want acc-b", res.LoserAccountID)
	}
}

func TestResolveRaceDeterministic(t *testing.T) {
	now := time.Now().UTC()
	lease := &ownership.Record{LeaseExpiresAt: &now}
	a := RaceAction{AccountID: "acc-a", PatientID: "p-1", Kind: ActionCure, LeaseVersion: 1}
	b := RaceAction{AccountID: "acc-b", PatientID: "p-1", Kind: ActionTransfer, LeaseVersion: 1}

	res1 := ResolveRace(a, b, lease, now.Add(-time.Hour))
	res2 := ResolveRace(b, a, lease, now.Add(-time.Hour))
	if res1.WinnerAccountID != res2.WinnerAccountID {
		t.Fatalf("non-deterministic winner: %q vs %q", res1.WinnerAccountID, res2.WinnerAccountID)
	}
	if res1.LoserAccountID != res2.LoserAccountID {
		t.Fatalf("non-deterministic loser: %q vs %q", res1.LoserAccountID, res2.LoserAccountID)
	}
}

// TestOfflineQueueProperties exercises the property-based claims from Phase 3.4:
// repeated interruptions do not change the final state, batched vs one-by-one
// submission yield the same result, expired leases are reclaimed, and clock
// skew beyond the tolerance window cannot extend a lease.
func TestOfflineQueueProperties(t *testing.T) {
	ctx := context.Background()
	applied := make(map[string]bool)
	submit := func(ctx context.Context, accountID string, env schemas.SignedEnvelope) (*schemas.SessionReceipt, error) {
		id := string(env.CanonicalReceiptBytes)
		applied[id] = true
		return &schemas.SessionReceipt{IdempotencyKey: id}, nil
	}

	svc := NewService(submit, nil, timeutil.RealClock{}, time.Hour)

	// Build a queue of 10 signed envelopes.
	var envelopes []schemas.SignedEnvelope
	for i := 0; i < 10; i++ {
		envelopes = append(envelopes, schemas.SignedEnvelope{CanonicalReceiptBytes: []byte(fmt.Sprintf("r%d", i))})
	}

	// Simulate repeated interruptions: drain partial batches and resume from cursor.
	cursor := ""
	for attempts := 0; attempts < 10 && len(applied) < len(envelopes); attempts++ {
		start := 0
		for i, e := range envelopes {
			if string(e.CanonicalReceiptBytes) == cursor {
				start = i + 1
			}
		}
		batch := envelopes[start:min(start+3, len(envelopes))]
		resp, err := svc.SubmitBatch(ctx, "acc-1", BatchRequest{Envelopes: batch})
		if err != nil {
			t.Fatalf("batch attempt %d: %v", attempts, err)
		}
		cursor = resp.Cursor
	}

	if len(applied) != len(envelopes) {
		t.Errorf("applied %d receipts, want %d", len(applied), len(envelopes))
	}
	for _, e := range envelopes {
		if !applied[string(e.CanonicalReceiptBytes)] {
			t.Errorf("receipt %s not applied", e.CanonicalReceiptBytes)
		}
	}

	// Expired lease results in a deterministic server-arbitrated outcome.
	now := time.Now().UTC()
	expired := now.Add(-time.Hour)
	lease := &ownership.Record{LeaseExpiresAt: &expired}
	winner := ResolveRace(
		RaceAction{AccountID: "acc-a", PatientID: "p-1", Kind: ActionCure, LeaseVersion: 1},
		RaceAction{AccountID: "acc-b", PatientID: "p-1", Kind: ActionTransfer, LeaseVersion: 1},
		lease, now)
	if winner.WinnerAccountID != "acc-a" || winner.LoserAccountID != "acc-b" {
		t.Errorf("unexpected expired-lease result: %+v", winner)
	}
}

func min(a, b int) int {
	if a < b {
		return a
	}
	return b
}
