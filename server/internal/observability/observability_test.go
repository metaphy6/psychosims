package observability

import (
	"net/http"
	"net/http/httptest"
	"testing"
	"time"

	"psychosims.dev/server/internal/psylog"
)

func TestMetrics(t *testing.T) {
	m := NewMetrics()
	m.Inc("receipts_accepted")
	m.Inc("receipts_accepted")
	m.Gauge("queue_depth", 5)
	m.RecordTimer("validate_latency", 10*time.Millisecond)

	if m.Counter("receipts_accepted") != 2 {
		t.Errorf("counter = %d, want 2", m.Counter("receipts_accepted"))
	}
	if m.GaugeValue("queue_depth") != 5 {
		t.Errorf("gauge = %d, want 5", m.GaugeValue("queue_depth"))
	}
	if m.TimerCount("validate_latency") != 1 {
		t.Errorf("timer count = %d, want 1", m.TimerCount("validate_latency"))
	}
}

func TestTraceMiddleware(t *testing.T) {
	logger := NewLogger(&psylog.Logger{MinLevel: psylog.Info, JSONMode: true, CorrelationID: "c1"})
	metrics := NewMetrics()
	handler := TraceMiddleware(logger, metrics)(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		w.WriteHeader(http.StatusOK)
	}))

	req := httptest.NewRequest(http.MethodGet, "/test", nil)
	rec := httptest.NewRecorder()
	handler.ServeHTTP(rec, req)

	if rec.Code != http.StatusOK {
		t.Errorf("status = %d, want %d", rec.Code, http.StatusOK)
	}
	if metrics.Counter("http_requests_total") != 1 {
		t.Errorf("requests counter = %d, want 1", metrics.Counter("http_requests_total"))
	}
	if metrics.TimerCount("http_request_duration") != 1 {
		t.Errorf("timer count = %d, want 1", metrics.TimerCount("http_request_duration"))
	}
}

func TestStatusTracingMiddleware(t *testing.T) {
	metrics := NewMetrics()
	handler := StatusTracingMiddleware(metrics)(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		w.WriteHeader(http.StatusBadRequest)
	}))

	req := httptest.NewRequest(http.MethodGet, "/", nil)
	rec := httptest.NewRecorder()
	handler.ServeHTTP(rec, req)

	if metrics.Counter("http_4xx_total") != 1 {
		t.Errorf("4xx counter = %d, want 1", metrics.Counter("http_4xx_total"))
	}
}
