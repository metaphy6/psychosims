package devicekeys

import (
	"context"
	"crypto/ed25519"
	"testing"
	"time"

	"psychosims.dev/server/internal/api"
)

func TestRegisterAndResolve(t *testing.T) {
	svc := NewService(NewInMemoryRepository())
	pub, _, _ := ed25519.GenerateKey(nil)

	keyID, err := svc.Register(context.Background(), "acc-1", pub, "ed25519-v1")
	if err != nil {
		t.Fatalf("register: %v", err)
	}

	rec, err := svc.ResolveForAccount(context.Background(), "acc-1", keyID)
	if err != nil {
		t.Fatalf("resolve: %v", err)
	}
	if string(rec.PublicKey) != string(pub) {
		t.Error("public key mismatch")
	}
}

func TestResolveWrongAccount(t *testing.T) {
	svc := NewService(NewInMemoryRepository())
	pub, _, _ := ed25519.GenerateKey(nil)
	keyID, _ := svc.Register(context.Background(), "acc-1", pub, "ed25519-v1")

	_, err := svc.ResolveForAccount(context.Background(), "acc-2", keyID)
	if err == nil {
		t.Fatal("expected error for wrong account")
	}
	if he, ok := err.(api.HTTPError); !ok || he.Body.Code != api.CodeInvalidSignature {
		t.Errorf("expected invalid signature, got %v", err)
	}
}

func TestResolveRevoked(t *testing.T) {
	repo := NewInMemoryRepository()
	svc := NewService(repo)
	pub, _, _ := ed25519.GenerateKey(nil)
	keyID, _ := svc.Register(context.Background(), "acc-1", pub, "ed25519-v1")
	repo.Revoke(context.Background(), "acc-1", keyID)

	_, err := svc.ResolveForAccount(context.Background(), "acc-1", keyID)
	if err == nil {
		t.Fatal("expected error for revoked key")
	}
}

func TestRegisterInvalidKeyLength(t *testing.T) {
	svc := NewService(NewInMemoryRepository())
	_, err := svc.Register(context.Background(), "acc-1", []byte("short"), "ed25519-v1")
	if err == nil {
		t.Fatal("expected error for short key")
	}
}

func TestProvisionRateLimited(t *testing.T) {
	repo := NewInMemoryRepository()
	limiter := &stubLimiter{allowed: false}
	svc := NewService(repo).WithRateLimiter(limiter)
	pub, _, _ := ed25519.GenerateKey(nil)

	_, err := svc.Provision(context.Background(), "acc-1", pub, "ed25519-v1")
	if err == nil {
		t.Fatal("expected rate-limit error")
	}
}

func TestRecoverReprovisionsAndRevokes(t *testing.T) {
	svc := NewService(NewInMemoryRepository())
	pub1, _, _ := ed25519.GenerateKey(nil)
	pub2, _, _ := ed25519.GenerateKey(nil)

	oldID, err := svc.Register(context.Background(), "acc-1", pub1, "ed25519-v1")
	if err != nil {
		t.Fatalf("register old: %v", err)
	}
	newID, revokedID, err := svc.Recover(context.Background(), "acc-1", pub2, "ed25519-v1", true)
	if err != nil {
		t.Fatalf("recover: %v", err)
	}
	if newID == "" {
		t.Fatal("expected new key id")
	}
	if revokedID != oldID {
		t.Errorf("revoked = %q, want %q", revokedID, oldID)
	}
	_, err = svc.ResolveForAccount(context.Background(), "acc-1", oldID)
	if err == nil {
		t.Fatal("expected old key to be revoked")
	}
}

func TestRotationWindow(t *testing.T) {
	now := time.Now().UTC()
	policy := &RotationPolicy{
		Active:             "ed25519-v2",
		Previous:           "ed25519-v1",
		PreviousValidUntil: now.Add(time.Hour),
	}
	svc := NewService(NewInMemoryRepository()).WithRotationPolicy(policy)

	if !svc.VerifyRecord(&Record{SuiteID: "ed25519-v1"}, now) {
		t.Error("expected previous suite valid inside window")
	}
	if svc.VerifyRecord(&Record{SuiteID: "ed25519-v1"}, now.Add(2*time.Hour)) {
		t.Error("expected previous suite invalid outside window")
	}
}

func TestRevocationList(t *testing.T) {
	repo := NewInMemoryRepository()
	svc := NewService(repo)
	pub, _, _ := ed25519.GenerateKey(nil)
	keyID, _ := svc.Register(context.Background(), "acc-1", pub, "ed25519-v1")
	repo.Revoke(context.Background(), "acc-1", keyID)

	list, err := svc.BuildRevocationList(context.Background(), time.Hour)
	if err != nil {
		t.Fatalf("build list: %v", err)
	}
	if len(list.Entries) != 1 {
		t.Fatalf("expected 1 entry, got %d", len(list.Entries))
	}
	if list.Entries[0].KeyID != keyID {
		t.Errorf("entry key id = %q, want %q", list.Entries[0].KeyID, keyID)
	}
	if list.ETag == "" {
		t.Error("expected ETag")
	}
}

type stubLimiter struct {
	allowed bool
}

func (s *stubLimiter) Allow(accountID string) bool { return s.allowed }
