// Package middleware backpressure fast-rejects requests when a bounded queue
// depth is exceeded (Phase 3.3).
package middleware

import (
	"net/http"
	"strconv"
	"sync"

	"psychosims.dev/server/internal/api"
	"psychosims.dev/server/internal/ctxutil"
)

// QueueDepth reports the current depth of a downstream queue.
type QueueDepth interface {
	Depth() int
}

// BackpressureLimits configures the fast-reject threshold.
type BackpressureLimits struct {
	MaxDepth   int
	RetryAfter int
}

// DefaultBackpressureLimits returns a sensible production default.
func DefaultBackpressureLimits() BackpressureLimits {
	return BackpressureLimits{MaxDepth: 1000, RetryAfter: 5}
}

// InFlightCounter is a simple in-memory backpressure counter.
type InFlightCounter struct {
	max   int
	count int
	mu    sync.Mutex
}

// NewInFlightCounter creates a counter with the given max.
func NewInFlightCounter(max int) *InFlightCounter {
	return &InFlightCounter{max: max}
}

// Depth returns the current count.
func (c *InFlightCounter) Depth() int {
	c.mu.Lock()
	defer c.mu.Unlock()
	return c.count
}

// Acquire increments the counter if under max.
func (c *InFlightCounter) Acquire() bool {
	c.mu.Lock()
	defer c.mu.Unlock()
	if c.count >= c.max {
		return false
	}
	c.count++
	return true
}

// Release decrements the counter.
func (c *InFlightCounter) Release() {
	c.mu.Lock()
	defer c.mu.Unlock()
	if c.count > 0 {
		c.count--
	}
}

// Backpressure returns middleware that fast-rejects with 503/Retry-After when
// the configured queue depth is exceeded.
func Backpressure(limits BackpressureLimits, depth QueueDepth) func(http.Handler) http.Handler {
	return func(next http.Handler) http.Handler {
		return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
			if depth.Depth() >= limits.MaxDepth {
				w.Header().Set("Retry-After", strconv.Itoa(max(1, limits.RetryAfter)))
				api.NewServiceUnavailable("server queue depth exceeded").Write(w, ctxutil.RequestID(r.Context()))
				return
			}
			next.ServeHTTP(w, r)
		})
	}
}

// InFlightMiddleware wraps a handler with an acquire/release counter.
func InFlightMiddleware(counter *InFlightCounter) func(http.Handler) http.Handler {
	return func(next http.Handler) http.Handler {
		return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
			if !counter.Acquire() {
				w.Header().Set("Retry-After", "1")
				api.NewError(http.StatusServiceUnavailable, api.ErrExternal, api.CodeServiceUnavailable,
					"too many in-flight requests").Write(w, ctxutil.RequestID(r.Context()))
				return
			}
			defer counter.Release()
			next.ServeHTTP(w, r)
		})
	}
}
