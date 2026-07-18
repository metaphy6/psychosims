package middleware

import (
	"net/http"
	"net/http/httptest"
	"testing"

	"psychosims.dev/server/internal/api"
	"psychosims.dev/server/internal/ctxutil"
)

func TestRequestContext(t *testing.T) {
	handler := RequestContext(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		if ctxutil.CorrelationID(r.Context()) == "" {
			t.Error("expected correlation id")
		}
		if ctxutil.RequestID(r.Context()) == "" {
			t.Error("expected request id")
		}
		w.WriteHeader(http.StatusOK)
	}))

	req := httptest.NewRequest(http.MethodGet, "/", nil)
	rec := httptest.NewRecorder()
	handler.ServeHTTP(rec, req)

	if rec.Code != http.StatusOK {
		t.Errorf("status = %d, want %d", rec.Code, http.StatusOK)
	}
	if rec.Header().Get(api.CorrelationIDHeader) == "" {
		t.Error("expected correlation id response header")
	}
}

func TestRequireIdempotencyKey(t *testing.T) {
	handler := RequestContext(RequireIdempotencyKey(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		w.WriteHeader(http.StatusOK)
	})))

	req := httptest.NewRequest(http.MethodPost, "/", nil)
	rec := httptest.NewRecorder()
	handler.ServeHTTP(rec, req)

	if rec.Code != http.StatusBadRequest {
		t.Errorf("status = %d, want %d", rec.Code, http.StatusBadRequest)
	}
}

func TestAPIVersionHeader(t *testing.T) {
	handler := APIVersion(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		w.WriteHeader(http.StatusOK)
	}))

	req := httptest.NewRequest(http.MethodGet, "/", nil)
	rec := httptest.NewRecorder()
	handler.ServeHTTP(rec, req)

	if got := rec.Header().Get(api.VersionHeader); got != api.Version {
		t.Errorf("version header = %q, want %q", got, api.Version)
	}
}
