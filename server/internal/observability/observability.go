// Package observability implements the server-side 0.7 logging, metrics, and
// request-tracing seam for Phase 3.7.
package observability

import (
	"math"
	"net/http"
	"sync"
	"time"

	"psychosims.dev/server/internal/ctxutil"
	"psychosims.dev/server/internal/psylog"
)

// Logger is the structured server logger.
type Logger struct {
	inner *psylog.Logger
}

// NewLogger builds a server logger from the psylog base.
func NewLogger(base *psylog.Logger) *Logger {
	return &Logger{inner: base}
}

// WithCorrelation returns a logger scoped to the correlation id.
func (l *Logger) WithCorrelation(id string) *Logger {
	cp := *l.inner
	cp.CorrelationID = id
	return &Logger{inner: &cp}
}

// Info logs an info event.
func (l *Logger) Info(scope, event string, kv psylog.KV) { l.inner.Info(scope, event, kv) }

// Error logs an error event.
func (l *Logger) Error(scope, event string, kv psylog.KV) { l.inner.Error(scope, event, kv) }

// Metric storage limits are invariants, independent of traffic volume. Names
// must be static instrumentation keys, never account IDs, paths or labels.
const maxMetricSeries = 128
const maxMetricNameBytes = 96

var timerBounds = [...]time.Duration{time.Millisecond, 5 * time.Millisecond, 10 * time.Millisecond, 25 * time.Millisecond, 50 * time.Millisecond, 100 * time.Millisecond, 250 * time.Millisecond, 500 * time.Millisecond, time.Second, 2500 * time.Millisecond, 5 * time.Second, 10 * time.Second}

// TimerSummary retains fixed histogram buckets, not raw observations. Buckets
// are noncumulative and the final bucket is greater than the last bound.
type TimerSummary struct {
	Count   uint64
	Sum     time.Duration
	Max     time.Duration
	Buckets [13]uint64
}

// Metrics is a bounded counter / gauge / timer sink.
type Metrics struct {
	mu       sync.Mutex
	counters map[string]int64
	gauges   map[string]int64
	timers   map[string]TimerSummary
	dropped  uint64
}

// NewMetrics creates a metrics sink.
func NewMetrics() *Metrics {
	return &Metrics{
		counters: make(map[string]int64),
		gauges:   make(map[string]int64),
		timers:   make(map[string]TimerSummary),
	}
}

func validMetricName(name string) bool {
	if len(name) == 0 || len(name) > maxMetricNameBytes {
		return false
	}
	for _, c := range name {
		if !((c >= 'a' && c <= 'z') || (c >= 'A' && c <= 'Z') || (c >= '0' && c <= '9') || c == '_' || c == ':') {
			return false
		}
	}
	return true
}

func acceptMetricName[V any](name string, series map[string]V) bool {
	if !validMetricName(name) {
		return false
	}
	_, exists := series[name]
	return exists || len(series) < maxMetricSeries
}

func increment(value uint64) uint64 {
	if value == math.MaxUint64 {
		return value
	}
	return value + 1
}

// Inc increments a counter.
func (m *Metrics) Inc(name string) {
	m.mu.Lock()
	defer m.mu.Unlock()
	if !acceptMetricName(name, m.counters) {
		m.dropped = increment(m.dropped)
		return
	}
	if m.counters[name] < math.MaxInt64 {
		m.counters[name]++
	}
}

// Gauge sets a gauge.
func (m *Metrics) Gauge(name string, v int64) {
	m.mu.Lock()
	defer m.mu.Unlock()
	if !acceptMetricName(name, m.gauges) {
		m.dropped = increment(m.dropped)
		return
	}
	m.gauges[name] = v
}

// RecordTimer records a timer observation.
func (m *Metrics) RecordTimer(name string, d time.Duration) {
	m.mu.Lock()
	defer m.mu.Unlock()
	if d < 0 || !acceptMetricName(name, m.timers) {
		m.dropped = increment(m.dropped)
		return
	}
	summary := m.timers[name]
	summary.Count = increment(summary.Count)
	if d > summary.Max {
		summary.Max = d
	}
	if d > time.Duration(math.MaxInt64)-summary.Sum {
		summary.Sum = time.Duration(math.MaxInt64)
	} else {
		summary.Sum += d
	}
	bucket := len(timerBounds)
	for i, upper := range timerBounds {
		if d <= upper {
			bucket = i
			break
		}
	}
	summary.Buckets[bucket] = increment(summary.Buckets[bucket])
	m.timers[name] = summary
}

// Counter returns a counter value.
func (m *Metrics) Counter(name string) int64 {
	m.mu.Lock()
	defer m.mu.Unlock()
	return m.counters[name]
}

// GaugeValue returns a gauge value.
func (m *Metrics) GaugeValue(name string) int64 {
	m.mu.Lock()
	defer m.mu.Unlock()
	return m.gauges[name]
}

// TimerCount returns the number of timer observations.
func (m *Metrics) TimerCount(name string) int {
	m.mu.Lock()
	defer m.mu.Unlock()
	count := m.timers[name].Count
	if count > uint64(math.MaxInt) {
		return math.MaxInt
	}
	return int(count)
}

// TimerSnapshot returns a value copy that cannot mutate the stored aggregate.
func (m *Metrics) TimerSnapshot(name string) TimerSummary {
	m.mu.Lock()
	defer m.mu.Unlock()
	return m.timers[name]
}

// Dropped reports invalid observations and names rejected at the series cap.
func (m *Metrics) Dropped() uint64 {
	m.mu.Lock()
	defer m.mu.Unlock()
	return m.dropped
}

func requestMethod(method string) string {
	switch method {
	case http.MethodGet, http.MethodPost, http.MethodPut, http.MethodPatch, http.MethodDelete, http.MethodHead, http.MethodOptions, http.MethodConnect, http.MethodTrace:
		return method
	default:
		return "OTHER"
	}
}

// TraceMiddleware captures per-request timing and propagates correlation ids.
func TraceMiddleware(logger *Logger, metrics *Metrics) func(http.Handler) http.Handler {
	return func(next http.Handler) http.Handler {
		return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
			start := time.Now()
			correlationID := ctxutil.CorrelationID(r.Context())
			logger.WithCorrelation(correlationID).Info("http", "request_start", psylog.KV{
				"method": requestMethod(r.Method),
			})
			next.ServeHTTP(w, r)
			duration := time.Since(start)
			metrics.Inc("http_requests_total")
			metrics.RecordTimer("http_request_duration", duration)
			logger.WithCorrelation(correlationID).Info("http", "request_done", psylog.KV{
				"method":   requestMethod(r.Method),
				"duration": duration.String(),
			})
		})
	}
}

// ResponseWriter wrapper to capture status code.
type responseRecorder struct {
	http.ResponseWriter
	status      int
	wroteHeader bool
}

func (r *responseRecorder) WriteHeader(status int) {
	if r.wroteHeader {
		return
	}
	if status >= 100 && status < 200 && status != http.StatusSwitchingProtocols {
		r.ResponseWriter.WriteHeader(status)
		return
	}
	r.wroteHeader = true
	r.status = status
	r.ResponseWriter.WriteHeader(status)
}

func (r *responseRecorder) Write(body []byte) (int, error) {
	if !r.wroteHeader {
		r.WriteHeader(http.StatusOK)
	}
	return r.ResponseWriter.Write(body)
}

// Unwrap preserves ResponseController support for optional HTTP operations.
func (r *responseRecorder) Unwrap() http.ResponseWriter { return r.ResponseWriter }

// StatusTracingMiddleware captures HTTP status codes.
func StatusTracingMiddleware(metrics *Metrics) func(http.Handler) http.Handler {
	return func(next http.Handler) http.Handler {
		return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
			rec := &responseRecorder{ResponseWriter: w, status: http.StatusOK}
			next.ServeHTTP(rec, r)
			if rec.status >= 500 {
				metrics.Inc("http_5xx_total")
			} else if rec.status >= 400 {
				metrics.Inc("http_4xx_total")
			}
		})
	}
}
