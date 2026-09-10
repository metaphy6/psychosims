package server

import (
	"bytes"
	"context"
	"encoding/json"
	"net/http"
	"net/http/httptest"
	"strings"
	"sync"
	"testing"
	"time"

	"psychosims.dev/server/internal/api"
	"psychosims.dev/server/internal/config"
	"psychosims.dev/server/internal/ctxutil"
	"psychosims.dev/server/internal/offline"
	"psychosims.dev/server/internal/schemas"
	"psychosims.dev/server/internal/tokens"
)

func TestCanonicalReceiptSizeRejectedBeforePersistence(t *testing.T) {
	envelope := schemas.SignedEnvelope{CanonicalReceiptBytes: bytes.Repeat([]byte("x"), schemas.MaxCanonicalReceiptBytes+1)}
	// A nil database deliberately makes any device-key, receipt, audit or
	// profile access fail. These decoder-level rejections must precede them.
	cfg := config.Default()
	catalog, _ := NewCatalog(nil)
	srv := NewOnline(cfg, nil, nil, tokens.NewSQLManager(nil, []byte(strings.Repeat("s", 32)), time.Minute, time.Hour), catalog, []byte(strings.Repeat("s", 32)))
	for _, tc := range []struct {
		name    string
		body    any
		handler http.HandlerFunc
	}{
		{"single", envelope, srv.handleReceipt},
		{"batch", offline.BatchRequest{Envelopes: []schemas.SignedEnvelope{envelope}}, srv.handleBatch},
	} {
		t.Run(tc.name, func(t *testing.T) {
			body, err := json.Marshal(tc.body)
			if err != nil {
				t.Fatal(err)
			}
			req := httptest.NewRequest(http.MethodPost, "/", bytes.NewReader(body))
			req.Header.Set("Content-Type", "application/json")
			req = req.WithContext(ctxutil.WithAccountID(req.Context(), "account"))
			response := httptest.NewRecorder()
			tc.handler(response, req)
			if response.Code != http.StatusRequestEntityTooLarge {
				t.Fatalf("oversized canonical receipt: status=%d body=%s", response.Code, response.Body.String())
			}
		})
	}
}

func TestOnlineNeverTrustsInjectedAccountAndMethod(t *testing.T) {
	cfg := config.Default()
	catalog, _ := NewCatalog(nil)
	srv := NewOnline(cfg, nil, nil, tokens.NewSQLManager(nil, []byte(strings.Repeat("s", 32)), time.Minute, time.Hour), catalog, []byte(strings.Repeat("s", 32)))
	for _, path := range []string{"/v1/boot", "/v1/device-keys", "/v1/sessions", "/v1/receipts", "/v1/receipts/batch", "/v1/auth/link"} {
		method := "POST"
		if path == "/v1/boot" {
			method = "GET"
		}
		req := httptest.NewRequest(method, path, strings.NewReader(`{"account_id":"victim","role":"admin"}`))
		req = req.WithContext(ctxutil.WithAccountID(context.Background(), "injected"))
		req.Header.Set(api.IdempotencyKeyHeader, "test")
		req.Header.Set("Content-Type", "application/json")
		w := httptest.NewRecorder()
		srv.Handler().ServeHTTP(w, req)
		if w.Code != 401 {
			t.Errorf("unverified %s accepted: %d", path, w.Code)
		}
	}
	req := httptest.NewRequest("POST", "/v1/boot", strings.NewReader(`{}`))
	req.Header.Set(api.IdempotencyKeyHeader, "method")
	w := httptest.NewRecorder()
	srv.Handler().ServeHTTP(w, req)
	if w.Code != http.StatusMethodNotAllowed {
		t.Errorf("wrong boot method not rejected: %d", w.Code)
	}
}

func TestOnlineInFlightAdmissionIsSharedAndKeepsLivenessAvailable(t *testing.T) {
	t.Setenv("PSY_HTTP_MAX_IN_FLIGHT", "1")
	cfg := config.Default()
	catalog, _ := NewCatalog(nil)
	srv := NewOnline(cfg, nil, nil, tokens.NewSQLManager(nil, []byte(strings.Repeat("s", 32)), time.Minute, time.Hour), catalog, []byte(strings.Repeat("s", 32)))
	entered := make(chan struct{}, 2)
	release := make(chan struct{})
	var workers sync.WaitGroup
	srv.mux.HandleFunc("GET /hold", func(w http.ResponseWriter, r *http.Request) { entered <- struct{}{}; <-release; w.WriteHeader(200) })
	defer func() { close(release); workers.Wait() }()
	workers.Add(1)
	go func() {
		defer workers.Done()
		srv.Handler().ServeHTTP(httptest.NewRecorder(), httptest.NewRequest("GET", "/hold", nil))
	}()
	<-entered
	response := httptest.NewRecorder()
	second := make(chan struct{})
	workers.Add(1)
	go func() {
		defer workers.Done()
		srv.Handler().ServeHTTP(response, httptest.NewRequest("GET", "/hold", nil))
		close(second)
	}()
	select {
	case <-second:
	case <-time.After(100 * time.Millisecond):
		t.Fatal("excess request entered work instead of immediate admission rejection")
	}
	if response.Code != 503 || response.Header().Get("Retry-After") == "" {
		t.Fatalf("admission response=%d retry=%q", response.Code, response.Header().Get("Retry-After"))
	}
	health := httptest.NewRecorder()
	srv.Handler().ServeHTTP(health, httptest.NewRequest("GET", "/health", nil))
	if health.Code != 200 {
		t.Fatal("saturation hid liveness")
	}
}
