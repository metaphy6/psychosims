//go:build postgres

package integration

import (
	"bytes"
	"context"
	"crypto"
	"crypto/ed25519"
	"crypto/rand"
	"crypto/rsa"
	"crypto/sha256"
	"encoding/base64"
	"encoding/json"
	"fmt"
	"io"
	"math/big"
	"net/http"
	"net/http/httptest"
	"strings"
	"sync"
	"testing"
	"time"

	"psychosims.dev/server/internal/api"
	"psychosims.dev/server/internal/canonicaljson"
	"psychosims.dev/server/internal/config"
	"psychosims.dev/server/internal/ctxutil"
	"psychosims.dev/server/internal/devicekeys"
	"psychosims.dev/server/internal/identity"
	"psychosims.dev/server/internal/ownership"
	"psychosims.dev/server/internal/receipts"
	"psychosims.dev/server/internal/schemas"
	"psychosims.dev/server/internal/server"
	"psychosims.dev/server/internal/tokens"
)

func TestPostgresHTTPAuthenticatedReceiptLifecycle(t *testing.T) {
	st := postgresStore(t)
	cfg := config.Default()
	cfg.RateLimitPreAuthPerIP = 1000
	cfg.RateLimitAuthPerAccount = 1000
	key, err := rsa.GenerateKey(rand.Reader, 2048)
	if err != nil {
		t.Fatal(err)
	}
	providerServer := httptest.NewTLSServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		json.NewEncoder(w).Encode(map[string]any{"keys": []any{map[string]string{"kty": "RSA", "kid": "test", "alg": "RS256", "use": "sig", "n": base64.RawURLEncoding.EncodeToString(key.N.Bytes()), "e": base64.RawURLEncoding.EncodeToString(big.NewInt(int64(key.E)).Bytes())}}})
	}))
	defer providerServer.Close()
	provider, err := identity.NewOIDCProvider(identity.OIDCConfig{Provider: "google", ClientID: "client", Issuer: "https://fixture.example", JWKSURL: providerServer.URL, AuthorizationURL: providerServer.URL, TokenURL: providerServer.URL}, providerServer.Client())
	if err != nil {
		t.Fatal(err)
	}
	ids := identity.NewService(identity.NewSQLRepository(st.DB()))
	ids.RegisterProvider("google", provider)
	catalog, err := server.NewCatalog([]server.CatalogCase{{ID: "case-a", RulesetVersion: "0.1.0", MemoryClass: ownership.MemoryClassPersistent, InitialAxes: map[string]int{"trust": 20}, Controllers: schemas.TherapyControllerSettings{Focus: schemas.FocusBalanced, EmotionalDelivery: schemas.DeliveryBalanced}}})
	if err != nil {
		t.Fatal(err)
	}
	secret := []byte("local-only-integration-signing-key-32")
	srv := server.NewOnline(cfg, st.DB(), ids, tokens.NewSQLManager(st.DB(), secret, time.Minute, time.Hour), catalog, secret)
	httpServer := httptest.NewServer(srv.Handler())
	defer httpServer.Close()
	call := func(method, path, token, idem string, body any) (int, []byte, http.Header) {
		t.Helper()
		b, _ := json.Marshal(body)
		req, _ := http.NewRequest(method, httpServer.URL+path, bytes.NewReader(b))
		req.Header.Set("Content-Type", "application/json")
		req.Header.Set(api.VersionHeader, "v1")
		req.Header.Set(api.CorrelationIDHeader, "http-test")
		if idem != "" {
			req.Header.Set(api.IdempotencyKeyHeader, idem)
		}
		if token != "" {
			req.Header.Set("Authorization", "Bearer "+token)
		}
		resp, err := http.DefaultClient.Do(req)
		if err != nil {
			t.Fatal(err)
		}
		defer resp.Body.Close()
		out, _ := io.ReadAll(resp.Body)
		return resp.StatusCode, out, resp.Header
	}
	h, _ := json.Marshal(map[string]string{"alg": "RS256", "kid": "test"})
	c, _ := json.Marshal(map[string]any{"iss": "https://fixture.example", "aud": "client", "sub": "subject", "nonce": "fixture-nonce", "iat": time.Now().Unix(), "exp": time.Now().Add(time.Hour).Unix()})
	unsigned := base64.RawURLEncoding.EncodeToString(h) + "." + base64.RawURLEncoding.EncodeToString(c)
	digest := sha256.Sum256([]byte(unsigned))
	signature, _ := rsa.SignPKCS1v15(rand.Reader, key, crypto.SHA256, digest[:])
	proof := unsigned + "." + base64.RawURLEncoding.EncodeToString(signature)
	status, body, headers := call("POST", "/v1/auth/id-token", "", "login", map[string]string{"provider": "google", "id_token": proof, "nonce": "fixture-nonce"})
	if status != 200 {
		t.Fatalf("sign-in status=%d: %s", status, body)
	}
	var pair tokens.Pair
	if err := json.Unmarshal(body, &pair); err != nil {
		t.Fatal(err)
	}
	if headers.Get(api.VersionHeader) != "v1" || headers.Get(api.CorrelationIDHeader) != "http-test" {
		t.Fatal("missing protocol headers")
	}
	status, body, _ = call("GET", "/v1/boot", pair.AccessToken, "", nil)
	if status != 200 {
		t.Fatalf("boot: %d %s", status, body)
	}
	pub, priv, _ := ed25519.GenerateKey(nil)
	status, body, _ = call("POST", "/v1/device-keys", pair.AccessToken, "enroll", map[string]any{"public_key": pub, "suite_id": "ed25519-v1"})
	if status != 200 {
		t.Fatalf("key: %d %s", status, body)
	}
	var device devicekeys.Record
	json.Unmarshal(body, &device)
	if device.AccountID != pair.AccountID {
		t.Fatal("device account mismatch")
	}
	status, body, _ = call("POST", "/v1/sessions", pair.AccessToken, "session", map[string]any{"case_id": "case-a", "card_ids": []string{"open_question"}})
	if status != 200 {
		t.Fatalf("session: %d %s", status, body)
	}
	var permit receipts.Authorization
	json.Unmarshal(body, &permit)
	if permit.StartState.InitialAxes["trust"] != 20 || permit.StartState.RootSeed == 0 || permit.StartState.CaseID != "case-a" {
		t.Fatal("trusted start missing")
	}
	receipt := schemas.SessionReceipt{ID: permit.ID, PatientID: permit.PatientID, SchemaVersion: "0.3.0", RulesetVersion: permit.RulesetVersion, IdempotencyKey: "receipt", CorrelationID: "http-test", TurnCount: 1, StartState: permit.StartState, Actions: []schemas.InteractionPattern{schemas.OpenQuestion}, Deltas: []schemas.StructuredDelta{}, LedgerEvents: []schemas.LedgerEvent{}}
	wire, err := canonicaljson.Marshal(receipt)
	if err != nil {
		t.Fatal(err)
	}
	env := schemas.SignedEnvelope{CanonicalReceiptBytes: wire, Signature: ed25519.Sign(priv, wire), SuiteID: "ed25519-v1", SigningKeyID: device.ID}
	for i := 0; i < 2; i++ {
		status, body, _ = call("POST", "/v1/receipts", pair.AccessToken, "receipt", env)
		if status != 200 {
			t.Fatalf("receipt: %d %s", status, body)
		}
		var verdict map[string]any
		json.Unmarshal(body, &verdict)
		if verdict["status"] != "accepted" || verdict["reward_status"] != "held_unproven" || verdict["profile_version"] != float64(2) {
			t.Fatalf("verdict: %s", body)
		}
	}
	if n := countRows(t, st.DB(), "ledger_events"); n != 0 {
		t.Fatal("unproven HTTP receipt paid rewards")
	}
	status, body, _ = call("POST", "/v1/sessions", pair.AccessToken, "session", map[string]any{"case_id": "case-a", "card_ids": []string{"open_question"}})
	var replayed receipts.Authorization
	json.Unmarshal(body, &replayed)
	if status != 200 || replayed.ID != permit.ID {
		t.Fatalf("session mutation retry created new grant after acceptance: %d %s", status, body)
	}
	status, body, _ = call("POST", "/v1/receipts/batch", pair.AccessToken, "batch", map[string]any{"envelopes": []schemas.SignedEnvelope{env}})
	if status != 200 {
		t.Fatalf("batch: %d %s", status, body)
	}

	// Next-day starts renew only this account's expired owned catalog instance.
	if _, err := st.DB().Exec(`UPDATE ownership_records SET lease_expires_at=clock_timestamp()-INTERVAL '1 second' WHERE patient_id=$1`, permit.PatientID); err != nil {
		t.Fatal(err)
	}
	status, body, _ = call("POST", "/v1/sessions", pair.AccessToken, "next-day", map[string]any{"case_id": "case-a", "card_ids": []string{"open_question"}})
	var renewed receipts.Authorization
	if err := json.Unmarshal(body, &renewed); err != nil {
		t.Fatal(err)
	}
	if status != 200 || renewed.ID == permit.ID || !renewed.ExpiresAt.After(time.Now()) {
		t.Fatalf("expired owned lease cannot renew: %d %s", status, body)
	}
	var version int
	if err := st.DB().QueryRow(`SELECT version FROM ownership_records WHERE patient_id=$1`, permit.PatientID).Scan(&version); err != nil {
		t.Fatal(err)
	}
	if version != 2 {
		t.Fatalf("renewed version=%d", version)
	}
	// Expire an unfinished authorization and race exact start retries. The old
	// pending grant must be invalidated while accepted receipt evidence survives.
	if _, err := st.DB().Exec(`UPDATE ownership_records SET lease_expires_at=clock_timestamp()-INTERVAL '1 second' WHERE patient_id=$1`, permit.PatientID); err != nil {
		t.Fatal(err)
	}
	var wg sync.WaitGroup
	permitIDs := make(chan string, 8)
	for i := 0; i < 8; i++ {
		wg.Add(1)
		go func() {
			defer wg.Done()
			code, b, _ := call("POST", "/v1/sessions", pair.AccessToken, "renew-race", map[string]any{"case_id": "case-a", "card_ids": []string{"open_question"}})
			var a receipts.Authorization
			if err := json.Unmarshal(b, &a); err != nil {
				t.Error(err)
				return
			}
			if code != 200 {
				t.Errorf("concurrent renewal: %d %s", code, b)
			}
			permitIDs <- a.ID
		}()
	}
	wg.Wait()
	close(permitIDs)
	var same string
	for id := range permitIDs {
		if same == "" {
			same = id
		}
		if id == "" || id != same || id == renewed.ID {
			t.Fatal("concurrent renewals did not converge")
		}
	}
	if err := st.DB().QueryRow(`SELECT version FROM ownership_records WHERE patient_id=$1`, permit.PatientID).Scan(&version); err != nil {
		t.Fatal(err)
	}
	if version != 3 {
		t.Fatalf("concurrent renewal version=%d", version)
	}
	var accepted int
	if err := st.DB().QueryRow(`SELECT count(*) FROM session_authorizations WHERE consumed_at IS NOT NULL`).Scan(&accepted); err != nil {
		t.Fatal(err)
	}
	if accepted != 1 {
		t.Fatal("renewal removed terminal receipt evidence")
	}
	status, body, _ = call("POST", "/v1/receipts", pair.AccessToken, "receipt", env)
	if status != 200 {
		t.Fatalf("accepted receipt replay after renewal: %d %s", status, body)
	}
	var stale int
	if err := st.DB().QueryRow(`SELECT count(*) FROM session_authorizations WHERE id=$1`, renewed.ID).Scan(&stale); err != nil {
		t.Fatal(err)
	}
	if stale != 0 {
		t.Fatal("stale unfinished grant retained")
	}
	if _, err := st.DB().Exec(`UPDATE ownership_records SET memory_class='stateless',lease_expires_at=clock_timestamp()-INTERVAL '1 second' WHERE patient_id=$1`, permit.PatientID); err != nil {
		t.Fatal(err)
	}
	status, body, _ = call("POST", "/v1/sessions", pair.AccessToken, "memory-change", map[string]any{"case_id": "case-a", "card_ids": []string{"open_question"}})
	if status != 409 {
		t.Fatalf("memory class changed by renewal: %d %s", status, body)
	}
	if _, err := st.DB().Exec(`UPDATE ownership_records SET memory_class='persistent' WHERE patient_id=$1`, permit.PatientID); err != nil {
		t.Fatal(err)
	}
	for _, state := range []string{"hospitalized", "cured", "archived"} {
		if _, err := st.DB().Exec(`UPDATE ownership_records SET state=$2,lease_expires_at=clock_timestamp()-INTERVAL '1 second' WHERE patient_id=$1`, permit.PatientID, state); err != nil {
			t.Fatal(err)
		}
		code, b, _ := call("POST", "/v1/sessions", pair.AccessToken, "terminal-"+state, map[string]any{"case_id": "case-a", "card_ids": []string{"open_question"}})
		if code != 409 {
			t.Fatalf("non-owned state renewed: %d %s", code, b)
		}
	}
	sqlAccount(t, st.DB(), "foreign-owner")
	if _, err := st.DB().Exec(`UPDATE ownership_records SET state='owned',account_id='foreign-owner' WHERE patient_id=$1`, permit.PatientID); err != nil {
		t.Fatal(err)
	}
	status, body, _ = call("POST", "/v1/sessions", pair.AccessToken, "foreign", map[string]any{"case_id": "case-a", "card_ids": []string{"open_question"}})
	if status != 409 {
		t.Fatalf("foreign lease stolen: %d %s", status, body)
	}
	var owner string
	if err := st.DB().QueryRow(`SELECT account_id FROM ownership_records WHERE patient_id=$1`, permit.PatientID).Scan(&owner); err != nil {
		t.Fatal(err)
	}
	if owner != "foreign-owner" {
		t.Fatal("foreign lease mutated")
	}
	status, _, _ = call("POST", "/v1/auth/logout", pair.AccessToken, "logout", map[string]any{})
	if status != 200 {
		t.Fatal("logout failed")
	}
	status, _, _ = call("POST", "/v1/auth/logout", pair.AccessToken, "logout", map[string]any{})
	if status != 200 {
		t.Fatal("logout retry failed")
	}
	status, _, _ = call("GET", "/v1/boot", pair.AccessToken, "", nil)
	if status != 401 {
		t.Fatal("revoked bearer accepted")
	}
	if _, err := ids.SignIn(context.Background(), "google", proof, "wrong-nonce"); err == nil {
		t.Fatal("nonce mismatch accepted")
	}
}

func TestPostgresBootUsesAccountRateLimit(t *testing.T) {
	st := postgresStore(t)
	sqlAccount(t, st.DB(), "rate-account")
	cfg := config.Default()
	cfg.RateLimitAuthPerAccount = 1
	manager := tokens.NewSQLManager(st.DB(), []byte("only-a-local-test-secret-32-bytes-long"), time.Minute, time.Hour)
	pair, err := manager.IssuePair(ctxutil.WithIdempotencyKey(context.Background(), "login"), "rate-account", "login")
	if err != nil {
		t.Fatal(err)
	}
	catalog, _ := server.NewCatalog(nil)
	srv := server.NewOnline(cfg, st.DB(), identity.NewService(identity.NewSQLRepository(st.DB())), manager, catalog, []byte("only-a-local-test-secret-32-bytes-long"))
	for i, want := range []int{200, 429} {
		r := httptest.NewRequest("GET", "/v1/boot", nil)
		r.Header.Set("Authorization", "Bearer "+pair.AccessToken)
		w := httptest.NewRecorder()
		srv.Handler().ServeHTTP(w, r)
		if w.Code != want {
			t.Fatalf("boot request %d: want %d got %d", i, want, w.Code)
		}
	}
}

func TestPostgresBearerStoreOutageIsRetryable(t *testing.T) {
	st := postgresStore(t)
	sqlAccount(t, st.DB(), "outage-account")
	manager := tokens.NewSQLManager(st.DB(), []byte("only-a-local-test-secret-32-bytes-long"), time.Minute, time.Hour)
	pair, err := manager.IssuePair(context.Background(), "outage-account", "login")
	if err != nil {
		t.Fatal(err)
	}
	catalog, _ := server.NewCatalog(nil)
	srv := server.NewOnline(config.Default(), st.DB(), identity.NewService(identity.NewSQLRepository(st.DB())), manager, catalog, []byte("only-a-local-test-secret-32-bytes-long"))
	st.DB().Close()
	for _, path := range []string{"/v1/boot", "/v1/auth/logout"} {
		method := "GET"
		var body io.Reader
		if path != "/v1/boot" {
			method = "POST"
			body = strings.NewReader("{}")
		}
		r := httptest.NewRequest(method, path, body)
		r.Header.Set("Authorization", "Bearer "+pair.AccessToken)
		r.Header.Set("Content-Type", "application/json")
		r.Header.Set(api.IdempotencyKeyHeader, "logout")
		w := httptest.NewRecorder()
		srv.Handler().ServeHTTP(w, r)
		if w.Code != 503 {
			t.Fatalf("store outage at %s misclassified: %d", path, w.Code)
		}
	}
}

func TestPostgresPrivateFailedAuthIsBoundedWithoutChargingSuccesses(t *testing.T) {
	st := postgresStore(t)
	sqlAccount(t, st.DB(), "auth-rate-account")
	cfg := config.Default()
	cfg.RateLimitPreAuthPerIP = 1
	cfg.RateLimitAuthPerAccount = 5
	manager := tokens.NewSQLManager(st.DB(), []byte("only-a-local-test-secret-32-bytes-long"), time.Minute, time.Hour)
	pair, err := manager.IssuePair(context.Background(), "auth-rate-account", "login")
	if err != nil {
		t.Fatal(err)
	}
	catalog, _ := server.NewCatalog(nil)
	srv := server.NewOnline(cfg, st.DB(), identity.NewService(identity.NewSQLRepository(st.DB())), manager, catalog, []byte("only-a-local-test-secret-32-bytes-long"))
	call := func(token, ip string) int {
		r := httptest.NewRequest("GET", "/v1/boot", nil)
		r.RemoteAddr = ip + ":1234"
		r.Header.Set("Authorization", "Bearer "+token)
		w := httptest.NewRecorder()
		srv.Handler().ServeHTTP(w, r)
		return w.Code
	}
	for i := 0; i < 5; i++ {
		if code := call(pair.AccessToken, "192.0.2.1"); code != 200 {
			t.Fatalf("success consumed failure-only budget: %d", code)
		}
	}
	if code := call(pair.AccessToken, "192.0.2.1"); code != 429 {
		t.Fatalf("account budget not preserved: %d", code)
	}
	if err := manager.Logout(context.Background(), pair.AccessToken); err != nil {
		t.Fatal(err)
	}
	short := tokens.NewSQLManager(st.DB(), []byte("only-a-local-test-secret-32-bytes-long"), time.Second, time.Hour)
	expired, err := short.IssuePair(context.Background(), "auth-rate-account", "expired")
	if err != nil {
		t.Fatal(err)
	}
	time.Sleep(time.Until(expired.AccessExpiresAt) + 10*time.Millisecond)
	for i, token := range []string{"invalid", pair.AccessToken, expired.AccessToken} {
		ip := fmt.Sprintf("192.0.2.%d", i+10)
		for _, want := range []int{401, 429} {
			if code := call(token, ip); code != want {
				t.Errorf("invalid/revoked/expired attempt: want %d got %d", want, code)
			}
		}
	}
	// Once the failed signed bearer exhausts admission, no further SQL lookup
	// occurs: even a closed store must return 429 rather than dependency failure.
	if code := call(pair.AccessToken, "192.0.2.99"); code != 401 {
		t.Fatalf("first revoked attempt=%d", code)
	}
	if err := st.DB().Close(); err != nil {
		t.Fatal(err)
	}
	if code := call(pair.AccessToken, "192.0.2.99"); code != 429 {
		t.Fatalf("throttled bearer reached closed store: %d", code)
	}

}
