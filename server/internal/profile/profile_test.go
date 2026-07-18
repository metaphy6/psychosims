package profile

import (
	"context"
	"testing"
	"time"

	"psychosims.dev/server/internal/schemas"
	"psychosims.dev/server/internal/timeutil"
)

func TestInMemoryProfileOptimisticConcurrency(t *testing.T) {
	repo := NewInMemoryProfileRepository()
	ctx := context.Background()

	p := &PrimitiveProfile{AccountID: "acc-1", Version: 1, Level: 1, UpdatedAt: time.Now().UTC()}
	if err := repo.Update(ctx, p); err != nil {
		t.Fatalf("create: %v", err)
	}

	// Simulate stale read + update.
	stale := &PrimitiveProfile{AccountID: "acc-1", Version: 1, Level: 2, UpdatedAt: time.Now().UTC()}
	if err := repo.Update(ctx, stale); err == nil {
		t.Fatal("expected version conflict")
	}

	fresh, _ := repo.Get(ctx, "acc-1")
	if fresh.Level != 1 {
		t.Errorf("level = %d, want 1", fresh.Level)
	}
}

func TestLedgerUsesAuthoritativeTime(t *testing.T) {
	clock := timeutil.FixedClock{T: time.Date(2026, 1, 1, 12, 0, 0, 0, time.UTC)}
	ledger := NewInMemoryLedger(&clock)
	ctx := context.Background()

	// Client claims two events with reversed timestamps.
	events := []schemas.LedgerEvent{
		{IdempotencyKey: "e1", TimestampSeconds: 200, Currency: schemas.CurrencyCash, AmountMicros: 100},
		{IdempotencyKey: "e2", TimestampSeconds: 100, Currency: schemas.CurrencyCash, AmountMicros: -100},
	}
	if err := ledger.Append(ctx, nil, "acc-1", events); err != nil {
		t.Fatalf("append: %v", err)
	}

	clock.Advance(time.Hour)
	events2 := []schemas.LedgerEvent{
		{IdempotencyKey: "e3", TimestampSeconds: 50, Currency: schemas.CurrencyCash, AmountMicros: 50},
	}
	if err := ledger.Append(ctx, nil, "acc-1", events2); err != nil {
		t.Fatalf("append: %v", err)
	}

	recorded := ledger.Events()
	if len(recorded) != 3 {
		t.Fatalf("expected 3 events, got %d", len(recorded))
	}
	// Order follows server clock, not client timestamps.
	if recorded[0].TimestampSeconds != int(time.Date(2026, 1, 1, 12, 0, 0, 0, time.UTC).Unix()) {
		t.Errorf("event 1 server time mismatch: %d", recorded[0].TimestampSeconds)
	}
	if recorded[2].TimestampSeconds != int(time.Date(2026, 1, 1, 13, 0, 0, 0, time.UTC).Unix()) {
		t.Errorf("event 3 server time mismatch: %d", recorded[2].TimestampSeconds)
	}
}

func TestEraseAccount(t *testing.T) {
	repo := NewInMemoryProfileRepository()
	ctx := context.Background()

	p := &PrimitiveProfile{AccountID: "acc-1", Version: 1, Level: 5, XP: 100, CashMicros: 500000}
	if err := repo.Update(ctx, p); err != nil {
		t.Fatalf("create: %v", err)
	}

	if err := repo.Erase(ctx, "acc-1"); err != nil {
		t.Fatalf("erase: %v", err)
	}

	erased, err := repo.Get(ctx, "acc-1")
	if err != nil {
		t.Fatalf("get after erase: %v", err)
	}
	if erased.Level != 0 || erased.XP != 0 || erased.CashMicros != 0 {
		t.Errorf("expected zeroed profile, got %+v", erased)
	}
	if erased.AccountID != "acc-1" {
		t.Errorf("expected account id preserved, got %q", erased.AccountID)
	}
}
