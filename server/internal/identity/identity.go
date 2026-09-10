// Package identity implements server-authoritative identity for Phase 3.1.
//
// Google/Apple OAuth token verification is abstracted behind an interface so
// the production verifier can call the providers while tests supply a stub.
// Account linking resolves multiple provider identities to one account id.
package identity

import (
	"context"
	"crypto/hmac"
	"crypto/rand"
	"crypto/sha256"
	"encoding/base64"
	"encoding/hex"
	"errors"
	"fmt"
	"strings"
	"time"

	"psychosims.dev/server/internal/api"
)

// ProviderIdentity is the verified result from an OAuth provider.
type ProviderIdentity struct {
	Provider   string `json:"provider"`
	ProviderID string `json:"provider_id"`
	Email      string `json:"email"`
}

// ProviderVerifier checks an OAuth id_token / authorization credential.
type ProviderVerifier interface {
	Verify(ctx context.Context, token, nonce string) (ProviderIdentity, error)
}

// Account is the server-authoritative identity record.
type Account struct {
	ID        string    `json:"id"`
	CreatedAt time.Time `json:"created_at"`
	UpdatedAt time.Time `json:"updated_at"`
}

// Repository abstracts account persistence.
type Repository interface {
	// FindByProvider returns the account id linked to a provider identity, or "".
	FindByProvider(ctx context.Context, provider, providerID string) (string, error)
	// CreateAccount creates a new account and returns its id.
	CreateAccount(ctx context.Context) (string, error)
	// LinkProvider attaches a provider identity to an account.
	LinkProvider(ctx context.Context, accountID string, identity ProviderIdentity) error
	// GetAccount returns an account by id.
	GetAccount(ctx context.Context, accountID string) (*Account, error)
}

// OAuthConfig surfaces desktop distribution-channel redirect URIs for the
// deep-link OAuth flow (ADR-0002). Steam is a distribution channel only; auth
// still flows through Google/Apple.
type OAuthConfig struct {
	DesktopRedirectURIs map[string]string
	PKCEEnabled         bool
}

// DefaultOAuthConfig returns the dev-local OAuth surface.
func DefaultOAuthConfig() OAuthConfig {
	return OAuthConfig{
		DesktopRedirectURIs: map[string]string{
			"steam":           "https://auth.psychosims.dev/callback/steam",
			"direct_download": "https://auth.psychosims.dev/callback/direct",
		},
		PKCEEnabled: true,
	}
}

// AuthSession holds the PKCE + nonce state for one desktop OAuth attempt.
type AuthSession struct {
	State               string    `json:"state"`
	Nonce               string    `json:"nonce"`
	CodeChallenge       string    `json:"code_challenge"`
	CodeChallengeMethod string    `json:"code_challenge_method"`
	RedirectURI         string    `json:"redirect_uri"`
	Provider            string    `json:"provider"`
	ExpiresAt           time.Time `json:"expires_at"`
}

// StateStore holds short-lived signed OAuth state/nonce sessions.
type StateStore interface {
	Create(ctx context.Context, session AuthSession) error
	Peek(ctx context.Context, state string) (*AuthSession, error)
	Consume(ctx context.Context, state string) (*AuthSession, error)
}

// InMemoryStateStore is a test implementation of StateStore.
type InMemoryStateStore struct {
	sessions map[string]AuthSession
}

// NewInMemoryStateStore creates a test state store.
func NewInMemoryStateStore() *InMemoryStateStore {
	return &InMemoryStateStore{sessions: make(map[string]AuthSession)}
}

// Create stores a session keyed by its signed state value.
func (s *InMemoryStateStore) Create(ctx context.Context, session AuthSession) error {
	s.sessions[session.State] = session
	return nil
}

// Peek returns a session without removing it.
func (s *InMemoryStateStore) Peek(ctx context.Context, state string) (*AuthSession, error) {
	session, ok := s.sessions[state]
	if !ok {
		return nil, errors.New("unknown or expired state")
	}
	if time.Now().UTC().After(session.ExpiresAt) {
		return nil, errors.New("state expired")
	}
	return &session, nil
}

// Consume returns and removes a session if it exists and has not expired.
func (s *InMemoryStateStore) Consume(ctx context.Context, state string) (*AuthSession, error) {
	session, err := s.Peek(ctx, state)
	if err != nil {
		return nil, err
	}
	delete(s.sessions, state)
	return session, nil
}

// Service resolves OAuth credentials to server accounts.
type Service struct {
	verifiers   map[string]ProviderVerifier
	repo        Repository
	stateStore  StateStore
	stateSecret []byte
	oauthCfg    OAuthConfig
}

// NewService builds an identity service.
func NewService(repo Repository) *Service {
	return NewServiceWithPKCE(repo, NewInMemoryStateStore(), nil, DefaultOAuthConfig())
}

// NewServiceWithPKCE builds an identity service with PKCE / signed-state support.
func NewServiceWithPKCE(repo Repository, stateStore StateStore, stateSecret []byte, oauthCfg OAuthConfig) *Service {
	if len(stateSecret) == 0 {
		stateSecret = make([]byte, 32)
		_, _ = rand.Read(stateSecret)
	}
	return &Service{
		verifiers:   make(map[string]ProviderVerifier),
		repo:        repo,
		stateStore:  stateStore,
		stateSecret: stateSecret,
		oauthCfg:    oauthCfg,
	}
}

// OAuthConfig returns the configured OAuth redirect surface.
func (s *Service) OAuthConfig() OAuthConfig { return s.oauthCfg }

// RegisterProvider adds a verifier for a provider name ("google", "apple").
func (s *Service) RegisterProvider(name string, v ProviderVerifier) {
	s.verifiers[name] = v
}

// SignIn verifies an OAuth credential and returns the linked account id,
// creating a new account if this provider identity has not been seen before.
func (s *Service) SignIn(ctx context.Context, provider, token, nonce string) (string, error) {
	v, ok := s.verifiers[provider]
	if !ok {
		return "", api.NewUserError(api.CodeBadRequest, "unsupported identity provider")
	}

	identity, err := v.Verify(ctx, token, nonce)
	if err != nil {
		return "", providerFailure(err)
	}
	identity.Provider = provider
	if identity.ProviderID == "" || len(identity.ProviderID) > 255 {
		return "", api.NewUnauthorized("invalid provider subject")
	}
	if resolver, ok := s.repo.(interface {
		ResolveVerified(context.Context, ProviderIdentity) (string, error)
	}); ok {
		accountID, err := resolver.ResolveVerified(ctx, identity)
		if err != nil {
			return "", api.NewInternalError("account resolution failed")
		}
		return accountID, nil
	}

	accountID, err := s.repo.FindByProvider(ctx, provider, identity.ProviderID)
	if err != nil {
		return "", api.NewInternalError("account lookup failed: " + err.Error())
	}
	if accountID == "" {
		accountID, err = s.repo.CreateAccount(ctx)
		if err != nil {
			return "", api.NewInternalError("account creation failed: " + err.Error())
		}
		if err := s.repo.LinkProvider(ctx, accountID, identity); err != nil {
			return "", api.NewInternalError("account linking failed: " + err.Error())
		}
	}

	return accountID, nil
}

// LinkAccount links an additional provider identity to an existing account.
func (s *Service) LinkAccount(ctx context.Context, accountID, provider, token, nonce string) error {
	v, ok := s.verifiers[provider]
	if !ok {
		return api.NewUserError(api.CodeBadRequest, "unsupported identity provider")
	}
	identity, err := v.Verify(ctx, token, nonce)
	if err != nil {
		return providerFailure(err)
	}
	identity.Provider = provider

	existing, err := s.repo.FindByProvider(ctx, provider, identity.ProviderID)
	if err != nil {
		return api.NewInternalError("account lookup failed: " + err.Error())
	}
	if existing != "" && existing != accountID {
		return api.NewConflict(api.CodeConflict, "provider identity already linked to another account")
	}
	if err := s.repo.LinkProvider(ctx, accountID, identity); err != nil {
		if he, ok := err.(api.HTTPError); ok {
			return he
		}
		return api.NewInternalError("account linking failed: " + err.Error())
	}
	return nil
}

// InMemoryRepository is a test implementation of Repository.
type InMemoryRepository struct {
	accounts  map[string]*Account
	providers map[string]string // provider::provider_id -> account_id
	links     map[string][]ProviderIdentity
}

// NewInMemoryRepository creates a test repository.
func NewInMemoryRepository() *InMemoryRepository {
	return &InMemoryRepository{
		accounts:  make(map[string]*Account),
		providers: make(map[string]string),
		links:     make(map[string][]ProviderIdentity),
	}
}

func providerKey(provider, providerID string) string { return provider + "::" + providerID }

// FindByProvider implements Repository.
func (r *InMemoryRepository) FindByProvider(ctx context.Context, provider, providerID string) (string, error) {
	return r.providers[providerKey(provider, providerID)], nil
}

// CreateAccount implements Repository.
func (r *InMemoryRepository) CreateAccount(ctx context.Context) (string, error) {
	id, err := generateAccountID()
	if err != nil {
		return "", err
	}
	now := time.Now().UTC()
	r.accounts[id] = &Account{ID: id, CreatedAt: now, UpdatedAt: now}
	return id, nil
}

// LinkProvider implements Repository.
func (r *InMemoryRepository) LinkProvider(ctx context.Context, accountID string, identity ProviderIdentity) error {
	key := providerKey(identity.Provider, identity.ProviderID)
	if existing, ok := r.providers[key]; ok && existing != accountID {
		return errors.New("provider already linked")
	}
	r.providers[key] = accountID
	r.links[accountID] = append(r.links[accountID], identity)
	return nil
}

// GetAccount implements Repository.
func (r *InMemoryRepository) GetAccount(ctx context.Context, accountID string) (*Account, error) {
	acc, ok := r.accounts[accountID]
	if !ok {
		return nil, errors.New("account not found")
	}
	return acc, nil
}

// StubVerifier is a test verifier that returns a fixed identity.
type StubVerifier struct {
	Identity ProviderIdentity
	Err      error
}

// Verify implements ProviderVerifier.
func (s *StubVerifier) Verify(ctx context.Context, token, nonce string) (ProviderIdentity, error) {
	if s.Err != nil {
		return ProviderIdentity{}, s.Err
	}
	return s.Identity, nil
}

// StartAuthSession begins a desktop deep-link OAuth flow, returning a signed
// state value and a nonce for the client to include in its authorization
// request. The state value is integrity-protected with HMAC-SHA256.
func (s *Service) StartAuthSession(ctx context.Context, provider, channel, codeChallenge, codeChallengeMethod string) (state, nonce string, err error) {
	if codeChallengeMethod != "S256" || len(codeChallenge) != 43 || !validPKCE(codeChallenge) {
		return "", "", api.NewUserError(api.CodeBadRequest, "S256 PKCE challenge required")
	}
	if provider != "google" && provider != "apple" {
		return "", "", api.NewUserError(api.CodeBadRequest, "unsupported identity provider")
	}
	redirectURI, ok := s.oauthCfg.DesktopRedirectURIs[channel]
	if !ok {
		return "", "", api.NewUserError(api.CodeBadRequest, "unsupported desktop channel")
	}
	nonce, err = generateNonce()
	if err != nil {
		return "", "", err
	}
	rawState, err := generateNonce()
	if err != nil {
		return "", "", err
	}
	sig := signState(rawState, s.stateSecret)
	state = base64.RawURLEncoding.EncodeToString([]byte(rawState + "." + sig))

	session := AuthSession{
		State:               state,
		Nonce:               nonce,
		CodeChallenge:       codeChallenge,
		CodeChallengeMethod: normalizePKCEMethod(codeChallengeMethod),
		RedirectURI:         redirectURI,
		Provider:            provider,
		ExpiresAt:           time.Now().UTC().Add(10 * time.Minute),
	}
	if durable, ok := s.stateStore.(interface {
		CreateOrReplay(context.Context, AuthSession) (AuthSession, error)
	}); ok {
		session, err = durable.CreateOrReplay(ctx, session)
		if err != nil {
			return "", "", err
		}
		return session.State, session.Nonce, nil
	}
	if err := s.stateStore.Create(ctx, session); err != nil {
		return "", "", api.NewInternalError("state store failed: " + err.Error())
	}
	return state, nonce, nil
}

// VerifyState checks a returned state value and code verifier against the
// stored PKCE challenge without consuming the session, so the redirect handler
// can validate the redirect before the token exchange. It returns the stored
// nonce on success.
func (s *Service) VerifyState(ctx context.Context, state, codeVerifier string) (string, error) {
	if err := verifyStateSignature(state, s.stateSecret); err != nil {
		return "", api.NewUserError(api.CodeInvalidSignature, "invalid state signature")
	}
	session, err := s.stateStore.Peek(ctx, state)
	if err != nil {
		return "", api.NewUserError(api.CodeBadRequest, "unknown or expired state")
	}
	if err := verifyPKCE(codeVerifier, session.CodeChallenge, session.CodeChallengeMethod); err != nil {
		return "", api.NewUserError(api.CodeBadRequest, "pkce verification failed: "+err.Error())
	}
	return session.Nonce, nil
}

// ExchangeCode verifies PKCE state, consumes the session to prevent replay,
// then validates the provider id_token. It is the desktop-channel counterpart
// to SignIn.
func (s *Service) ExchangeCode(ctx context.Context, provider, code, state, codeVerifier string) (string, error) {
	nonce, err := s.VerifyState(ctx, state, codeVerifier)
	if err != nil {
		return "", err
	}
	session, err := s.stateStore.Peek(ctx, state)
	if err != nil || session.Provider != provider {
		return "", api.NewUserError(api.CodeBadRequest, "provider does not match authorization state")
	}
	exchanger, ok := s.verifiers[session.Provider].(interface {
		Exchange(context.Context, string, string, string) (string, error)
	})
	if !ok {
		return "", api.NewServiceUnavailable("provider code exchange unavailable")
	}
	if _, err := s.stateStore.Consume(ctx, state); err != nil {
		return "", api.NewUserError(api.CodeBadRequest, "unknown or expired state")
	}
	idToken, err := exchanger.Exchange(ctx, code, session.RedirectURI, codeVerifier)
	if err != nil {
		return "", api.NewUnauthorized("provider code exchange failed")
	}
	return s.SignIn(ctx, session.Provider, idToken, nonce)
}

// AuthSession returns stored handshake metadata without accepting caller provider
// or redirect choices during code exchange.
func (s *Service) AuthSession(ctx context.Context, state string) (*AuthSession, error) {
	return s.stateStore.Peek(ctx, state)
}
func (s *Service) AuthorizationURL(session AuthSession) (string, error) {
	p, ok := s.verifiers[session.Provider].(interface{ AuthorizationURL(AuthSession) string })
	if !ok {
		return "", api.NewServiceUnavailable("provider browser authorization unavailable")
	}
	return p.AuthorizationURL(session), nil
}

func normalizePKCEMethod(m string) string {
	m = strings.ToUpper(m)
	if m == "PLAIN" {
		return "plain"
	}
	return "S256"
}

func verifyPKCE(verifier, challenge, method string) error {
	if method != "S256" || len(verifier) < 43 || len(verifier) > 128 || !validPKCE(verifier) {
		return errors.New("invalid S256 verifier")
	}
	method = normalizePKCEMethod(method)
	var computed string
	if method == "S256" {
		h := sha256.Sum256([]byte(verifier))
		computed = base64.RawURLEncoding.EncodeToString(h[:])
	} else {
		computed = verifier
	}
	if !hmac.Equal([]byte(computed), []byte(challenge)) {
		return errors.New("code challenge mismatch")
	}
	return nil
}

func validPKCE(s string) bool {
	for _, c := range s {
		if !((c >= 'a' && c <= 'z') || (c >= 'A' && c <= 'Z') || (c >= '0' && c <= '9') || c == '-' || c == '_' || c == '.' || c == '~') {
			return false
		}
	}
	return true
}

// VerifyExchange uses a locked durable session supplied by the composition
// layer. Its caller atomically consumes that session with account/token writes.
func (s *Service) VerifyExchange(ctx context.Context, session AuthSession, code, verifier string) (ProviderIdentity, error) {
	if verifyStateSignature(session.State, s.stateSecret) != nil || !time.Now().Before(session.ExpiresAt) || verifyPKCE(verifier, session.CodeChallenge, session.CodeChallengeMethod) != nil {
		return ProviderIdentity{}, api.NewUnauthorized("invalid authorization state or verifier")
	}
	p := s.verifiers[session.Provider]
	exchanger, ok := p.(interface {
		Exchange(context.Context, string, string, string) (string, error)
	})
	if !ok {
		return ProviderIdentity{}, api.NewServiceUnavailable("provider code exchange unavailable")
	}
	token, err := exchanger.Exchange(ctx, code, session.RedirectURI, verifier)
	if err != nil {
		return ProviderIdentity{}, providerFailure(err)
	}
	verified, err := p.Verify(ctx, token, session.Nonce)
	if err != nil {
		return ProviderIdentity{}, providerFailure(err)
	}
	verified.Provider = session.Provider
	return verified, nil
}

func signState(rawState string, secret []byte) string {
	mac := hmac.New(sha256.New, secret)
	mac.Write([]byte(rawState))
	return base64.RawURLEncoding.EncodeToString(mac.Sum(nil))
}

func verifyStateSignature(state string, secret []byte) error {
	raw, err := base64.RawURLEncoding.DecodeString(state)
	if err != nil {
		return err
	}
	parts := strings.SplitN(string(raw), ".", 2)
	if len(parts) != 2 {
		return errors.New("malformed state")
	}
	want := signState(parts[0], secret)
	if !hmac.Equal([]byte(want), []byte(parts[1])) {
		return errors.New("state signature mismatch")
	}
	return nil
}

func generateNonce() (string, error) {
	b := make([]byte, 16)
	if _, err := rand.Read(b); err != nil {
		return "", fmt.Errorf("generate nonce: %w", err)
	}
	return base64.RawURLEncoding.EncodeToString(b), nil
}

func generateAccountID() (string, error) {
	b := make([]byte, 16)
	if _, err := rand.Read(b); err != nil {
		return "", fmt.Errorf("generate account id: %w", err)
	}
	return "acc_" + hex.EncodeToString(b), nil
}

// Provider diagnostics can contain URLs or credentials. Expose only the retry
// classification, never the underlying message.
func providerFailure(err error) error {
	var he api.HTTPError
	if errors.As(err, &he) && he.Status == 503 {
		return api.NewServiceUnavailable("identity provider temporarily unavailable")
	}
	return api.NewUnauthorized("provider verification failed; restart authorization")
}
