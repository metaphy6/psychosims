// Package server holds the HTTP control-plane wiring for Psychosims.
//
// This is the minimal health-check surface stood up in Phase 0.1; the
// authoritative endpoints (identity, receipts, ownership, signing, economy,
// moderation) land in Phase 3.
package server

import (
	"context"
	"encoding/json"
	"fmt"
	"net/http"
	"strings"

	"psychosims.dev/server/internal/api"
	"psychosims.dev/server/internal/authz"
	"psychosims.dev/server/internal/ctxutil"
	"psychosims.dev/server/internal/middleware"
	"psychosims.dev/server/internal/profile"
	"psychosims.dev/server/internal/timeutil"
)

// Version is the server build version reported by the health endpoint.
const Version = "0.3.0-alpha.1"

// HealthResponse is the payload returned by the liveness endpoint.
type HealthResponse struct {
	Status  string `json:"status"`
	Version string `json:"version"`
}

// ReadinessResponse reports dependency health.
type ReadinessResponse struct {
	Status     string            `json:"status"`
	Version    string            `json:"version"`
	Deps       map[string]string `json:"deps"`
	APIVersion string            `json:"api_version"`
}

// BootResponse wraps the primitive profile for the session handshake.
type BootResponse struct {
	Profile profile.PrimitiveProfile `json:"profile"`
	ETag    string                   `json:"etag"`
}

// HealthChecker reports dependency health for readiness probes.
type HealthChecker interface {
	Check(ctx context.Context) map[string]string
}

// TokenVerifier validates bearer tokens and returns account id + role.
type TokenVerifier interface {
	Verify(token string) (accountID string, role authz.Role, err error)
}

// Server is the control-plane HTTP server with graceful lifecycle hooks.
type Server struct {
	mux           *http.ServeMux
	clock         timeutil.Clock
	ready         func() ReadinessResponse
	profileRepo   profile.Repository
	authVerifier  TokenVerifier
	healthChecker HealthChecker
}

// Option configures a Server.
type Option func(*Server)

// WithProfileRepo injects the profile store used by /v1/boot.
func WithProfileRepo(repo profile.Repository) Option {
	return func(s *Server) { s.profileRepo = repo }
}

// WithAuthVerifier injects bearer-token authentication.
func WithAuthVerifier(v TokenVerifier) Option {
	return func(s *Server) { s.authVerifier = v }
}

// WithHealthChecker injects the dependency health check used by /ready.
func WithHealthChecker(h HealthChecker) Option {
	return func(s *Server) { s.healthChecker = h }
}

// New builds a Server with the standard middleware stack.
func New(clock timeutil.Clock, opts ...Option) *Server {
	s := &Server{
		mux:   http.NewServeMux(),
		clock: clock,
	}
	for _, opt := range opts {
		opt(s)
	}
	s.ready = s.defaultReady
	s.registerRoutes()
	return s
}

// Handler returns the fully-wrapped HTTP handler.
func (s *Server) Handler() http.Handler {
	return middleware.APIVersion(
		middleware.RequestContext(
			middleware.RequireIdempotencyKey(
				s.mux,
			),
		),
	)
}

func (s *Server) registerRoutes() {
	s.mux.HandleFunc("/health", s.handleHealth)
	s.mux.HandleFunc("/ready", s.handleReady)
	s.mux.HandleFunc("/time", s.handleTime)
	s.mux.Handle("/v1/boot", s.requireAuth(http.HandlerFunc(s.handleBoot)))
}

// requireAuth wraps a handler with bearer-token authentication if a verifier is
// configured. Tests may pre-populate the account id on the request context to
// bypass verification.
func (s *Server) requireAuth(next http.Handler) http.Handler {
	return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		if ctxutil.AccountID(r.Context()) != "" {
			next.ServeHTTP(w, r)
			return
		}
		if s.authVerifier == nil {
			api.NewUnauthorized("authentication required").Write(w, ctxutil.RequestID(r.Context()))
			return
		}
		token := extractBearer(r)
		if token == "" {
			api.NewUnauthorized("missing bearer token").Write(w, ctxutil.RequestID(r.Context()))
			return
		}
		accountID, role, err := s.authVerifier.Verify(token)
		if err != nil {
			api.NewUnauthorized("invalid bearer token").Write(w, ctxutil.RequestID(r.Context()))
			return
		}
		ctx := ctxutil.WithAccountID(r.Context(), accountID)
		ctx = authz.WithRole(ctx, role)
		next.ServeHTTP(w, r.WithContext(ctx))
	})
}

func extractBearer(r *http.Request) string {
	h := r.Header.Get("Authorization")
	const prefix = "Bearer "
	if len(h) > len(prefix) && strings.HasPrefix(h, prefix) {
		return h[len(prefix):]
	}
	return ""
}

func (s *Server) handleBoot(w http.ResponseWriter, r *http.Request) {
	accountID := ctxutil.AccountID(r.Context())
	if accountID == "" {
		api.NewUnauthorized("account id required").Write(w, ctxutil.RequestID(r.Context()))
		return
	}
	if s.profileRepo == nil {
		api.NewServiceUnavailable("profile store not configured").Write(w, ctxutil.RequestID(r.Context()))
		return
	}
	prof, err := s.profileRepo.Get(r.Context(), accountID)
	if err != nil {
		if he, ok := err.(api.HTTPError); ok && he.Body.Code == api.CodeNotFound {
			// Create a blank profile on first boot.
			prof = &profile.PrimitiveProfile{AccountID: accountID, Version: 1, UpdatedAt: s.clock.Now()}
			if err := s.profileRepo.Update(r.Context(), prof); err != nil {
				api.NewInternalError("profile creation failed: " + err.Error()).Write(w, ctxutil.RequestID(r.Context()))
				return
			}
			prof, _ = s.profileRepo.Get(r.Context(), accountID)
		} else {
			api.NewInternalError("profile read failed: " + err.Error()).Write(w, ctxutil.RequestID(r.Context()))
			return
		}
	}
	etag := fmt.Sprintf("\"v%d\"", prof.Version)
	if r.Header.Get("If-None-Match") == etag {
		w.WriteHeader(http.StatusNotModified)
		return
	}
	w.Header().Set("ETag", etag)
	writeJSON(w, http.StatusOK, BootResponse{Profile: *prof, ETag: etag})
}

func (s *Server) handleHealth(w http.ResponseWriter, _ *http.Request) {
	writeJSON(w, http.StatusOK, HealthResponse{Status: "ok", Version: Version})
}

func (s *Server) handleReady(w http.ResponseWriter, r *http.Request) {
	resp := s.ready()
	status := http.StatusOK
	if resp.Status != "ok" {
		status = http.StatusServiceUnavailable
	}
	writeJSON(w, status, resp)
}

func (s *Server) handleTime(w http.ResponseWriter, r *http.Request) {
	writeJSON(w, http.StatusOK, timeutil.NewServerTimeResponse(s.clock))
}

func (s *Server) defaultReady() ReadinessResponse {
	deps := map[string]string{"store": "not_configured"}
	if s.healthChecker != nil {
		deps = s.healthChecker.Check(context.Background())
	}
	status := "ok"
	for _, v := range deps {
		if v != "ok" {
			status = "degraded"
			break
		}
	}
	return ReadinessResponse{
		Status:     status,
		Version:    Version,
		Deps:       deps,
		APIVersion: api.Version,
	}
}

func writeJSON(w http.ResponseWriter, status int, v any) {
	w.Header().Set("Content-Type", "application/json")
	w.WriteHeader(status)
	_ = json.NewEncoder(w).Encode(v)
}

// NewMux returns the HTTP handler for the control plane.
// Deprecated: use New(...).Handler() for the full middleware stack.
func NewMux() *http.ServeMux {
	s := New(timeutil.RealClock{})
	return s.mux
}
