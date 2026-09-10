package ratelimit

import (
	"net/http"
	"net/http/httptest"
	"testing"
	"time"
)

func TestRateLimitIgnoresUntrustedForwardingAndSourcePort(t *testing.T) {
	h := Middleware(NewService(Limits{PreAuthPerIP: 1, AuthPerAccount: 1, Window: time.Minute}))(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) { w.WriteHeader(204) }))
	for i, remote := range []string{"127.0.0.1:3000", "127.0.0.1:4000"} {
		req := httptest.NewRequest("GET", "/", nil)
		req.RemoteAddr = remote
		req.Header.Set("X-Forwarded-For", remote)
		w := httptest.NewRecorder()
		h.ServeHTTP(w, req)
		if i == 1 && (w.Code != 429 || w.Header().Get("Retry-After") == "") {
			t.Fatalf("spoof bypass status=%d retry=%q", w.Code, w.Header().Get("Retry-After"))
		}
	}
}
