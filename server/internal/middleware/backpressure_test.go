package middleware

import (
	"net/http"
	"net/http/httptest"
	"testing"
)

func TestBackpressureRejectsOverDepth(t *testing.T) {
	counter := NewInFlightCounter(2)
	handler := Backpressure(BackpressureLimits{MaxDepth: 1, RetryAfter: 5}, counter)(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		w.WriteHeader(http.StatusOK)
	}))

	// Push counter to the limit.
	counter.Acquire()

	req := httptest.NewRequest(http.MethodGet, "/", nil)
	rec := httptest.NewRecorder()
	handler.ServeHTTP(rec, req)

	if rec.Code != http.StatusServiceUnavailable {
		t.Errorf("status = %d, want %d", rec.Code, http.StatusServiceUnavailable)
	}
}

func TestInFlightMiddlewareAcquiresAndReleases(t *testing.T) {
	counter := NewInFlightCounter(1)
	handler := InFlightMiddleware(counter)(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		w.WriteHeader(http.StatusOK)
	}))

	req := httptest.NewRequest(http.MethodGet, "/", nil)
	rec := httptest.NewRecorder()
	handler.ServeHTTP(rec, req)

	if rec.Code != http.StatusOK {
		t.Errorf("status = %d, want %d", rec.Code, http.StatusOK)
	}
	if counter.Depth() != 0 {
		t.Errorf("depth = %d, want 0", counter.Depth())
	}
}

func TestInFlightOverloadGivesRetryAfterAndReleasesAfterCancellation(t *testing.T) {
	counter := NewInFlightCounter(1)
	if !counter.Acquire() {
		t.Fatal("fixture reservation failed")
	}
	h := InFlightMiddleware(counter)(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) { w.WriteHeader(200) }))
	w := httptest.NewRecorder()
	h.ServeHTTP(w, httptest.NewRequest("GET", "/", nil))
	if w.Code != 503 || w.Header().Get("Retry-After") == "" {
		t.Fatal("overload has no retry guidance")
	}
	counter.Release()
	w = httptest.NewRecorder()
	h.ServeHTTP(w, httptest.NewRequest("GET", "/", nil))
	if w.Code != 200 || counter.Depth() != 0 {
		t.Fatal("admission did not recover")
	}
}
