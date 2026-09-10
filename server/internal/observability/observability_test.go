package observability

import (
	"fmt"
	"io"
	"math"
	"net/http"
	"net/http/httptest"
	"os"
	"reflect"
	"strings"
	"sync"
	"testing"
	"time"

	"psychosims.dev/server/internal/psylog"
)

func TestMetricsRetainBoundedAggregateInsteadOfEveryObservation(t *testing.T) {
	m := NewMetrics()
	for i := 0; i < 100000; i++ {
		m.RecordTimer("duration", time.Millisecond)
	}
	if m.TimerCount("duration") != 100000 {
		t.Fatal("aggregate lost observations")
	}
	if value := reflect.ValueOf(m.timers["duration"]); value.Kind() == reflect.Slice && value.Len() > 128 {
		t.Fatalf("timer retains %d raw observations instead of bounded aggregates", value.Len())
	}
}

func TestMetricsBoundSeriesAndRejectUntrustedNames(t *testing.T) {
	m := NewMetrics()
	for i := 0; i < 5000; i++ {
		name := fmt.Sprintf("metric_%d", i)
		m.Inc(name)
		m.Gauge(name, 1)
		m.RecordTimer(name, time.Millisecond)
	}
	if len(m.counters) > 128 || len(m.gauges) > 128 || len(m.timers) > 128 {
		t.Fatalf("unbounded series: %d counters, %d gauges, %d timers", len(m.counters), len(m.gauges), len(m.timers))
	}
	m.Inc("metric_0")
	m.Gauge("metric_0", 9)
	m.RecordTimer("metric_0", 2*time.Millisecond)
	if m.Counter("metric_0") != 2 || m.GaugeValue("metric_0") != 9 || m.TimerCount("metric_0") != 2 || m.Dropped() != 3*(5000-128) {
		t.Fatal("full metric sink failed to update existing series or account for drops")
	}
	m = NewMetrics()
	for _, name := range []string{"", "patient private dialogue", "/arbitrary/url", "token=secret"} {
		m.Inc(name)
		m.Gauge(name, 1)
		m.RecordTimer(name, time.Second)
	}
	if len(m.counters)+len(m.gauges)+len(m.timers) != 0 {
		t.Fatal("invalid metric names retained")
	}
}

func TestTimerHistogramAndConcurrentCounts(t *testing.T) {
	m := NewMetrics()
	var workers sync.WaitGroup
	for worker := 0; worker < 8; worker++ {
		workers.Add(1)
		go func() {
			defer workers.Done()
			for i := 0; i < 10000; i++ {
				m.RecordTimer("duration", 2*time.Millisecond)
				m.Inc("requests")
			}
		}()
	}
	workers.Wait()
	got := m.TimerSnapshot("duration")
	if got.Count != 80000 || got.Buckets[1] != 80000 || got.Max != 2*time.Millisecond || got.Sum != 160*time.Second || m.Counter("requests") != 80000 {
		t.Fatalf("lost or incorrect concurrent aggregates: %+v", got)
	}
	got.Buckets[1] = 0
	if m.TimerSnapshot("duration").Buckets[1] != 80000 {
		t.Fatal("snapshot aliases internal state")
	}
	for _, upper := range timerBounds {
		m.RecordTimer("bounds", upper)
	}
	m.RecordTimer("bounds", time.Minute)
	for _, count := range m.TimerSnapshot("bounds").Buckets {
		if count != 1 {
			t.Fatal("histogram boundary incorrectly classified")
		}
	}
	m.RecordTimer("negative", -time.Second)
	if m.TimerCount("negative") != 0 || m.Dropped() != 1 {
		t.Fatal("negative timer retained")
	}
	m.RecordTimer("large", time.Duration(math.MaxInt64))
	m.RecordTimer("large", time.Second)
	if m.TimerSnapshot("large").Sum != time.Duration(math.MaxInt64) {
		t.Fatal("timer sum overflowed")
	}
	m.counters["saturated"] = math.MaxInt64
	m.Inc("saturated")
	if m.Counter("saturated") != math.MaxInt64 {
		t.Fatal("counter overflowed")
	}
}

func TestTraceDoesNotRetainRequestPathQueryOrCustomMethod(t *testing.T) {
	reader, writer, err := os.Pipe()
	if err != nil {
		t.Fatal(err)
	}
	original := os.Stderr
	os.Stderr = writer
	defer func() { os.Stderr = original; reader.Close(); writer.Close() }()
	logger := NewLogger(&psylog.Logger{MinLevel: psylog.Info, JSONMode: true})
	handler := TraceMiddleware(logger, NewMetrics())(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) { w.WriteHeader(http.StatusOK) }))
	handler.ServeHTTP(httptest.NewRecorder(), httptest.NewRequest("PRIVATE_METHOD_SENTINEL", "/private-dialogue-sentinel?token=private-query-sentinel", nil))
	writer.Close()
	os.Stderr = original
	output, err := io.ReadAll(reader)
	if err != nil {
		t.Fatal(err)
	}
	if strings.Contains(strings.ToLower(string(output)), "private") || !strings.Contains(string(output), "OTHER") {
		t.Fatalf("unexpected request telemetry: %s", output)
	}
}

func TestStatusTracingUsesFirstFinalResponseStatus(t *testing.T) {
	metrics := NewMetrics()
	handler := StatusTracingMiddleware(metrics)(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		_, _ = w.Write([]byte("ok"))
		w.WriteHeader(http.StatusInternalServerError)
	}))
	response := httptest.NewRecorder()
	handler.ServeHTTP(response, httptest.NewRequest(http.MethodGet, "/", nil))
	if response.Code != http.StatusOK || metrics.Counter("http_5xx_total") != 0 {
		t.Fatal("metrics recorded a status that was never sent")
	}
}

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
