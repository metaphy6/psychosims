package server

import (
	"context"
	"crypto/hmac"
	"crypto/sha256"
	"database/sql"
	"encoding/binary"
	"encoding/hex"
	"encoding/json"
	"errors"
	"net/http"
	"strings"
	"time"

	"psychosims.dev/server/internal/api"
	"psychosims.dev/server/internal/audit"
	"psychosims.dev/server/internal/authz"
	"psychosims.dev/server/internal/config"
	"psychosims.dev/server/internal/ctxutil"
	"psychosims.dev/server/internal/devicekeys"
	"psychosims.dev/server/internal/health"
	"psychosims.dev/server/internal/idempotency"
	"psychosims.dev/server/internal/identity"
	"psychosims.dev/server/internal/middleware"
	"psychosims.dev/server/internal/offline"
	"psychosims.dev/server/internal/ownership"
	"psychosims.dev/server/internal/profile"
	"psychosims.dev/server/internal/psylog"
	"psychosims.dev/server/internal/ratelimit"
	"psychosims.dev/server/internal/receipts"
	"psychosims.dev/server/internal/ruleset"
	"psychosims.dev/server/internal/schemas"
	"psychosims.dev/server/internal/timeutil"
	"psychosims.dev/server/internal/tokens"
)

type onlineServices struct {
	cfg          *config.Config
	db           *sql.DB
	identity     *identity.Service
	tokens       *tokens.SQLManager
	keys         *devicekeys.Service
	receipts     *receipts.Service
	batch        *offline.Service
	catalog      *Catalog
	secret       []byte
	rates        *ratelimit.Service
	authAttempts *ratelimit.AuthAttemptGate
}

// NewOnline is the executable composition root. All authority-bearing services
// use PostgreSQL; provider verification must be explicitly injected.
func NewOnline(cfg *config.Config, db *sql.DB, ids *identity.Service, tm *tokens.SQLManager, catalog *Catalog, secret []byte, opts ...Option) *Server {
	keys := devicekeys.NewService(devicekeys.NewSQLRepository(db))
	prof := profile.NewSQLRepository(db)
	idem := idempotency.NewService(idempotency.NewSQLRepository(db), 24*time.Hour)
	limits := receipts.DefaultLimits()
	limits.MaxActions = cfg.MaxReceiptActions
	limits.MaxDeltas = cfg.MaxReceiptDeltas
	limits.MaxLedgerEvents = cfg.MaxReceiptLedgerEvents
	validator := receipts.NewVerifier(receipts.NewVerifierFromDeviceKeys(keys), prof, profile.NewLedger(db), idem, keys, &limits).WithRuleset(ruleset.NewRegistry(ruleset.Config{KnownVersions: catalog.rulesets(), SunsetWindow: cfg.RulesetSunsetWindow}))
	submit := receipts.NewService(validator, db, idem, audit.NewAppender(db), nil)
	if err := submit.ConfigureCertifiedOutcomes(catalog.outcomes, cfg.CureRewards, cfg.EconomyEnabled); err != nil {
		// Runtime configuration is validated before composition in psy-server.
		// Direct internal callers must satisfy the same bounded policy contract.
		panic("invalid certified outcome configuration")
	}
	online := &onlineServices{cfg: cfg, db: db, identity: ids, tokens: tm, keys: keys, receipts: submit, catalog: catalog, secret: append([]byte(nil), secret...), rates: ratelimit.NewService(ratelimit.Limits{PreAuthPerIP: cfg.RateLimitPreAuthPerIP, AuthPerAccount: cfg.RateLimitAuthPerAccount, Window: cfg.RateLimitWindow})}
	online.authAttempts = ratelimit.NewAuthAttemptGate(cfg.RateLimitPreAuthPerIP, cfg.RateLimitWindow)
	online.batch = offline.NewService(online.submit, ownership.NewSQLRepository(db), timeutil.RealClock{}, 24*time.Hour)
	options := []Option{WithProfileRepo(prof), WithHealthChecker(health.NewChecker(func(ctx context.Context) (string, bool) { return "store", db.PingContext(ctx) == nil })), func(s *Server) { s.online = online; s.inFlight = middleware.NewInFlightCounter(cfg.HTTPMaxInFlight) }}
	options = append(options, opts...)
	return New(timeutil.RealClock{}, options...)
}
func (s *Server) onlineRoutes() {
	public := func(path string, h http.HandlerFunc) {
		s.mux.Handle("POST "+path, ratelimit.Middleware(s.online.rates)(h))
	}
	private := func(path string, h http.HandlerFunc) {
		s.mux.Handle("POST "+path, s.requireAuth(ratelimit.Middleware(s.online.rates)(h)))
	}
	public("/v1/auth/id-token", s.handleIDToken)
	public("/v1/auth/refresh", s.handleRefresh)
	public("/v1/auth/start", s.handleAuthStart)
	public("/v1/auth/exchange", s.handleAuthExchange)
	// Logout independently verifies a signed session to make revocation retries
	// succeed even after requireAuth would reject that already revoked session.
	public("/v1/auth/logout", s.handleLogout)
	private("/v1/auth/link", s.handleLink)
	private("/v1/device-keys", s.handleDeviceKey)
	private("/v1/device-keys/recover", s.handleDeviceRecovery)
	private("/v1/sessions", s.handleSession)
	private("/v1/receipts", s.handleReceipt)
	private("/v1/receipts/batch", s.handleBatch)
	s.mux.Handle("GET /v1/public-keys", ratelimit.Middleware(s.online.rates)(http.HandlerFunc(s.handlePublicKeys)))
}
func writeFailure(w http.ResponseWriter, r *http.Request, err error) {
	var he api.HTTPError
	if errors.As(err, &he) {
		psylog.Default().Warn("api", "request_rejected", psylog.KV{"request_id": ctxutil.RequestID(r.Context()), "status": he.Status, "code": he.Body.Code})
		he.Write(w, ctxutil.RequestID(r.Context()))
		return
	}
	psylog.Default().Error("api", "request_failed", psylog.KV{"request_id": ctxutil.RequestID(r.Context())})
	api.NewInternalError("request could not be completed").Write(w, ctxutil.RequestID(r.Context()))
}
func decodeRequest(w http.ResponseWriter, r *http.Request, dst any, maxBytes int64, maxString int) bool {
	if ct := strings.Split(r.Header.Get("Content-Type"), ";")[0]; ct != "application/json" {
		writeFailure(w, r, api.NewUserError(api.CodeBadRequest, "application/json required"))
		return false
	}
	limits := middleware.DefaultDecoderLimits()
	limits.MaxBodyBytes = maxBytes
	limits.MaxStringFieldBytes = int64(maxString)
	if err := middleware.DecodeJSON(r, dst, limits); err != nil {
		writeFailure(w, r, err)
		return false
	}
	return true
}

type identityRequest struct {
	Provider string `json:"provider"`
	IDToken  string `json:"id_token"`
	Nonce    string `json:"nonce"`
}

func (s *Server) handleIDToken(w http.ResponseWriter, r *http.Request) {
	var in identityRequest
	if !decodeRequest(w, r, &in, 32768, 16384) {
		return
	}
	account, err := s.online.identity.SignIn(r.Context(), in.Provider, in.IDToken, in.Nonce)
	if err != nil {
		writeFailure(w, r, err)
		return
	}
	pair, err := s.online.tokens.IssuePair(r.Context(), account, "signin:"+ctxutil.IdempotencyKey(r.Context()))
	if err != nil {
		writeFailure(w, r, err)
		return
	}
	w.Header().Set("Cache-Control", "no-store")
	writeJSON(w, 200, pair)
}
func (s *Server) handleRefresh(w http.ResponseWriter, r *http.Request) {
	var in struct {
		RefreshToken string `json:"refresh_token"`
	}
	if !decodeRequest(w, r, &in, 8192, 4096) {
		return
	}
	pair, err := s.online.tokens.Rotate(r.Context(), in.RefreshToken, ctxutil.IdempotencyKey(r.Context()))
	if err != nil {
		if errors.Is(err, tokens.ErrInvalidToken) || errors.Is(err, tokens.ErrTokenExpired) || errors.Is(err, tokens.ErrTokenRevoked) || errors.Is(err, sql.ErrNoRows) {
			err = api.NewUnauthorized("invalid refresh token")
		}
		writeFailure(w, r, err)
		return
	}
	w.Header().Set("Cache-Control", "no-store")
	writeJSON(w, 200, pair)
}
func (s *Server) handleLogout(w http.ResponseWriter, r *http.Request) {
	var in struct{}
	if !decodeRequest(w, r, &in, 1024, 128) {
		return
	}
	if err := s.online.tokens.Logout(r.Context(), extractBearer(r)); err != nil {
		writeFailure(w, r, tokenFailure(err))
		return
	}
	writeJSON(w, 200, map[string]string{"status": "revoked"})
}
func (s *Server) handleLink(w http.ResponseWriter, r *http.Request) {
	var in identityRequest
	if !decodeRequest(w, r, &in, 32768, 16384) {
		return
	}
	account := ctxutil.AccountID(r.Context())
	if err := s.online.identity.LinkAccount(r.Context(), account, in.Provider, in.IDToken, in.Nonce); err != nil {
		writeFailure(w, r, err)
		return
	}
	writeJSON(w, 200, map[string]string{"account_id": account})
}
func (s *Server) handleAuthStart(w http.ResponseWriter, r *http.Request) {
	var in struct {
		Provider      string `json:"provider"`
		Channel       string `json:"channel"`
		RedirectURI   string `json:"redirect_uri,omitempty"`
		CodeChallenge string `json:"code_challenge"`
		Method        string `json:"code_challenge_method"`
	}
	if !decodeRequest(w, r, &in, 4096, 1024) {
		return
	}
	if in.RedirectURI != "" && in.RedirectURI != s.online.identity.OAuthConfig().DesktopRedirectURIs[in.Channel] {
		writeFailure(w, r, api.NewUserError(api.CodeBadRequest, "redirect is not registered for this channel"))
		return
	}
	state, nonce, err := s.online.identity.StartAuthSession(r.Context(), in.Provider, in.Channel, in.CodeChallenge, in.Method)
	if err != nil {
		writeFailure(w, r, err)
		return
	}
	session, err := s.online.identity.AuthSession(r.Context(), state)
	if err != nil {
		writeFailure(w, r, err)
		return
	}
	authURL, err := s.online.identity.AuthorizationURL(*session)
	if err != nil {
		writeFailure(w, r, err)
		return
	}
	w.Header().Set("Cache-Control", "no-store")
	writeJSON(w, 200, map[string]any{"state": state, "nonce": nonce, "authorization_url": authURL, "expires_at": session.ExpiresAt})
}
func (s *Server) handleAuthExchange(w http.ResponseWriter, r *http.Request) {
	var in struct {
		State    string `json:"state"`
		Code     string `json:"code"`
		Verifier string `json:"code_verifier"`
	}
	if !decodeRequest(w, r, &in, 8192, 4096) {
		return
	}
	pair, err := s.exchange(r.Context(), in.State, in.Code, in.Verifier, ctxutil.IdempotencyKey(r.Context()))
	if err != nil {
		writeFailure(w, r, err)
		return
	}
	w.Header().Set("Cache-Control", "no-store")
	writeJSON(w, 200, pair)
}

type keyRequest struct {
	PublicKey     []byte `json:"public_key"`
	SuiteID       string `json:"suite_id"`
	Platform      string `json:"platform,omitempty"`
	ReplacesKeyID string `json:"replaces_key_id,omitempty"`
}

func (s *Server) handleDeviceKey(w http.ResponseWriter, r *http.Request) { s.deviceKey(w, r, false) }
func (s *Server) handleDeviceRecovery(w http.ResponseWriter, r *http.Request) {
	s.deviceKey(w, r, true)
}
func (s *Server) deviceKey(w http.ResponseWriter, r *http.Request, recovery bool) {
	var in keyRequest
	if !decodeRequest(w, r, &in, 2048, 256) {
		return
	}
	account := ctxutil.AccountID(r.Context())
	var id string
	var err error
	if recovery {
		id, err = s.online.keys.Replace(r.Context(), account, in.ReplacesKeyID, in.PublicKey, in.SuiteID)
	} else if in.ReplacesKeyID != "" {
		err = api.NewUserError(api.CodeBadRequest, "use recovery route for replacement")
	} else {
		id, err = s.online.keys.Provision(r.Context(), account, in.PublicKey, in.SuiteID)
	}
	if err != nil {
		writeFailure(w, r, err)
		return
	}
	rec, err := s.online.keys.Lookup(r.Context(), id)
	if err != nil {
		writeFailure(w, r, err)
		return
	}
	if recovery {
		writeJSON(w, 200, map[string]any{"key": rec, "revoked_key_id": in.ReplacesKeyID})
	} else {
		writeJSON(w, 200, rec)
	}
}
func (s *Server) handleSession(w http.ResponseWriter, r *http.Request) {
	var in struct {
		CaseID string   `json:"case_id"`
		Cards  []string `json:"card_ids"`
	}
	if !decodeRequest(w, r, &in, 4096, 256) {
		return
	}
	account := ctxutil.AccountID(r.Context())
	requestBytes, _ := json.Marshal(in)
	requestHash := sha256.Sum256(requestBytes)
	replay, err := s.online.receipts.ReplayAuthorization(r.Context(), account, requestHash[:])
	if err != nil {
		writeFailure(w, r, err)
		return
	}
	if replay != nil {
		writeSessionPermit(w, replay)
		return
	}
	item, ok := s.online.catalog.cases[in.CaseID]
	if !ok {
		writeFailure(w, r, api.NewNotFound("catalog case not available"))
		return
	}
	prof, err := s.profileRepo.Get(r.Context(), account)
	if err != nil {
		writeFailure(w, r, err)
		return
	}
	if len(in.Cards) == 0 || len(in.Cards) > 6 {
		writeFailure(w, r, api.NewUserError(api.CodeOutOfBounds, "invalid loadout size"))
		return
	}
	owned := map[string]bool{}
	for _, card := range prof.OwnedCardIDs {
		owned[card] = true
	}
	for _, card := range in.Cards {
		if !owned[card] {
			writeFailure(w, r, api.NewForbidden("loadout card is not owned"))
			return
		}
		delete(owned, card)
	}
	patientHash := sha256.Sum256([]byte(account + "\x00" + item.ID))
	patientID := "patient_" + hex.EncodeToString(patientHash[:16])
	// Renew expired owned instances before acquiring any authorization locks.
	repo := ownership.NewSQLRepository(s.online.db)
	if err := repo.EnsureCatalogLease(r.Context(), patientID, account, item.MemoryClass); err != nil {
		writeFailure(w, r, err)
		return
	}
	seedMAC := hmac.New(sha256.New, s.online.secret)
	seedMAC.Write([]byte(account + "\x00" + item.ID + "\x00" + ctxutil.IdempotencyKey(r.Context())))
	seed := int(binary.BigEndian.Uint32(seedMAC.Sum(nil)[:4]) & 0x7fffffff)
	if seed == 0 {
		seed = 1
	}
	start := schemas.SessionStartState{Loadout: schemas.Loadout{CardIds: in.Cards, SlotCap: 6}, Library: schemas.CardLibrary{OwnedCardIds: prof.OwnedCardIDs}, Controllers: item.Controllers, InitialAxes: item.InitialAxes, RootSeed: seed, ManifestChecksum: item.ManifestChecksum, CaseID: item.ID}
	certificateID := ""
	if proof, ok := s.online.catalog.outcomes.Select(item.ID, item.ManifestChecksum, item.RulesetVersion, in.Cards, prof.OwnedCardIDs, item.InitialAxes, item.Controllers); ok {
		start = proof.StartState
		certificateID = proof.ProofID
	}
	permit, err := s.online.receipts.AuthorizeCertifiedRequest(r.Context(), account, patientID, item.RulesetVersion, start, requestHash[:], certificateID)
	if err != nil {
		writeFailure(w, r, err)
		return
	}
	writeSessionPermit(w, permit)
}

func writeSessionPermit(w http.ResponseWriter, permit *receipts.Authorization) {
	rewardStatus := "held_unproven"
	if permit.CertificateID != "" {
		rewardStatus = "conditional_certified"
	}
	writeJSON(w, 200, struct {
		*receipts.Authorization
		RewardStatus string `json:"reward_status"`
	}{permit, rewardStatus})
}
func (o *onlineServices) submit(ctx context.Context, account string, env schemas.SignedEnvelope) (*schemas.SessionReceipt, error) {
	if !o.cfg.ReceiptValidationEnabled {
		return nil, api.NewServiceUnavailable("receipt acceptance temporarily disabled")
	}
	limit := min(o.cfg.MaxReceiptBodyBytes, int64(schemas.MaxCanonicalReceiptBytes))
	if int64(len(env.CanonicalReceiptBytes)) > limit {
		return nil, api.NewPayloadTooLarge(limit)
	}
	return o.receipts.Submit(ctx, account, env)
}
func (s *Server) handleReceipt(w http.ResponseWriter, r *http.Request) {
	var env schemas.SignedEnvelope
	if !decodeRequest(w, r, &env, s.online.cfg.MaxReceiptBodyBytes*2, int(s.online.cfg.MaxReceiptBodyBytes*2)) {
		return
	}
	account := ctxutil.AccountID(r.Context())
	receipt, err := s.online.submit(r.Context(), account, env)
	if err != nil {
		writeFailure(w, r, err)
		return
	}
	verdict, err := s.online.receipts.AcceptanceVerdict(r.Context(), account, receipt.ID)
	if err != nil {
		writeFailure(w, r, err)
		return
	}
	writeJSON(w, 200, acceptedResult(receipt.ID, receipt.IdempotencyKey, verdict))
}
func (s *Server) handleBatch(w http.ResponseWriter, r *http.Request) {
	var in offline.BatchRequest
	if !decodeRequest(w, r, &in, schemas.MaxReceiptBatchBytes, int(s.online.cfg.MaxReceiptBodyBytes*2)) {
		return
	}
	// Reject an oversized batch member before metadata extraction, device-key
	// lookup or any receipt/profile persistence. The client uses the same cap.
	for _, env := range in.Envelopes {
		if len(env.CanonicalReceiptBytes) > schemas.MaxCanonicalReceiptBytes {
			writeFailure(w, r, api.NewPayloadTooLarge(schemas.MaxCanonicalReceiptBytes))
			return
		}
	}
	out, err := s.online.batch.SubmitBatch(r.Context(), ctxutil.AccountID(r.Context()), in)
	if err != nil {
		writeFailure(w, r, err)
		return
	}
	for i := range out.Results {
		if out.Results[i].Status == "accepted" {
			verdict, err := s.online.receipts.AcceptanceVerdict(r.Context(), ctxutil.AccountID(r.Context()), out.Results[i].ID)
			if err != nil {
				writeFailure(w, r, err)
				return
			}
			out.Results[i] = acceptedResult(out.Results[i].ID, out.Results[i].IdempotencyKey, verdict)
		}
	}
	writeJSON(w, 200, out)
}

func acceptedResult(id, key string, v receipts.Verdict) offline.ItemResult {
	return offline.ItemResult{ID: id, IdempotencyKey: key, Status: "accepted", ProfileVersion: v.ProfileVersion, RewardStatus: v.RewardStatus, RewardReason: v.Reason, CertificateID: v.CertificateID, XPAwarded: v.XP, StudyAwarded: v.StudyPoints, CashAwarded: v.CashMicros}
}
func (s *Server) handlePublicKeys(w http.ResponseWriter, r *http.Request) {
	list, err := s.online.keys.BuildRevocationList(r.Context(), 5*time.Minute)
	if err != nil {
		writeFailure(w, r, err)
		return
	}
	body, _ := json.Marshal(struct {
		Version     string                       `json:"version"`
		Keys        []any                        `json:"keys"`
		Revocations []devicekeys.RevocationEntry `json:"revocations"`
		TTL         int                          `json:"ttl_seconds"`
	}{"v1", []any{}, list.Entries, 300})
	hash := sha256.Sum256(body)
	etag := "\"" + hex.EncodeToString(hash[:16]) + "\""
	w.Header().Set("ETag", etag)
	w.Header().Set("Cache-Control", "public, max-age=300")
	if r.Header.Get("If-None-Match") == etag {
		w.WriteHeader(304)
		return
	}
	w.Header().Set("Content-Type", "application/json")
	w.Write(body)
}
func (s *Server) authenticateOnline(r *http.Request) (context.Context, error) {
	claims, err := s.online.tokens.Verify(r.Context(), extractBearer(r))
	if err != nil {
		return nil, tokenFailure(err)
	}
	ctx := ctxutil.WithAccountID(r.Context(), claims.AccountID)
	return authz.WithRole(ctx, authz.Role(claims.Role)), nil
}

func tokenFailure(err error) error {
	if errors.Is(err, tokens.ErrInvalidToken) || errors.Is(err, tokens.ErrTokenExpired) || errors.Is(err, tokens.ErrTokenRevoked) || errors.Is(err, sql.ErrNoRows) {
		return api.NewUnauthorized("invalid authentication token")
	}
	return api.NewServiceUnavailable("authentication store temporarily unavailable")
}
