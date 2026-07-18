package idempotency

import (
	"context"
	"testing"
	"time"

	"psychosims.dev/server/internal/ctxutil"
)

func TestMemoryRepositoryDeduplication(t *testing.T) {
	repo := NewMemoryRepository()
	ctx := ctxutil.WithAccountID(context.Background(), "acc-1")
	ctx = ctxutil.WithIdempotencyKey(ctx, "idem-1")

	svc := NewService(repo, time.Hour)

	shouldExec, _, err := svc.CheckOrBegin(ctx)
	if err != nil {
		t.Fatalf("first check: %v", err)
	}
	if !shouldExec {
		t.Fatal("expected to execute on first request")
	}

	if err := svc.Record(ctx, []byte("response-1")); err != nil {
		t.Fatalf("record: %v", err)
	}

	shouldExec, _, err = svc.CheckOrBegin(ctx)
	if err == nil {
		t.Fatal("expected replay error on second request")
	}
	if shouldExec {
		t.Fatal("expected not to execute on replay")
	}
}

func TestMemoryRepositoryGC(t *testing.T) {
	repo := NewMemoryRepository()
	repo.Store(context.Background(), "acc-1", "idem-old", []byte("x"), -time.Hour)

	n, err := repo.GC(context.Background(), time.Now())
	if err != nil {
		t.Fatalf("gc: %v", err)
	}
	if n != 1 {
		t.Errorf("gc removed %d rows, want 1", n)
	}

	_, found, _ := repo.Lookup(context.Background(), "acc-1", "idem-old")
	if found {
		t.Error("expired key should have been removed")
	}
}

func TestCheckRequiresAccountID(t *testing.T) {
	svc := NewService(NewMemoryRepository(), time.Hour)
	ctx := ctxutil.WithIdempotencyKey(context.Background(), "idem-1")
	_, _, err := svc.CheckOrBegin(ctx)
	if err == nil {
		t.Fatal("expected error without account id")
	}
}
