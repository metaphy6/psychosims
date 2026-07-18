package api

import (
	"encoding/json"
	"net/http"
	"net/http/httptest"
	"testing"
)

func TestNewUserError(t *testing.T) {
	err := NewUserError(CodeBadRequest, "missing idempotency key")
	if err.Status != http.StatusBadRequest {
		t.Errorf("status = %d, want %d", err.Status, http.StatusBadRequest)
	}
	if err.Body.Kind != ErrUser {
		t.Errorf("kind = %q, want %q", err.Body.Kind, ErrUser)
	}
	if err.Body.Code != CodeBadRequest {
		t.Errorf("code = %q, want %q", err.Body.Code, CodeBadRequest)
	}
}

func TestRateLimitedRetryAfter(t *testing.T) {
	err := NewRateLimited(30)
	if err.Status != http.StatusTooManyRequests {
		t.Errorf("status = %d, want %d", err.Status, http.StatusTooManyRequests)
	}
	if err.Body.RetryAfter == nil || *err.Body.RetryAfter != 30 {
		t.Errorf("retry_after = %v, want 30", err.Body.RetryAfter)
	}
}

func TestWriteIncludesRequestID(t *testing.T) {
	rec := httptest.NewRecorder()
	NewUnauthorized("bad token").Write(rec, "req-123")

	if rec.Code != http.StatusUnauthorized {
		t.Errorf("code = %d, want %d", rec.Code, http.StatusUnauthorized)
	}

	var body ErrorResponse
	if err := json.Unmarshal(rec.Body.Bytes(), &body); err != nil {
		t.Fatalf("decode: %v", err)
	}
	if body.RequestID != "req-123" {
		t.Errorf("request_id = %q, want %q", body.RequestID, "req-123")
	}
}
