// Package observability implements the server-side 0.7 logging, metrics, and
// request-tracing seam for Phase 3.7.
package observability

import (
	"net/http"
	"sync"
	"time"

	"psychosims.dev/server/internal/api"
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

// Metrics is a minimal counter / gauge / timer sink.
type Metrics struct {
	mu      sync.Mutex
	counters map[string]int64
	gauges   map[string]int64
	timers   map[string][]time.Duration
}

// NewMetrics creates a metrics sink.
func NewMetrics() *Metrics {
	return &Metrics{
		counters: make(map[string]int64),
		gauges:   make(map[string]int64),
		timers:   make(map[string][]time.Duration),
	}
}

// Inc increments a counter.
func (m *Metrics) Inc(name string) {
	m.mu.Lock()
	defer m.mu.Unlock()
	m.counters[name]++
}

// Gauge sets a gauge.
func (m *Metrics) Gauge(name string, v int64) {
	m.mu.Lock()
	defer m.mu.Unlock()
	m.gauges[name] = v
}

// RecordTimer records a timer observation.
func (m *Metrics) RecordTimer(name string, d time.Duration) {
	m.mu.Lock()
	defer m.mu.Unlock()
	m.timers[name] = append(m.timers[name], d)
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
	return len(m.timers[name])
}

// TraceMiddleware captures per-request timing and propagates correlation ids.
func TraceMiddleware(logger *Logger, metrics *Metrics) func(http.Handler) http.Handler {
	return func(next http.Handler) http.Handler {
		return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
			start := time.Now()
			correlationID := ctxutil.CorrelationID(r.Context())
			logger.WithCorrelation(correlationID).Info("http", "request_start", psylog.KV{
				"method": r.Method,
				"path":   r.URL.Path,
			})
			next.ServeHTTP(w, r)
			duration := time.Since(start)
			metrics.Inc("http_requests_total")
			metrics.RecordTimer("http_request_duration", duration)
			logger.WithCorrelation(correlationID).Info("http", "request_done", psylog.KV{
				"method":   r.Method,
				"path":     r.URL.Path,
				"duration": duration.String(),
			})
		})
	}
}

// ResponseWriter wrapper to capture status code.
type responseRecorder struct {
	http.ResponseWriter
	status int
}

func (r *responseRecorder) WriteHeader(status int) {
	r.status = status
	r.ResponseWriter.WriteHeader(status)
}

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

// Avoid unused imports.
var _ = api.Version
