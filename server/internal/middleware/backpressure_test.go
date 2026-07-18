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
