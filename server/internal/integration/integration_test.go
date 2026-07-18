package integration

import (
	"context"
	"fmt"
	"net/http"
	"net/http/httptest"
	"testing"

	"psychosims.dev/server/internal/authz"
	"psychosims.dev/server/internal/health"
	"psychosims.dev/server/internal/profile"
	"psychosims.dev/server/internal/server"
	"psychosims.dev/server/internal/timeutil"
)

type stubVerifier struct{}

func (stubVerifier) Verify(token string) (string, authz.Role, error) {
	if token != "test-token" {
		return "", authz.RolePlayer, fmt.Errorf("invalid token")
	}
	return "acct-1", authz.RolePlayer, nil
}

func TestServerBootAndReady(t *testing.T) {
	profileRepo := profile.NewInMemoryProfileRepository()
	auth := stubVerifier{}
	hc := health.NewChecker(func(ctx context.Context) (string, bool) { return "db", true })

	srv := server.New(
		timeutil.RealClock{},
		server.WithProfileRepo(profileRepo),
		server.WithAuthVerifier(auth),
		server.WithHealthChecker(hc),
	)

	boot := httptest.NewRequest(http.MethodGet, "/v1/boot", nil)
	boot.Header.Set("Authorization", "Bearer test-token")
	rec := httptest.NewRecorder()
	srv.Handler().ServeHTTP(rec, boot)
	if rec.Code != http.StatusOK && rec.Code != http.StatusNotModified {
		t.Fatalf("boot status = %d, want 200 or 304", rec.Code)
	}

	ready := httptest.NewRequest(http.MethodGet, "/ready", nil)
	rec2 := httptest.NewRecorder()
	srv.Handler().ServeHTTP(rec2, ready)
	if rec2.Code != http.StatusOK {
		t.Errorf("ready status = %d, want 200", rec2.Code)
	}
}

// TestInvalidTokenFails is a failure-injection smoke test: a bad bearer is
// rejected before reaching the profile store.
func TestInvalidTokenFails(t *testing.T) {
	auth := stubVerifier{}
	srv := server.New(timeutil.RealClock{}, server.WithAuthVerifier(auth))

	req := httptest.NewRequest(http.MethodGet, "/v1/boot", nil)
	req.Header.Set("Authorization", "Bearer bad-token")
	rec := httptest.NewRecorder()
	srv.Handler().ServeHTTP(rec, req)
	if rec.Code != http.StatusUnauthorized {
		t.Errorf("status = %d, want %d", rec.Code, http.StatusUnauthorized)
	}
}

// TestBootLoadPass exercises a burst of concurrent boot handshakes to ensure
// the handshake path does not collapse under load (Phase 3.8 lightweight load
// pass and Phase 3.7 backpressure smoke test).
func TestBootLoadPass(t *testing.T) {
	profileRepo := profile.NewInMemoryProfileRepository()
	auth := stubVerifier{}
	hc := health.NewChecker(func(ctx context.Context) (string, bool) { return "db", true })
	srv := server.New(
		timeutil.RealClock{},
		server.WithProfileRepo(profileRepo),
		server.WithAuthVerifier(auth),
		server.WithHealthChecker(hc),
	)

	const n = 50
	errs := make(chan error, n)
	for i := 0; i < n; i++ {
		go func() {
			req := httptest.NewRequest(http.MethodGet, "/v1/boot", nil)
			req.Header.Set("Authorization", "Bearer test-token")
			rec := httptest.NewRecorder()
			srv.Handler().ServeHTTP(rec, req)
			if rec.Code != http.StatusOK && rec.Code != http.StatusNotModified {
				errs <- fmt.Errorf("boot status = %d", rec.Code)
			} else {
				errs <- nil
			}
		}()
	}
	failures := 0
	for i := 0; i < n; i++ {
		if <-errs != nil {
			failures++
		}
	}
	if failures > 0 {
		t.Errorf("%d/%d boot requests failed", failures, n)
	}
}

// BenchmarkBoot measures handshake latency for the exit-report baseline.
func BenchmarkBoot(b *testing.B) {
	profileRepo := profile.NewInMemoryProfileRepository()
	auth := stubVerifier{}
	hc := health.NewChecker(func(ctx context.Context) (string, bool) { return "db", true })
	srv := server.New(
		timeutil.RealClock{},
		server.WithProfileRepo(profileRepo),
		server.WithAuthVerifier(auth),
		server.WithHealthChecker(hc),
	)

	b.ResetTimer()
	for i := 0; i < b.N; i++ {
		req := httptest.NewRequest(http.MethodGet, "/v1/boot", nil)
		req.Header.Set("Authorization", "Bearer test-token")
		rec := httptest.NewRecorder()
		srv.Handler().ServeHTTP(rec, req)
		if rec.Code != http.StatusOK && rec.Code != http.StatusNotModified {
			b.Fatalf("boot status = %d", rec.Code)
		}
	}
}
