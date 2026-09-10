package identity

import (
	"context"
	"crypto"
	"crypto/rand"
	"crypto/rsa"
	"crypto/sha256"
	"encoding/base64"
	"encoding/json"
	"errors"
	"math/big"
	"net/http"
	"net/http/httptest"
	"net/url"
	"psychosims.dev/server/internal/api"
	"strings"
	"sync/atomic"
	"testing"
	"time"
)

func oidcToken(t *testing.T, key *rsa.PrivateKey, claims map[string]any) string {
	t.Helper()
	h, _ := json.Marshal(map[string]string{"alg": "RS256", "kid": "fixture", "typ": "JWT"})
	b, _ := json.Marshal(claims)
	input := base64.RawURLEncoding.EncodeToString(h) + "." + base64.RawURLEncoding.EncodeToString(b)
	digest := sha256.Sum256([]byte(input))
	sig, err := rsa.SignPKCS1v15(rand.Reader, key, crypto.SHA256, digest[:])
	if err != nil {
		t.Fatal(err)
	}
	return input + "." + base64.RawURLEncoding.EncodeToString(sig)
}
func TestOIDCVerifiedJWKSAndClaims(t *testing.T) {
	key, err := rsa.GenerateKey(rand.Reader, 2048)
	if err != nil {
		t.Fatal(err)
	}
	var requests atomic.Int32
	jwks := httptest.NewTLSServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		requests.Add(1)
		json.NewEncoder(w).Encode(map[string]any{"keys": []any{map[string]string{"kty": "RSA", "kid": "fixture", "alg": "RS256", "use": "sig", "n": base64.RawURLEncoding.EncodeToString(key.N.Bytes()), "e": base64.RawURLEncoding.EncodeToString(big.NewInt(int64(key.E)).Bytes())}}})
	}))
	defer jwks.Close()
	cfg := OIDCConfig{Provider: "google", ClientID: "client", Issuer: "https://issuer.example", JWKSURL: jwks.URL, AuthorizationURL: jwks.URL + "/authorize", TokenURL: jwks.URL + "/token"}
	provider, err := NewOIDCProvider(cfg, jwks.Client())
	if err != nil {
		t.Fatal(err)
	}
	claims := func() map[string]any {
		return map[string]any{"iss": cfg.Issuer, "aud": "client", "sub": "subject", "nonce": "expected-nonce", "iat": time.Now().Unix(), "exp": time.Now().Add(time.Hour).Unix()}
	}
	id, err := provider.Verify(context.Background(), oidcToken(t, key, claims()), "expected-nonce")
	if err != nil || id.ProviderID != "subject" {
		t.Fatalf("verified fixture rejected: %v", err)
	}
	cases := map[string]func(map[string]any){"issuer": func(c map[string]any) { c["iss"] = "attacker" }, "audience": func(c map[string]any) { c["aud"] = "other" }, "nonce": func(c map[string]any) { c["nonce"] = "wrong" }, "expired": func(c map[string]any) { c["exp"] = time.Now().Add(-time.Second).Unix() }, "future": func(c map[string]any) { c["iat"] = time.Now().Add(time.Hour).Unix() }, "empty subject": func(c map[string]any) { c["sub"] = "" }, "azp": func(c map[string]any) { c["aud"] = []string{"client", "other"}; c["azp"] = "other" }}
	for name, mutate := range cases {
		t.Run(name, func(t *testing.T) {
			c := claims()
			mutate(c)
			if _, err := provider.Verify(context.Background(), oidcToken(t, key, c), "expected-nonce"); err == nil {
				t.Fatal("untrusted token accepted")
			}
		})
	}
	forged := oidcToken(t, key, claims())
	parts := strings.Split(forged, ".")
	parts[2] = base64.RawURLEncoding.EncodeToString(make([]byte, 256))
	if _, err := provider.Verify(context.Background(), strings.Join(parts, "."), "expected-nonce"); err == nil {
		t.Fatal("forged signature accepted")
	}
	if _, err := provider.Verify(context.Background(), forged, ""); err == nil {
		t.Fatal("empty nonce accepted")
	}
	if requests.Load() != 1 {
		t.Fatalf("JWKS cache not used: %d", requests.Load())
	}
}

func TestOAuthUsesStoredProviderAndRealCodeExchange(t *testing.T) {
	verifier := strings.Repeat("a", 43)
	sum := sha256.Sum256([]byte(verifier))
	challenge := base64.RawURLEncoding.EncodeToString(sum[:])
	svc := NewServiceWithPKCE(NewInMemoryRepository(), NewInMemoryStateStore(), []byte(strings.Repeat("s", 32)), OAuthConfig{DesktopRedirectURIs: map[string]string{"direct_download": "https://registered.example/callback"}, PKCEEnabled: true})
	p := &codeProvider{t: t}
	svc.RegisterProvider("google", p)
	state, nonce, err := svc.StartAuthSession(context.Background(), "google", "direct_download", challenge, "S256")
	if err != nil {
		t.Fatal(err)
	}
	p.nonce = nonce
	if _, err := svc.ExchangeCode(context.Background(), "apple", "real-code", state, verifier); err == nil {
		t.Fatal("provider substitution accepted")
	}
	id, err := svc.ExchangeCode(context.Background(), "google", "real-code", state, verifier)
	if err != nil || id == "" {
		t.Fatalf("code exchange: %v", err)
	}
	if p.calls != 1 {
		t.Fatal("authorization code was not exchanged")
	}
	if _, err := svc.ExchangeCode(context.Background(), "google", "real-code", state, verifier); err == nil {
		t.Fatal("one-use state replay accepted")
	}
	for _, method := range []string{"plain", "unknown", ""} {
		if _, _, err := svc.StartAuthSession(context.Background(), "google", "direct_download", challenge, method); err == nil {
			t.Fatalf("PKCE downgrade %q accepted", method)
		}
	}
}

type codeProvider struct {
	t     *testing.T
	nonce string
	calls int
}

func (p *codeProvider) Verify(_ context.Context, token, nonce string) (ProviderIdentity, error) {
	if token != "exchanged-id-token" || nonce != p.nonce {
		p.t.Error("code masqueraded as ID token or nonce changed")
	}
	return ProviderIdentity{ProviderID: "subject"}, nil
}
func (p *codeProvider) Exchange(_ context.Context, code, redirect, verifier string) (string, error) {
	p.calls++
	if code != "real-code" || redirect != "https://registered.example/callback" || verifier != strings.Repeat("a", 43) {
		p.t.Error("exchange omitted stored redirect or PKCE")
	}
	return "exchanged-id-token", nil
}

func TestProviderOutageRemainsRetryableAndSanitized(t *testing.T) {
	remote := httptest.NewTLSServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) { w.WriteHeader(503) }))
	defer remote.Close()
	p, err := NewOIDCProvider(OIDCConfig{Provider: "google", ClientID: "client", Issuer: "https://issuer.example", JWKSURL: remote.URL, AuthorizationURL: remote.URL, TokenURL: remote.URL}, remote.Client())
	if err != nil {
		t.Fatal(err)
	}
	svc := NewService(NewInMemoryRepository())
	svc.RegisterProvider("google", p)
	header, _ := json.Marshal(map[string]string{"alg": "RS256", "kid": "fixture"})
	token := base64.RawURLEncoding.EncodeToString(header) + ".e30.AA"
	for i := 0; i < 2; i++ {
		_, err := svc.SignIn(context.Background(), "google", token, "public-test-nonce")
		var he api.HTTPError
		if !errors.As(err, &he) || he.Status != 503 {
			t.Fatalf("provider outage became permanent credential rejection: %v", err)
		}
	}
	svc.RegisterProvider("google", &StubVerifier{Err: errors.New("raw-private-provider-detail")})
	_, err = svc.SignIn(context.Background(), "google", "proof", "nonce")
	if strings.Contains(err.Error(), "raw-private") {
		t.Fatal("raw provider error disclosed")
	}
}

func TestAppleAuthorizationDoesNotRequestUnsupportedScope(t *testing.T) {
	p, err := NewOIDCProvider(OIDCConfig{Provider: "apple", ClientID: "client", Issuer: "https://appleid.apple.com", JWKSURL: "https://appleid.apple.com/auth/keys", AuthorizationURL: "https://appleid.apple.com/auth/authorize", TokenURL: "https://appleid.apple.com/auth/token"}, nil)
	if err != nil {
		t.Fatal(err)
	}
	u, err := url.Parse(p.AuthorizationURL(AuthSession{State: "state", Nonce: "nonce", RedirectURI: "https://registered.example/callback", CodeChallenge: strings.Repeat("a", 43)}))
	if err != nil {
		t.Fatal(err)
	}
	if u.Query().Get("scope") != "" || u.Query().Get("response_mode") != "query" {
		t.Fatal("Apple code redirect requests unsupported OIDC scope or response mode")
	}
}
