//go:build postgres

package integration

import (
	"context"
	"crypto/ed25519"
	"sync"
	"testing"
	"time"

	"psychosims.dev/server/internal/ctxutil"
	"psychosims.dev/server/internal/devicekeys"
	"psychosims.dev/server/internal/identity"
	"psychosims.dev/server/internal/tokens"
)

func TestPostgresIdentityConcurrentSignInAndLink(t *testing.T) {
	st := postgresStore(t)
	ctx := context.Background()
	svc := identity.NewService(identity.NewSQLRepository(st.DB()))
	svc.RegisterProvider("google", &identity.StubVerifier{Identity: identity.ProviderIdentity{ProviderID: "subject"}})
	var wg sync.WaitGroup
	ids := make(chan string, 12)
	for i := 0; i < 12; i++ {
		wg.Add(1)
		go func() {
			defer wg.Done()
			id, err := svc.SignIn(ctx, "google", "proof", "nonce")
			if err != nil {
				t.Error(err)
				return
			}
			ids <- id
		}()
	}
	wg.Wait()
	close(ids)
	var first string
	for id := range ids {
		if first == "" {
			first = id
		}
		if id != first {
			t.Errorf("duplicate identity accounts")
		}
	}
	if n := countRows(t, st.DB(), "accounts"); n != 1 {
		t.Fatalf("orphan accounts=%d", n)
	}
	sqlAccount(t, st.DB(), "other")
	if err := svc.LinkAccount(ctx, "other", "google", "proof", "nonce"); err == nil {
		t.Fatal("linked identity stolen")
	}
	restarted := identity.NewService(identity.NewSQLRepository(st.DB()))
	restarted.RegisterProvider("google", &identity.StubVerifier{Identity: identity.ProviderIdentity{ProviderID: "subject"}})
	got, err := restarted.SignIn(ctx, "google", "proof", "nonce")
	if err != nil || got != first {
		t.Fatalf("restart lost identity: %s %v", got, err)
	}
}

func TestPostgresTokensRotationRetryAndRevocation(t *testing.T) {
	st := postgresStore(t)
	sqlAccount(t, st.DB(), "a")
	ctx := context.Background()
	secret := []byte("only-a-local-test-secret-32-bytes-long")
	manager := tokens.NewSQLManager(st.DB(), secret, time.Minute, time.Hour)
	pair, err := manager.IssuePair(ctx, "a", "login-1")
	if err != nil {
		t.Fatal(err)
	}
	restarted := tokens.NewSQLManager(st.DB(), secret, time.Minute, time.Hour)
	if c, err := restarted.Verify(ctx, pair.AccessToken); err != nil || c.AccountID != "a" {
		t.Fatalf("restart access: %v", err)
	}
	var wg sync.WaitGroup
	results := make(chan tokens.Pair, 12)
	for i := 0; i < 12; i++ {
		wg.Add(1)
		go func() {
			defer wg.Done()
			p, err := restarted.Rotate(ctx, pair.RefreshToken, "rotation-1")
			if err != nil {
				t.Error(err)
				return
			}
			results <- p
		}()
	}
	wg.Wait()
	close(results)
	var rotated tokens.Pair
	for p := range results {
		if rotated.AccessToken == "" {
			rotated = p
		}
		if p != rotated {
			t.Fatal("same operation produced different token pairs")
		}
	}
	if _, err := manager.Rotate(ctx, pair.RefreshToken, "different-operation"); err == nil {
		t.Fatal("refresh replay accepted")
	}
	if err := manager.Logout(ctx, rotated.AccessToken); err != nil {
		t.Fatal(err)
	}
	if err := manager.Logout(ctx, rotated.AccessToken); err != nil {
		t.Fatalf("logout retry: %v", err)
	}
	for _, access := range []string{pair.AccessToken, rotated.AccessToken} {
		if _, err := restarted.Verify(ctx, access); err == nil {
			t.Fatal("revoked session access accepted")
		}
	}
	if _, err := restarted.Rotate(ctx, rotated.RefreshToken, "rotation-2"); err == nil {
		t.Fatal("revoked session refreshed")
	}
	second, err := manager.IssuePair(ctx, "a", "login-2")
	if err != nil {
		t.Fatal(err)
	}
	if err := manager.RevokeAccount(ctx, "a"); err != nil {
		t.Fatal(err)
	}
	if _, err := restarted.Verify(ctx, second.AccessToken); err == nil {
		t.Fatal("account revocation not durable")
	}
}

func TestPostgresDeviceReplacementAtomic(t *testing.T) {
	st := postgresStore(t)
	sqlAccount(t, st.DB(), "a")
	sqlAccount(t, st.DB(), "b")
	ctx := context.Background()
	svc := devicekeys.NewService(devicekeys.NewSQLRepository(st.DB()))
	pub, _, _ := ed25519.GenerateKey(nil)
	other, _, _ := ed25519.GenerateKey(nil)
	old, err := svc.Register(ctx, "a", pub, "ed25519-v1")
	if err != nil {
		t.Fatal(err)
	}
	same, err := svc.Register(ctx, "a", pub, "ed25519-v1")
	if err != nil || same != old {
		t.Fatal("enrollment retry was not idempotent")
	}
	if _, err := svc.Replace(ctx, "b", old, other, "ed25519-v1"); err == nil {
		t.Fatal("cross-account replacement accepted")
	}
	if _, err := st.DB().Exec(`CREATE FUNCTION fail_key_revoke() RETURNS trigger AS $$ BEGIN RAISE EXCEPTION 'forced'; END $$ LANGUAGE plpgsql; CREATE TRIGGER fail_key_revoke BEFORE UPDATE ON device_keys FOR EACH ROW EXECUTE FUNCTION fail_key_revoke()`); err != nil {
		t.Fatal(err)
	}
	if _, err := svc.Replace(ctx, "a", old, other, "ed25519-v1"); err == nil {
		t.Fatal("forced revoke failure accepted")
	}
	if n := countRows(t, st.DB(), "device_keys"); n != 1 {
		t.Fatal("new key escaped rollback")
	}
	if _, err := st.DB().Exec(`DROP TRIGGER fail_key_revoke ON device_keys; DROP FUNCTION fail_key_revoke()`); err != nil {
		t.Fatal(err)
	}
	replacement, err := svc.Replace(ctx, "a", old, other, "ed25519-v1")
	if err != nil {
		t.Fatal(err)
	}
	if _, err := svc.ResolveForAccount(ctx, "a", old); err == nil {
		t.Fatal("old key remains active")
	}
	if _, err := svc.ResolveForAccount(ctx, "a", replacement); err != nil {
		t.Fatal(err)
	}
	again, err := svc.Replace(ctx, "a", old, other, "ed25519-v1")
	if err != nil || again != replacement {
		t.Fatal("replacement retry changed key")
	}
	if _, err := svc.Register(ctx, "a", pub, "ed25519-v1"); err == nil {
		t.Fatal("revoked public key resurrected")
	}
	if _, err := svc.Register(ctx, "a", other, "unknown"); err == nil {
		t.Fatal("unsupported suite accepted")
	}
}

func TestPostgresTokenRotationFailureRollsBackConsumption(t *testing.T) {
	st := postgresStore(t)
	sqlAccount(t, st.DB(), "a")
	ctx := context.Background()
	manager := tokens.NewSQLManager(st.DB(), []byte("only-a-local-test-secret-32-bytes-long"), time.Minute, time.Hour)
	pair, err := manager.IssuePair(ctx, "a", "login")
	if err != nil {
		t.Fatal(err)
	}
	if _, err := st.DB().Exec(`CREATE FUNCTION fail_refresh_insert() RETURNS trigger AS $$ BEGIN RAISE EXCEPTION 'forced'; END $$ LANGUAGE plpgsql; CREATE TRIGGER fail_refresh_insert BEFORE INSERT ON refresh_tokens FOR EACH ROW EXECUTE FUNCTION fail_refresh_insert()`); err != nil {
		t.Fatal(err)
	}
	if _, err := manager.Rotate(ctx, pair.RefreshToken, "rotate"); err == nil {
		t.Fatal("failed refresh insertion accepted")
	}
	var consumed int
	if err := st.DB().QueryRow(`SELECT count(*) FROM refresh_tokens WHERE consumed_key IS NOT NULL`).Scan(&consumed); err != nil {
		t.Fatal(err)
	}
	if consumed != 0 {
		t.Fatal("refresh consumed outside rollback")
	}
	if _, err := st.DB().Exec(`DROP TRIGGER fail_refresh_insert ON refresh_tokens; DROP FUNCTION fail_refresh_insert()`); err != nil {
		t.Fatal(err)
	}
	if _, err := manager.Rotate(ctx, pair.RefreshToken, "rotate"); err != nil {
		t.Fatalf("rolled-back refresh was unusable: %v", err)
	}
}

func TestPostgresDeviceOperationIdentityCannotChangeKey(t *testing.T) {
	st := postgresStore(t)
	sqlAccount(t, st.DB(), "a")
	svc := devicekeys.NewService(devicekeys.NewSQLRepository(st.DB()))
	ctx := ctxutil.WithIdempotencyKey(context.Background(), "enrollment")
	pub, _, _ := ed25519.GenerateKey(nil)
	other, _, _ := ed25519.GenerateKey(nil)
	id, err := svc.Register(ctx, "a", pub, "ed25519-v1")
	if err != nil {
		t.Fatal(err)
	}
	if _, err := svc.Register(ctx, "a", other, "ed25519-v1"); err == nil {
		t.Fatal("same mutation key enrolled different device key")
	}
	again, err := svc.Register(ctx, "a", pub, "ed25519-v1")
	if err != nil || again != id {
		t.Fatal("same enrollment retry changed identity")
	}
	if n := countRows(t, st.DB(), "device_keys"); n != 1 {
		t.Fatal("changed retry produced another key")
	}
}
