package identity

import (
	"context"
	"crypto/sha256"
	"encoding/base64"
	"errors"
	"testing"

	"psychosims.dev/server/internal/api"
)

func TestSignInCreatesAccount(t *testing.T) {
	repo := NewInMemoryRepository()
	svc := NewService(repo)
	svc.RegisterProvider("google", &StubVerifier{Identity: ProviderIdentity{ProviderID: "g-1", Email: "a@b.com"}})

	accountID, err := svc.SignIn(context.Background(), "google", "token", "nonce")
	if err != nil {
		t.Fatalf("sign in: %v", err)
	}
	if accountID == "" {
		t.Fatal("expected account id")
	}

	// Second sign-in with same provider identity returns same account.
	again, err := svc.SignIn(context.Background(), "google", "token", "nonce")
	if err != nil {
		t.Fatalf("sign in again: %v", err)
	}
	if again != accountID {
		t.Errorf("account mismatch: %q vs %q", again, accountID)
	}
}

func TestSignInRejectsUnsupportedProvider(t *testing.T) {
	svc := NewService(NewInMemoryRepository())
	_, err := svc.SignIn(context.Background(), "steam", "token", "nonce")
	if err == nil {
		t.Fatal("expected error")
	}
}

func TestSignInRejectsBadToken(t *testing.T) {
	svc := NewService(NewInMemoryRepository())
	svc.RegisterProvider("google", &StubVerifier{Err: errors.New("bad token")})
	_, err := svc.SignIn(context.Background(), "google", "token", "nonce")
	if err == nil {
		t.Fatal("expected error")
	}
	if _, ok := err.(api.HTTPError); !ok {
		t.Fatalf("expected HTTPError, got %T", err)
	}
}

func TestLinkAccount(t *testing.T) {
	repo := NewInMemoryRepository()
	svc := NewService(repo)
	svc.RegisterProvider("google", &StubVerifier{Identity: ProviderIdentity{ProviderID: "g-1", Email: "a@b.com"}})
	svc.RegisterProvider("apple", &StubVerifier{Identity: ProviderIdentity{ProviderID: "a-1", Email: "a@b.com"}})

	accountID, err := svc.SignIn(context.Background(), "google", "token", "nonce")
	if err != nil {
		t.Fatalf("sign in: %v", err)
	}

	if err := svc.LinkAccount(context.Background(), accountID, "apple", "token", "nonce"); err != nil {
		t.Fatalf("link: %v", err)
	}

	// Signing in with Apple now resolves to the same account.
	viaApple, err := svc.SignIn(context.Background(), "apple", "token", "nonce")
	if err != nil {
		t.Fatalf("sign in apple: %v", err)
	}
	if viaApple != accountID {
		t.Errorf("account mismatch after link: %q vs %q", viaApple, accountID)
	}
}

func TestPKCEAuthSession(t *testing.T) {
	repo := NewInMemoryRepository()
	svc := NewService(repo)
	svc.RegisterProvider("google", &StubVerifier{Identity: ProviderIdentity{ProviderID: "g-1", Email: "a@b.com"}})

	state, nonce, err := svc.StartAuthSession(context.Background(), "google", "steam", "challenge", "S256")
	if err != nil {
		t.Fatalf("start auth session: %v", err)
	}
	if state == "" || nonce == "" {
		t.Fatal("expected state and nonce")
	}

	verifier := "mysecretverifier"
	h := sha256.Sum256([]byte(verifier))
	challenge := base64.RawURLEncoding.EncodeToString(h[:])

	state2, nonce2, err := svc.StartAuthSession(context.Background(), "google", "steam", challenge, "S256")
	if err != nil {
		t.Fatalf("start auth session 2: %v", err)
	}
	returnedNonce, err := svc.VerifyState(context.Background(), state2, verifier)
	if err != nil {
		t.Fatalf("verify state: %v", err)
	}
	if returnedNonce != nonce2 {
		t.Errorf("nonce mismatch: %q vs %q", returnedNonce, nonce2)
	}

	// Wrong verifier fails PKCE.
	state3, _, _ := svc.StartAuthSession(context.Background(), "google", "steam", challenge, "S256")
	if _, err := svc.VerifyState(context.Background(), state3, "wrong"); err == nil {
		t.Fatal("expected wrong verifier to fail")
	}

	// Tampered state fails signature check.
	if _, err := svc.VerifyState(context.Background(), state+"x", verifier); err == nil {
		t.Fatal("expected tampered state to fail")
	}

	// ExchangeCode signs in after PKCE verification using a fresh state.
	state4, _, err := svc.StartAuthSession(context.Background(), "google", "steam", challenge, "S256")
	if err != nil {
		t.Fatalf("start auth session 4: %v", err)
	}
	if _, err := svc.VerifyState(context.Background(), state4, verifier); err != nil {
		t.Fatalf("verify state 4: %v", err)
	}
	accountID, err := svc.ExchangeCode(context.Background(), "google", "token", state4, verifier)
	if err != nil {
		t.Fatalf("exchange code: %v", err)
	}
	if accountID == "" {
		t.Fatal("expected account id")
	}

	// Re-use of consumed state at ExchangeCode is rejected.
	if _, err := svc.ExchangeCode(context.Background(), "google", "token", state4, verifier); err == nil {
		t.Fatal("expected reused state to be rejected")
	}
}

func TestDesktopChannelConfig(t *testing.T) {
	svc := NewService(NewInMemoryRepository())
	cfg := svc.OAuthConfig()
	if cfg.DesktopRedirectURIs["steam"] == "" {
		t.Error("expected steam redirect uri")
	}
	if cfg.DesktopRedirectURIs["direct_download"] == "" {
		t.Error("expected direct_download redirect uri")
	}
}
