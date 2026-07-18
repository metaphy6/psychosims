// Package timeutil provides the authoritative server-time seam (0.8).
//
// All TTLs, leases, sunset windows, and cadence use the injected Clock. The
// device clock is never trusted for authoritative decisions.
package timeutil

import "time"

// Clock abstracts wall-clock and monotonic time sources.
type Clock interface {
	// Now returns the current authoritative wall time.
	Now() time.Time
	// Since returns the duration since t using a monotonic source.
	Since(t time.Time) time.Duration
}

// RealClock uses the Go runtime's time package.
type RealClock struct{}

// Now implements Clock.
func (RealClock) Now() time.Time { return time.Now().UTC() }

// Since implements Clock.
func (RealClock) Since(t time.Time) time.Duration { return time.Since(t) }

// FixedClock is a deterministic clock for tests.
type FixedClock struct {
	T time.Time
}

// Now implements Clock.
func (c FixedClock) Now() time.Time { return c.T }

// Since implements Clock.
func (c FixedClock) Since(t time.Time) time.Duration { return c.T.Sub(t) }

// Advance moves the fixed clock forward by d.
func (c *FixedClock) Advance(d time.Duration) { c.T = c.T.Add(d) }

// ServerTimeResponse is the payload returned by the time-sync endpoint.
type ServerTimeResponse struct {
	ServerTimeRFC3339 string `json:"server_time_rfc3339"`
	ServerTimeUnix    int64  `json:"server_time_unix"`
}

// NewServerTimeResponse builds a response from a clock.
func NewServerTimeResponse(clock Clock) ServerTimeResponse {
	now := clock.Now()
	return ServerTimeResponse{
		ServerTimeRFC3339: now.Format(time.RFC3339),
		ServerTimeUnix:    now.Unix(),
	}
}
