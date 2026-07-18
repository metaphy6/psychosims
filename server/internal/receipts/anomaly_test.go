package receipts

import (
	"context"
	"testing"
	"time"

	"psychosims.dev/server/internal/schemas"
)

func TestDeriveSignals(t *testing.T) {
	r := schemas.SessionReceipt{
		IdempotencyKey: "idem-1",
		PatientID:      "p-1",
		LedgerEvents: []schemas.LedgerEvent{
			{Currency: schemas.CurrencyCash, AmountMicros: -100000},
			{Currency: schemas.CurrencyCash, AmountMicros: 200000},
		},
	}
	sig := deriveSignals("acc-1", r)
	if sig.AccountID != "acc-1" {
		t.Errorf("account id = %q, want acc-1", sig.AccountID)
	}
	if sig.ReceiptID != "idem-1" {
		t.Errorf("receipt id = %q, want idem-1", sig.ReceiptID)
	}
	if sig.PayoutPerCase != 100000 {
		t.Errorf("payout = %d, want 100000", sig.PayoutPerCase)
	}
}

func TestMemorySignalStore(t *testing.T) {
	store := NewMemorySignalStore()
	ctx := context.Background()
	sig := AnomalySignal{AccountID: "acc-1", ReceiptID: "r-1"}
	if err := store.Record(ctx, sig); err != nil {
		t.Fatalf("record: %v", err)
	}
	list, err := store.ListByAccount(ctx, "acc-1", time.Now().UTC().Add(-time.Hour))
	if err != nil {
		t.Fatalf("list: %v", err)
	}
	if len(list) != 1 {
		t.Errorf("expected 1 signal, got %d", len(list))
	}
}
