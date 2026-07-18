package presence

import (
	"context"
	"crypto/ed25519"
	"testing"
)

func TestSignAndVerify(t *testing.T) {
	pub, priv, _ := ed25519.GenerateKey(nil)
	repo := NewInMemoryRepository()
	svc := NewService(repo, priv)

	rec, err := svc.Set(context.Background(), "acc-1", "online", "ed25519-v1")
	if err != nil {
		t.Fatalf("set: %v", err)
	}
	if rec.SuiteID != "ed25519-v1" {
		t.Errorf("suite id = %q, want ed25519-v1", rec.SuiteID)
	}
	if !svc.Verify(pub, rec) {
		t.Error("signature did not verify")
	}

	// Tampered status should fail.
	rec.Status = "offline"
	if svc.Verify(pub, rec) {
		t.Error("tampered record verified")
	}

	// Tampered suite id should fail.
	rec, _ = svc.Set(context.Background(), "acc-1", "online", "ed25519-v1")
	rec.SuiteID = "ed25519-v2"
	if svc.Verify(pub, rec) {
		t.Error("tampered suite id verified")
	}
}

func TestListByStatus(t *testing.T) {
	_, priv, _ := ed25519.GenerateKey(nil)
	repo := NewInMemoryRepository()
	svc := NewService(repo, priv)
	ctx := context.Background()

	if _, err := svc.Set(ctx, "acc-1", "online", "ed25519-v1"); err != nil {
		t.Fatalf("set: %v", err)
	}
	if _, err := svc.Set(ctx, "acc-2", "away", "ed25519-v1"); err != nil {
		t.Fatalf("set: %v", err)
	}
	if _, err := svc.Set(ctx, "acc-3", "online", "ed25519-v1"); err != nil {
		t.Fatalf("set: %v", err)
	}

	online, err := repo.ListByStatus(ctx, "online")
	if err != nil {
		t.Fatalf("list: %v", err)
	}
	if len(online) != 2 {
		t.Errorf("expected 2 online, got %d", len(online))
	}
}
