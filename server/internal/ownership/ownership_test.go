package ownership

import (
	"context"
	"testing"
	"time"

	"psychosims.dev/server/internal/api"
	"psychosims.dev/server/internal/timeutil"
)

func TestClaimFromPool(t *testing.T) {
	repo := NewInMemoryRepository()
	ctx := context.Background()

	if err := repo.Claim(ctx, "p-1", "acc-1", 0); err != nil {
		t.Fatalf("claim: %v", err)
	}
	rec, err := repo.Get(ctx, "p-1")
	if err != nil {
		t.Fatalf("get: %v", err)
	}
	if rec.State != StateOwned || rec.AccountID != "acc-1" {
		t.Errorf("unexpected state: %+v", rec)
	}
}

func TestDoubleClaimRejected(t *testing.T) {
	repo := NewInMemoryRepository()
	ctx := context.Background()

	repo.Claim(ctx, "p-1", "acc-1", 0)
	if err := repo.Claim(ctx, "p-1", "acc-2", 1); err == nil {
		t.Fatal("expected double claim rejected")
	}
}

func TestLegalTransition(t *testing.T) {
	repo := NewInMemoryRepository()
	ctx := context.Background()

	repo.Claim(ctx, "p-1", "acc-1", 0)
	if err := repo.Transition(ctx, "p-1", "acc-1", StateOwned, StateHospitalized, 1); err != nil {
		t.Fatalf("transition: %v", err)
	}
	rec, _ := repo.Get(ctx, "p-1")
	if rec.State != StateHospitalized {
		t.Errorf("state = %q, want hospitalized", rec.State)
	}
}

func TestIllegalTransition(t *testing.T) {
	repo := NewInMemoryRepository()
	ctx := context.Background()

	repo.Claim(ctx, "p-1", "acc-1", 0)
	err := repo.Transition(ctx, "p-1", "acc-1", StateHospitalized, StateArchived, 1)
	if err == nil {
		t.Fatal("expected illegal transition error")
	}
	if he, ok := err.(api.HTTPError); !ok || he.Body.Code != api.CodeIllegalTransition {
		t.Errorf("expected illegal transition, got %v", err)
	}
}

func TestHospitalizedDirectToArchivedRejected(t *testing.T) {
	repo := NewInMemoryRepository()
	ctx := context.Background()

	repo.Claim(ctx, "p-1", "acc-1", 0)
	repo.Transition(ctx, "p-1", "acc-1", StateOwned, StateHospitalized, 1)
	if err := repo.Transition(ctx, "p-1", "acc-1", StateHospitalized, StateArchived, 2); err == nil {
		t.Fatal("expected hospitalized→archived rejected")
	}
}

func TestServiceRejectsExpiredLease(t *testing.T) {
	repo := NewInMemoryRepository()
	ctx := context.Background()
	now := time.Now().UTC()
	expired := now.Add(-time.Hour)

	repo.Claim(ctx, "p-1", "acc-1", 0)
	rec, _ := repo.Get(ctx, "p-1")
	rec.LeaseExpiresAt = &expired
	repo.records["p-1"] = rec

	svc := NewService(repo, timeutil.FixedClock{T: now})
	err := svc.Transition(ctx, "p-1", "acc-1", StateOwned, StateCured, 1)
	if err == nil {
		t.Fatal("expected expired lease error")
	}
	if he, ok := err.(api.HTTPError); !ok || he.Body.Code != api.CodeLeaseExpired {
		t.Errorf("expected lease expired, got %v", err)
	}
}

func TestMemoryClassGuardBlocksHospitalization(t *testing.T) {
	repo := NewInMemoryRepository()
	ctx := context.Background()

	repo.Claim(ctx, "p-1", "acc-1", 0)
	rec, _ := repo.Get(ctx, "p-1")
	rec.MemoryClass = MemoryClassStateless
	repo.records["p-1"] = rec

	svc := NewService(repo, timeutil.RealClock{})
	if err := svc.Transition(ctx, "p-1", "acc-1", StateOwned, StateHospitalized, 1); err == nil {
		t.Fatal("expected stateless hospitalization rejected")
	}
}
