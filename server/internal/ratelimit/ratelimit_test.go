package ratelimit

import (
	"net/http"
	"net/http/httptest"
	"testing"
	"time"

	"psychosims.dev/server/internal/ctxutil"
)

func TestPreAuthIPLimit(t *testing.T) {
	limits := Limits{PreAuthPerIP: 2, AuthPerAccount: 100, Window: time.Minute}
	svc := NewService(limits)

	if ok, _ := svc.Allow("", "1.2.3.4"); !ok {
		t.Fatal("first request should be allowed")
	}
	if ok, _ := svc.Allow("", "1.2.3.4"); !ok {
		t.Fatal("second request should be allowed")
	}
	if ok, _ := svc.Allow("", "1.2.3.4"); ok {
		t.Fatal("third request should be denied")
	}
	if ok, _ := svc.Allow("", "5.6.7.8"); !ok {
		t.Fatal("different ip should be allowed")
	}
}

func TestAccountLimit(t *testing.T) {
	limits := Limits{PreAuthPerIP: 100, AuthPerAccount: 1, Window: time.Minute}
	svc := NewService(limits)

	if ok, _ := svc.Allow("acc-1", "1.2.3.4"); !ok {
		t.Fatal("first request should be allowed")
	}
	if ok, _ := svc.Allow("acc-1", "1.2.3.4"); ok {
		t.Fatal("second request should be denied")
	}
}

func TestMiddlewareReturns429(t *testing.T) {
	limits := Limits{PreAuthPerIP: 0, AuthPerAccount: 0, Window: time.Minute}
	svc := NewService(limits)
	handler := Middleware(svc)(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		w.WriteHeader(http.StatusOK)
	}))

	req := httptest.NewRequest(http.MethodGet, "/", nil)
	rec := httptest.NewRecorder()
	handler.ServeHTTP(rec, req)

	if rec.Code != http.StatusTooManyRequests {
		t.Errorf("status = %d, want %d", rec.Code, http.StatusTooManyRequests)
	}
}

func TestMiddlewareUsesAccountBucket(t *testing.T) {
	limits := Limits{PreAuthPerIP: 0, AuthPerAccount: 1, Window: time.Minute}
	svc := NewService(limits)
	handler := Middleware(svc)(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		w.WriteHeader(http.StatusOK)
	}))

	req := httptest.NewRequest(http.MethodGet, "/", nil)
	req = req.WithContext(ctxutil.WithAccountID(req.Context(), "acc-1"))
	rec := httptest.NewRecorder()
	handler.ServeHTTP(rec, req)
	if rec.Code != http.StatusOK {
		t.Errorf("first status = %d, want %d", rec.Code, http.StatusOK)
	}

	rec = httptest.NewRecorder()
	handler.ServeHTTP(rec, req)
	if rec.Code != http.StatusTooManyRequests {
		t.Errorf("second status = %d, want %d", rec.Code, http.StatusTooManyRequests)
	}
}

func TestAuthAttemptsReserveBeforeVerificationAndExpire(t *testing.T) {
	now := time.Unix(100, 0)
	gate := NewAuthAttemptGate(1, time.Minute)
	gate.now = func() time.Time { return now }
	gate.maxPeers = 2
	finish, retry := gate.Begin("one")
	if finish == nil || retry != 0 {
		t.Fatal("first attempt denied")
	}
	if f, _ := gate.Begin("one"); f != nil {
		t.Fatal("concurrent expensive verification admitted")
	}
	finish(false)
	finish(false) // Completion is exactly once.
	if f, _ := gate.Begin("one"); f != nil {
		t.Fatal("failed attempt was not charged")
	}
	f, _ := gate.Begin("two")
	f(false)
	if f, _ := gate.Begin("three"); f != nil {
		t.Fatal("peer storage cap exceeded")
	}
	now = now.Add(time.Minute)
	f, _ = gate.Begin("three")
	if f == nil {
		t.Fatal("expired peers not collected")
	}
	f(true)
	if len(gate.peers) != 0 {
		t.Fatal("expired or successful peers retained")
	}
	for i := 0; i < 10; i++ {
		f, _ := gate.Begin("one")
		if f == nil {
			t.Fatal("success consumed failure budget")
		}
		f(true)
	}
}
