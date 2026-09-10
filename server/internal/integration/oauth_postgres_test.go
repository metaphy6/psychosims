//go:build postgres

package integration

import (
	"bytes"
	"crypto"
	"crypto/rand"
	"crypto/rsa"
	"crypto/sha256"
	"encoding/base64"
	"encoding/json"
	"math/big"
	"net/http"
	"net/http/httptest"
	"strings"
	"sync/atomic"
	"testing"
	"time"

	"psychosims.dev/server/internal/api"
	"psychosims.dev/server/internal/config"
	"psychosims.dev/server/internal/identity"
	"psychosims.dev/server/internal/server"
	"psychosims.dev/server/internal/tokens"
)

func TestPostgresOAuthCodeExchangeLostResponseReplay(t *testing.T) {
	st := postgresStore(t)
	key, err := rsa.GenerateKey(rand.Reader, 2048)
	if err != nil {
		t.Fatal(err)
	}
	var nonce string
	var exchanges atomic.Int32
	verifier := strings.Repeat("v", 43)
	challenge := sha256.Sum256([]byte(verifier))
	fixture := httptest.NewTLSServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		if r.URL.Path == "/token" {
			exchanges.Add(1)
			if err := r.ParseForm(); err != nil {
				t.Error(err)
			}
			if r.Form.Get("code") != "provider-code" || r.Form.Get("redirect_uri") != "https://registered.example/callback" || r.Form.Get("code_verifier") != verifier || r.Form.Get("grant_type") != "authorization_code" {
				t.Error("real code exchange omitted registered parameters")
			}
			h, _ := json.Marshal(map[string]string{"alg": "RS256", "kid": "test"})
			c, _ := json.Marshal(map[string]any{"iss": "https://fixture.example", "aud": "client", "sub": "oauth-subject", "nonce": nonce, "iat": time.Now().Unix(), "exp": time.Now().Add(time.Hour).Unix()})
			unsigned := base64.RawURLEncoding.EncodeToString(h) + "." + base64.RawURLEncoding.EncodeToString(c)
			digest := sha256.Sum256([]byte(unsigned))
			signature, _ := rsa.SignPKCS1v15(rand.Reader, key, crypto.SHA256, digest[:])
			json.NewEncoder(w).Encode(map[string]string{"id_token": unsigned + "." + base64.RawURLEncoding.EncodeToString(signature)})
			return
		}
		json.NewEncoder(w).Encode(map[string]any{"keys": []any{map[string]string{"kty": "RSA", "kid": "test", "alg": "RS256", "use": "sig", "n": base64.RawURLEncoding.EncodeToString(key.N.Bytes()), "e": base64.RawURLEncoding.EncodeToString(big.NewInt(int64(key.E)).Bytes())}}})
	}))
	defer fixture.Close()
	p, err := identity.NewOIDCProvider(identity.OIDCConfig{Provider: "google", ClientID: "client", Issuer: "https://fixture.example", JWKSURL: fixture.URL + "/keys", AuthorizationURL: fixture.URL + "/authorize", TokenURL: fixture.URL + "/token"}, fixture.Client())
	if err != nil {
		t.Fatal(err)
	}
	secret := []byte(strings.Repeat("s", 32))
	ids := identity.NewServiceWithPKCE(identity.NewSQLRepository(st.DB()), identity.NewSQLStateStore(st.DB()), secret, identity.OAuthConfig{DesktopRedirectURIs: map[string]string{"direct_download": "https://registered.example/callback"}, PKCEEnabled: true})
	ids.RegisterProvider("google", p)
	cfg := config.Default()
	cfg.RateLimitPreAuthPerIP = 1000
	catalog, _ := server.NewCatalog(nil)
	srv := server.NewOnline(cfg, st.DB(), ids, tokens.NewSQLManager(st.DB(), secret, time.Minute, time.Hour), catalog, secret)
	call := func(path, idem string, body any) *httptest.ResponseRecorder {
		t.Helper()
		b, _ := json.Marshal(body)
		req := httptest.NewRequest("POST", path, bytes.NewReader(b))
		req.Header.Set("Content-Type", "application/json")
		req.Header.Set(api.IdempotencyKeyHeader, idem)
		w := httptest.NewRecorder()
		srv.Handler().ServeHTTP(w, req)
		return w
	}
	start := call("/v1/auth/start", "start", map[string]string{"provider": "google", "channel": "direct_download", "code_challenge": base64.RawURLEncoding.EncodeToString(challenge[:]), "code_challenge_method": "S256"})
	if start.Code != 200 {
		t.Fatalf("start: %d %s", start.Code, start.Body)
	}
	startRetry := call("/v1/auth/start", "start", map[string]string{"provider": "google", "channel": "direct_download", "code_challenge": base64.RawURLEncoding.EncodeToString(challenge[:]), "code_challenge_method": "S256"})
	if startRetry.Code != 200 || !bytes.Equal(start.Body.Bytes(), startRetry.Body.Bytes()) {
		t.Fatalf("auth start retry changed state: %d %s", startRetry.Code, startRetry.Body)
	}
	changedStart := call("/v1/auth/start", "start", map[string]string{"provider": "google", "channel": "direct_download", "code_challenge": strings.Repeat("a", 43), "code_challenge_method": "S256"})
	if changedStart.Code != 409 {
		t.Fatalf("auth start operation reused differently: %d", changedStart.Code)
	}
	var state struct {
		State string `json:"state"`
		Nonce string `json:"nonce"`
	}
	json.Unmarshal(start.Body.Bytes(), &state)
	nonce = state.Nonce
	body := map[string]string{"state": state.State, "code": "provider-code", "code_verifier": verifier}
	first := call("/v1/auth/exchange", "exchange", body)
	if first.Code != 200 {
		t.Fatalf("exchange: %d %s", first.Code, first.Body)
	}
	again := call("/v1/auth/exchange", "exchange", body)
	if again.Code != 200 || !bytes.Equal(first.Body.Bytes(), again.Body.Bytes()) {
		t.Fatalf("lost-response replay: %d %s", again.Code, again.Body)
	}
	if exchanges.Load() != 1 {
		t.Fatal("provider authorization code exchanged more than once")
	}
	if changed := call("/v1/auth/exchange", "other-key", body); changed.Code < 400 {
		t.Fatal("consumed authorization state accepted under different operation")
	}
	if n := countRows(t, st.DB(), "auth_sessions"); n != 1 {
		t.Fatal("exchange replay duplicated auth session")
	}
}
