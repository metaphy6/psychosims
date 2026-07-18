package ctxutil

import (
	"context"
	"testing"
)

func TestContextValues(t *testing.T) {
	ctx := context.Background()
	ctx = WithCorrelationID(ctx, "corr-1")
	ctx = WithIdempotencyKey(ctx, "idem-1")
	ctx = WithAccountID(ctx, "acc-1")
	ctx = WithRequestID(ctx, "req-1")

	if got := CorrelationID(ctx); got != "corr-1" {
		t.Errorf("CorrelationID = %q, want %q", got, "corr-1")
	}
	if got := IdempotencyKey(ctx); got != "idem-1" {
		t.Errorf("IdempotencyKey = %q, want %q", got, "idem-1")
	}
	if got := AccountID(ctx); got != "acc-1" {
		t.Errorf("AccountID = %q, want %q", got, "acc-1")
	}
	if got := RequestID(ctx); got != "req-1" {
		t.Errorf("RequestID = %q, want %q", got, "req-1")
	}
}

func TestGenerateIDUnique(t *testing.T) {
	a, b := GenerateID(), GenerateID()
	if a == b {
		t.Error("generated ids should be unique")
	}
	if len(a) != 32 {
		t.Errorf("id length = %d, want 32", len(a))
	}
}
