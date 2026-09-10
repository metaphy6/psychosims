package server

import (
	"context"
	"encoding/json"
	"errors"
	"net/http"
	"net/http/httptest"
	"testing"
	"time"

	"psychosims.dev/server/internal/api"
	"psychosims.dev/server/internal/authz"
	"psychosims.dev/server/internal/ctxutil"
	"psychosims.dev/server/internal/health"
	"psychosims.dev/server/internal/profile"
	"psychosims.dev/server/internal/timeutil"
)

func TestHealth(t *testing.T) {
	req := httptest.NewRequest(http.MethodGet, "/health", nil)
	rec := httptest.NewRecorder()

	New(timeutil.RealClock{}).Handler().ServeHTTP(rec, req)

	if rec.Code != http.StatusOK {
		t.Fatalf("status = %d, want %d", rec.Code, http.StatusOK)
	}

	var body HealthResponse
	if err := json.Unmarshal(rec.Body.Bytes(), &body); err != nil {
		t.Fatalf("decode body: %v", err)
	}
	if body.Status != "ok" {
		t.Errorf("status = %q, want %q", body.Status, "ok")
	}
	if body.Version != Version {
		t.Errorf("version = %q, want %q", body.Version, Version)
	}
}

func TestReady(t *testing.T) {
	req := httptest.NewRequest(http.MethodGet, "/ready", nil)
	rec := httptest.NewRecorder()

	hc := health.NewChecker(func(ctx context.Context) (string, bool) { return "db", true })
	New(timeutil.RealClock{}, WithHealthChecker(hc)).Handler().ServeHTTP(rec, req)

	if rec.Code != http.StatusOK {
		t.Fatalf("status = %d, want %d", rec.Code, http.StatusOK)
	}

	var body ReadinessResponse
	if err := json.Unmarshal(rec.Body.Bytes(), &body); err != nil {
		t.Fatalf("decode body: %v", err)
	}
	if body.Status != "ok" {
		t.Errorf("status = %q, want %q", body.Status, "ok")
	}
	if body.APIVersion != api.Version {
		t.Errorf("api_version = %q, want %q", body.APIVersion, api.Version)
	}
}

func TestReadyHonorsRequestCancellation(t *testing.T) {
	hc := health.NewChecker(func(ctx context.Context) (string, bool) { <-ctx.Done(); return "store", false })
	srv := New(timeutil.RealClock{}, WithHealthChecker(hc))
	ctx, cancel := context.WithCancel(context.Background())
	cancel()
	req := httptest.NewRequest("GET", "/ready", nil).WithContext(ctx)
	w := httptest.NewRecorder()
	done := make(chan struct{})
	go func() { srv.Handler().ServeHTTP(w, req); close(done) }()
	select {
	case <-done:
		if w.Code != 503 {
			t.Fatalf("cancelled readiness=%d", w.Code)
		}
	case <-time.After(200 * time.Millisecond):
		t.Fatal("readiness probe ignored request cancellation")
	}
}

func TestTime(t *testing.T) {
	fixed := time.Date(2026, 1, 1, 0, 0, 0, 0, time.UTC)
	req := httptest.NewRequest(http.MethodGet, "/time", nil)
	rec := httptest.NewRecorder()

	New(timeutil.FixedClock{T: fixed}).Handler().ServeHTTP(rec, req)

	if rec.Code != http.StatusOK {
		t.Fatalf("status = %d, want %d", rec.Code, http.StatusOK)
	}

	var body timeutil.ServerTimeResponse
	if err := json.Unmarshal(rec.Body.Bytes(), &body); err != nil {
		t.Fatalf("decode body: %v", err)
	}
	if body.ServerTimeUnix != fixed.Unix() {
		t.Errorf("server_time_unix = %d, want %d", body.ServerTimeUnix, fixed.Unix())
	}
}

func TestRequireIdempotencyKeyOnMutatingRequest(t *testing.T) {
	req := httptest.NewRequest(http.MethodPost, "/time", nil)
	rec := httptest.NewRecorder()

	New(timeutil.RealClock{}).Handler().ServeHTTP(rec, req)

	if rec.Code != http.StatusBadRequest {
		t.Errorf("status = %d, want %d", rec.Code, http.StatusBadRequest)
	}
}

func TestBootCreatesAndReturnsProfile(t *testing.T) {
	repo := profile.NewInMemoryProfileRepository()
	srv := New(timeutil.RealClock{}, WithProfileRepo(repo))

	req := httptest.NewRequest(http.MethodGet, "/v1/boot", nil)
	req = req.WithContext(ctxutil.WithAccountID(req.Context(), "acc-1"))
	rec := httptest.NewRecorder()

	srv.Handler().ServeHTTP(rec, req)

	if rec.Code != http.StatusOK {
		t.Fatalf("status = %d, want %d", rec.Code, http.StatusOK)
	}
	var body BootResponse
	if err := json.Unmarshal(rec.Body.Bytes(), &body); err != nil {
		t.Fatalf("decode: %v", err)
	}
	if body.Profile.AccountID != "acc-1" {
		t.Errorf("account id = %q, want acc-1", body.Profile.AccountID)
	}
	etag := rec.Header().Get("ETag")
	if etag == "" {
		t.Fatal("expected ETag")
	}

	// Conditional fetch returns 304.
	req2 := httptest.NewRequest(http.MethodGet, "/v1/boot", nil)
	req2 = req2.WithContext(ctxutil.WithAccountID(req2.Context(), "acc-1"))
	req2.Header.Set("If-None-Match", etag)
	rec2 := httptest.NewRecorder()
	srv.Handler().ServeHTTP(rec2, req2)
	if rec2.Code != http.StatusNotModified {
		t.Errorf("status = %d, want %d", rec2.Code, http.StatusNotModified)
	}
}

func TestBootRequiresAuth(t *testing.T) {
	repo := profile.NewInMemoryProfileRepository()
	srv := New(timeutil.RealClock{}, WithProfileRepo(repo), WithAuthVerifier(&stubVerifier{}))

	req := httptest.NewRequest(http.MethodGet, "/v1/boot", nil)
	rec := httptest.NewRecorder()
	srv.Handler().ServeHTTP(rec, req)

	if rec.Code != http.StatusUnauthorized {
		t.Errorf("status = %d, want %d", rec.Code, http.StatusUnauthorized)
	}
}

func TestBootAcceptsValidBearer(t *testing.T) {
	repo := profile.NewInMemoryProfileRepository()
	srv := New(timeutil.RealClock{}, WithProfileRepo(repo), WithAuthVerifier(&stubVerifier{accountID: "acc-2"}))

	req := httptest.NewRequest(http.MethodGet, "/v1/boot", nil)
	req.Header.Set("Authorization", "Bearer valid-token")
	rec := httptest.NewRecorder()
	srv.Handler().ServeHTTP(rec, req)

	if rec.Code != http.StatusOK {
		t.Fatalf("status = %d, want %d", rec.Code, http.StatusOK)
	}
	var body BootResponse
	if err := json.Unmarshal(rec.Body.Bytes(), &body); err != nil {
		t.Fatalf("decode: %v", err)
	}
	if body.Profile.AccountID != "acc-2" {
		t.Errorf("account id = %q, want acc-2", body.Profile.AccountID)
	}
}

func TestReadyWithHealthChecker(t *testing.T) {
	checker := &stubHealthChecker{deps: map[string]string{"store": "ok", "queue": "ok"}}
	srv := New(timeutil.RealClock{}, WithHealthChecker(checker))

	req := httptest.NewRequest(http.MethodGet, "/ready", nil)
	rec := httptest.NewRecorder()
	srv.Handler().ServeHTTP(rec, req)

	if rec.Code != http.StatusOK {
		t.Fatalf("status = %d, want %d", rec.Code, http.StatusOK)
	}
	var body ReadinessResponse
	if err := json.Unmarshal(rec.Body.Bytes(), &body); err != nil {
		t.Fatalf("decode: %v", err)
	}
	if body.Status != "ok" {
		t.Errorf("status = %q, want ok", body.Status)
	}
}

func TestReadyDegraded(t *testing.T) {
	checker := &stubHealthChecker{deps: map[string]string{"store": "down"}}
	srv := New(timeutil.RealClock{}, WithHealthChecker(checker))

	req := httptest.NewRequest(http.MethodGet, "/ready", nil)
	rec := httptest.NewRecorder()
	srv.Handler().ServeHTTP(rec, req)

	if rec.Code != http.StatusServiceUnavailable {
		t.Errorf("status = %d, want %d", rec.Code, http.StatusServiceUnavailable)
	}
}

type stubVerifier struct {
	accountID string
	role      authz.Role
}

func (s *stubVerifier) Verify(token string) (string, authz.Role, error) {
	if token == "valid-token" {
		return s.accountID, s.role, nil
	}
	return "", authz.RolePlayer, errors.New("invalid token")
}

type stubHealthChecker struct {
	deps map[string]string
}

func (s *stubHealthChecker) Check(ctx context.Context) map[string]string {
	return s.deps
}
