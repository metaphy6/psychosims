package audit

import (
	"context"
	"testing"
)

func TestMemoryChain(t *testing.T) {
	app := NewMemoryAppender()
	ctx := context.Background()

	if err := app.Append(ctx, nil, Record{AccountID: "a1", Action: "receipt_accept", EntityType: "receipt", EntityID: "r1", Outcome: "accepted"}); err != nil {
		t.Fatalf("append 1: %v", err)
	}
	if err := app.Append(ctx, nil, Record{AccountID: "a1", Action: "receipt_reject", EntityType: "receipt", EntityID: "r2", Outcome: "rejected"}); err != nil {
		t.Fatalf("append 2: %v", err)
	}

	records, err := app.ValidateChain(ctx)
	if err != nil {
		t.Fatalf("validate: %v", err)
	}
	if len(records) != 2 {
		t.Fatalf("expected 2 records, got %d", len(records))
	}
	if string(records[1].PrevHash) != string(records[0].RowHash) {
		t.Error("expected second row to chain to first")
	}

	// Tamper with a row and expect validation failure.
	app.records[0].Outcome = "rejected"
	if _, err := app.ValidateChain(ctx); err == nil {
		t.Fatal("expected validation to fail after tamper")
	}
}
