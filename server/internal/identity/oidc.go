package identity

import (
	"context"
	"crypto"
	"crypto/hmac"
	"crypto/rsa"
	"crypto/sha256"
	"encoding/base64"
	"encoding/json"
	"errors"
	"io"
	"math/big"
	"net/http"
	"net/url"
	"psychosims.dev/server/internal/api"
	"strings"
	"sync"
	"time"
)

// OIDCConfig is trusted operator configuration, never taken from an HTTP body.
type OIDCConfig struct{ Provider, ClientID, ClientSecret, Issuer, JWKSURL, AuthorizationURL, TokenURL string }
type OIDCProvider struct {
	cfg             OIDCConfig
	client          *http.Client
	mu              sync.Mutex
	keys            map[string]*rsa.PublicKey
	expires         time.Time
	lastFetch       time.Time
	lastFetchFailed bool
}

func NewOIDCProvider(cfg OIDCConfig, client *http.Client) (*OIDCProvider, error) {
	if cfg.ClientID == "" || cfg.Issuer == "" || (cfg.Provider != "google" && cfg.Provider != "apple") {
		return nil, errors.New("invalid OIDC configuration")
	}
	for _, raw := range []string{cfg.JWKSURL, cfg.AuthorizationURL, cfg.TokenURL} {
		u, err := url.Parse(raw)
		if err != nil || u.Scheme != "https" || u.Host == "" || u.User != nil || u.Fragment != "" {
			return nil, errors.New("OIDC endpoints must use HTTPS")
		}
	}
	if client == nil {
		client = &http.Client{Timeout: 10 * time.Second}
	}
	copyClient := *client
	if copyClient.Timeout == 0 {
		copyClient.Timeout = 10 * time.Second
	}
	copyClient.CheckRedirect = func(*http.Request, []*http.Request) error { return errors.New("OIDC endpoint redirects forbidden") }
	return &OIDCProvider{cfg: cfg, client: &copyClient}, nil
}
func (p *OIDCProvider) Verify(ctx context.Context, token, nonce string) (ProviderIdentity, error) {
	invalid := errors.New("invalid identity proof")
	if len(token) > 16384 || len(nonce) < 8 || len(nonce) > 256 {
		return ProviderIdentity{}, invalid
	}
	parts := strings.Split(token, ".")
	if len(parts) != 3 {
		return ProviderIdentity{}, invalid
	}
	var header struct {
		Alg string `json:"alg"`
		Kid string `json:"kid"`
	}
	hb, err := base64.RawURLEncoding.DecodeString(parts[0])
	if err != nil || json.Unmarshal(hb, &header) != nil || header.Alg != "RS256" || header.Kid == "" || len(header.Kid) > 128 {
		return ProviderIdentity{}, invalid
	}
	key, err := p.key(ctx, header.Kid)
	if err != nil {
		return ProviderIdentity{}, err
	}
	sig, err := base64.RawURLEncoding.DecodeString(parts[2])
	if err != nil {
		return ProviderIdentity{}, invalid
	}
	digest := sha256.Sum256([]byte(parts[0] + "." + parts[1]))
	if rsa.VerifyPKCS1v15(key, crypto.SHA256, digest[:], sig) != nil {
		return ProviderIdentity{}, invalid
	}
	var c struct {
		Issuer          string          `json:"iss"`
		Audience        json.RawMessage `json:"aud"`
		Subject         string          `json:"sub"`
		Nonce           string          `json:"nonce"`
		AuthorizedParty string          `json:"azp"`
		IssuedAt        int64           `json:"iat"`
		ExpiresAt       int64           `json:"exp"`
		NotBefore       int64           `json:"nbf"`
	}
	body, err := base64.RawURLEncoding.DecodeString(parts[1])
	if err != nil || json.Unmarshal(body, &c) != nil {
		return ProviderIdentity{}, invalid
	}
	issuerOK := c.Issuer == p.cfg.Issuer || (p.cfg.Provider == "google" && p.cfg.Issuer == "https://accounts.google.com" && c.Issuer == "accounts.google.com")
	now := time.Now().Unix()
	if !issuerOK || c.Subject == "" || len(c.Subject) > 255 || c.ExpiresAt <= now || c.IssuedAt <= 0 || c.IssuedAt > now+30 || c.ExpiresAt <= c.IssuedAt || c.NotBefore > now+30 || !hmac.Equal([]byte(c.Nonce), []byte(nonce)) {
		return ProviderIdentity{}, invalid
	}
	var audiences []string
	var single string
	if json.Unmarshal(c.Audience, &single) == nil {
		audiences = []string{single}
	} else if json.Unmarshal(c.Audience, &audiences) != nil {
		return ProviderIdentity{}, invalid
	}
	found := false
	for _, aud := range audiences {
		if aud == p.cfg.ClientID {
			found = true
		}
	}
	if !found || (len(audiences) > 1 && c.AuthorizedParty != p.cfg.ClientID) || (c.AuthorizedParty != "" && c.AuthorizedParty != p.cfg.ClientID) {
		return ProviderIdentity{}, invalid
	}
	return ProviderIdentity{Provider: p.cfg.Provider, ProviderID: c.Subject}, nil
}
func (p *OIDCProvider) key(ctx context.Context, kid string) (*rsa.PublicKey, error) {
	p.mu.Lock()
	defer p.mu.Unlock()
	now := time.Now()
	if now.Before(p.expires) {
		if key := p.keys[kid]; key != nil {
			return key, nil
		}
	}
	// Unknown attacker-selected kids cannot turn the public route into an
	// unbounded JWKS fetcher. Cache misses refresh at most once per 30 seconds.
	if now.Sub(p.lastFetch) < 30*time.Second {
		if p.lastFetchFailed {
			return nil, api.NewServiceUnavailable("identity provider temporarily unavailable")
		}
		return nil, errors.New("unknown provider signing key")
	}
	p.lastFetch = now
	p.lastFetchFailed = true
	req, err := http.NewRequestWithContext(ctx, http.MethodGet, p.cfg.JWKSURL, nil)
	if err != nil {
		return nil, err
	}
	resp, err := p.client.Do(req)
	if err != nil {
		return nil, api.NewServiceUnavailable("identity provider temporarily unavailable")
	}
	defer resp.Body.Close()
	if resp.StatusCode != http.StatusOK {
		return nil, api.NewServiceUnavailable("identity provider temporarily unavailable")
	}
	body, err := io.ReadAll(io.LimitReader(resp.Body, 65537))
	if err != nil || len(body) > 65536 {
		return nil, api.NewServiceUnavailable("identity provider keys unavailable")
	}
	var set struct {
		Keys []struct{ Kty, Kid, Alg, Use, N, E string }
	}
	if json.Unmarshal(body, &set) != nil || len(set.Keys) > 32 {
		return nil, api.NewServiceUnavailable("identity provider keys unavailable")
	}
	keys := map[string]*rsa.PublicKey{}
	for _, j := range set.Keys {
		if j.Kty != "RSA" || j.Kid == "" || (j.Alg != "" && j.Alg != "RS256") || (j.Use != "" && j.Use != "sig") {
			continue
		}
		n, ne := base64.RawURLEncoding.DecodeString(j.N)
		e, ee := base64.RawURLEncoding.DecodeString(j.E)
		if ne != nil || ee != nil || len(n) < 256 || len(n) > 512 || len(e) == 0 || len(e) > 4 {
			continue
		}
		exponent := new(big.Int).SetBytes(e).Int64()
		if exponent < 3 || exponent > 2147483647 || exponent%2 == 0 {
			continue
		}
		if keys[j.Kid] != nil {
			return nil, api.NewServiceUnavailable("identity provider keys unavailable")
		}
		keys[j.Kid] = &rsa.PublicKey{N: new(big.Int).SetBytes(n), E: int(exponent)}
	}
	p.lastFetchFailed = false
	p.keys = keys
	p.expires = now.Add(5 * time.Minute)
	if key := keys[kid]; key != nil {
		return key, nil
	}
	return nil, errors.New("unknown provider signing key")
}
func (p *OIDCProvider) AuthorizationURL(s AuthSession) string {
	u, _ := url.Parse(p.cfg.AuthorizationURL)
	q := u.Query()
	q.Set("client_id", p.cfg.ClientID)
	q.Set("response_type", "code")
	if p.cfg.Provider == "google" {
		q.Set("scope", "openid")
	} else {
		q.Del("scope")
		q.Set("response_mode", "query")
	}
	q.Set("redirect_uri", s.RedirectURI)
	q.Set("state", s.State)
	q.Set("nonce", s.Nonce)
	q.Set("code_challenge", s.CodeChallenge)
	q.Set("code_challenge_method", "S256")
	u.RawQuery = q.Encode()
	return u.String()
}

// Exchange sends the provider authorization code to its configured token
// endpoint. A code is never accepted directly as an ID-token credential.
func (p *OIDCProvider) Exchange(ctx context.Context, code, redirect, verifier string) (string, error) {
	if code == "" || len(code) > 4096 {
		return "", errors.New("invalid authorization code")
	}
	form := url.Values{"grant_type": {"authorization_code"}, "client_id": {p.cfg.ClientID}, "code": {code}, "redirect_uri": {redirect}, "code_verifier": {verifier}}
	if p.cfg.ClientSecret != "" {
		form.Set("client_secret", p.cfg.ClientSecret)
	}
	req, err := http.NewRequestWithContext(ctx, http.MethodPost, p.cfg.TokenURL, strings.NewReader(form.Encode()))
	if err != nil {
		return "", err
	}
	req.Header.Set("Content-Type", "application/x-www-form-urlencoded")
	resp, err := p.client.Do(req)
	if err != nil {
		return "", api.NewServiceUnavailable("identity provider temporarily unavailable")
	}
	defer resp.Body.Close()
	if resp.StatusCode == 408 || resp.StatusCode == 429 || resp.StatusCode >= 500 {
		return "", api.NewServiceUnavailable("identity provider temporarily unavailable")
	}
	if resp.StatusCode != http.StatusOK {
		return "", errors.New("provider rejected authorization code")
	}
	body, err := io.ReadAll(io.LimitReader(resp.Body, 32769))
	if err != nil || len(body) > 32768 {
		return "", errors.New("invalid provider token response")
	}
	var result struct {
		IDToken string `json:"id_token"`
	}
	if json.Unmarshal(body, &result) != nil || result.IDToken == "" {
		return "", errors.New("provider token response omitted ID token")
	}
	return result.IDToken, nil
}
