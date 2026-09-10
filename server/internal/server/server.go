// Package server holds the HTTP control-plane wiring for Psychosims.
//
// This is the minimal health-check surface stood up in Phase 0.1; the
// authoritative endpoints (identity, receipts, ownership, signing, economy,
// moderation) land in Phase 3.
package server

import (
	"context"
	"encoding/json"
	"errors"
	"fmt"
	"math"
	"net"
	"net/http"
	"strings"
	"time"

	"psychosims.dev/server/internal/api"
	"psychosims.dev/server/internal/authz"
	"psychosims.dev/server/internal/ctxutil"
	"psychosims.dev/server/internal/middleware"
	"psychosims.dev/server/internal/observability"
	"psychosims.dev/server/internal/profile"
	"psychosims.dev/server/internal/psylog"
	"psychosims.dev/server/internal/ratelimit"
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
	ready         func(context.Context) ReadinessResponse
	profileRepo   profile.Repository
	authVerifier  TokenVerifier
	healthChecker HealthChecker
	online        *onlineServices
	inFlight      *middleware.InFlightCounter
	metrics       *observability.Metrics
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

// WithMetrics supplies a bounded in-process metrics sink for inspection.
func WithMetrics(metrics *observability.Metrics) Option {
	return func(s *Server) { s.metrics = metrics }
}

// New builds a Server with the standard middleware stack.
func New(clock timeutil.Clock, opts ...Option) *Server {
	s := &Server{
		mux:     http.NewServeMux(),
		metrics: observability.NewMetrics(),
		clock:   clock,
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
	var work http.Handler = s.mux
	if s.inFlight != nil {
		limited := middleware.InFlightMiddleware(s.inFlight)(work)
		work = http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
			// Liveness performs no downstream work and stays available under pressure.
			if r.Method == http.MethodGet && r.URL.Path == "/health" {
				s.mux.ServeHTTP(w, r)
				return
			}
			limited.ServeHTTP(w, r)
		})
	}
	work = observability.TraceMiddleware(observability.NewLogger(psylog.Default()), s.metrics)(observability.StatusTracingMiddleware(s.metrics)(middleware.RequireIdempotencyKey(work)))
	handler := middleware.APIVersion(middleware.RequestContext(work))
	return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		ctx, cancel := context.WithTimeout(r.Context(), 30*time.Second)
		defer cancel()
		handler.ServeHTTP(w, r.WithContext(ctx))
	})
}

func (s *Server) registerRoutes() {
	s.mux.HandleFunc("GET /health", s.handleHealth)
	s.mux.HandleFunc("GET /ready", s.handleReady)
	s.mux.HandleFunc("GET /time", s.handleTime)
	var boot http.Handler = http.HandlerFunc(s.handleBoot)
	if s.online != nil {
		boot = ratelimit.Middleware(s.online.rates)(boot)
	}
	s.mux.Handle("GET /v1/boot", s.requireAuth(boot))
	if s.online != nil {
		s.onlineRoutes()
	}
}

// requireAuth wraps a handler with bearer-token authentication if a verifier is
// configured. Tests may pre-populate the account id on the request context to
// bypass verification.
func (s *Server) requireAuth(next http.Handler) http.Handler {
	return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		if s.online != nil {
			peer := r.RemoteAddr
			if host, _, err := net.SplitHostPort(peer); err == nil {
				peer = host
			}
			finish, retry := s.online.authAttempts.Begin(peer)
			if finish == nil {
				api.NewRateLimited(max(1, int(math.Ceil(retry.Seconds())))).Write(w, ctxutil.RequestID(r.Context()))
				return
			}
			defer finish(true) // Release even if dependency verification panics.
			ctx, err := s.authenticateOnline(r)
			var he api.HTTPError
			failedAuth := errors.As(err, &he) && he.Status == http.StatusUnauthorized
			finish(!failedAuth)
			if err != nil {
				writeFailure(w, r, err)
				return
			}
			next.ServeHTTP(w, r.WithContext(ctx))
			return
		}
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
			prof = &profile.PrimitiveProfile{AccountID: accountID, Version: 0, OwnedCardIDs: []string{"open_question"}, UpdatedAt: s.clock.Now()}
			if err := s.profileRepo.Update(r.Context(), prof); err != nil {
				if he, ok := err.(api.HTTPError); !ok || he.Body.Code != api.CodeConflict {
					api.NewInternalError("profile creation failed").Write(w, ctxutil.RequestID(r.Context()))
					return
				}
			}
			prof, err = s.profileRepo.Get(r.Context(), accountID)
			if err != nil {
				api.NewInternalError("profile read failed").Write(w, ctxutil.RequestID(r.Context()))
				return
			}
		} else {
			api.NewInternalError("profile read failed: "+err.Error()).Write(w, ctxutil.RequestID(r.Context()))
			return
		}
	}
	etag := fmt.Sprintf("\"v%d\"", prof.Version)
	w.Header().Set("ETag", etag)
	if r.Header.Get("If-None-Match") == etag {
		w.WriteHeader(http.StatusNotModified)
		return
	}
	writeJSON(w, http.StatusOK, BootResponse{Profile: *prof, ETag: etag})
}

func (s *Server) handleHealth(w http.ResponseWriter, _ *http.Request) {
	writeJSON(w, http.StatusOK, HealthResponse{Status: "ok", Version: Version})
}

func (s *Server) handleReady(w http.ResponseWriter, r *http.Request) {
	ctx, cancel := context.WithTimeout(r.Context(), 2*time.Second)
	defer cancel()
	resp := s.ready(ctx)
	status := http.StatusOK
	if resp.Status != "ok" {
		status = http.StatusServiceUnavailable
	}
	writeJSON(w, status, resp)
}

func (s *Server) handleTime(w http.ResponseWriter, r *http.Request) {
	writeJSON(w, http.StatusOK, timeutil.NewServerTimeResponse(s.clock))
}

func (s *Server) defaultReady(ctx context.Context) ReadinessResponse {
	deps := map[string]string{"store": "not_configured"}
	if s.healthChecker != nil {
		deps = s.healthChecker.Check(ctx)
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
