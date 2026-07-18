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
