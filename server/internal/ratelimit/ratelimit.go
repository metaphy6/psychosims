// Package ratelimit implements Phase 3.1 abuse prevention: per-IP (pre-auth),
// per-account, and per-endpoint rate limits with 429 Retry-After.
package ratelimit

import (
	"net/http"
	"sync"
	"time"

	"psychosims.dev/server/internal/api"
	"psychosims.dev/server/internal/ctxutil"
)

// Limits defines rate-limit policy.
type Limits struct {
	PreAuthPerIP   int
	AuthPerAccount int
	Window         time.Duration
}

// DefaultLimits returns the policy from the server config defaults.
func DefaultLimits() Limits {
	return Limits{
		PreAuthPerIP:   20,
		AuthPerAccount: 100,
		Window:         time.Minute,
	}
}

// bucket tracks requests in a sliding window.
type bucket struct {
	mu      sync.Mutex
	window  time.Duration
	limit   int
	events  []time.Time
}

func newBucket(limit int, window time.Duration) *bucket {
	return &bucket{limit: limit, window: window}
}

func (b *bucket) allow(now time.Time) bool {
	b.mu.Lock()
	defer b.mu.Unlock()
	cutoff := now.Add(-b.window)
	n := 0
	for _, e := range b.events {
		if e.After(cutoff) {
			b.events[n] = e
			n++
		}
	}
	b.events = b.events[:n]
	if n >= b.limit {
		return false
	}
	b.events = append(b.events, now)
	return true
}

// Service is the in-memory rate limiter.
type Service struct {
	limits  Limits
	ipBuckets   map[string]*bucket
	accountBuckets map[string]*bucket
	mu          sync.Mutex
}

// NewService builds a rate limiter.
func NewService(limits Limits) *Service {
	return &Service{
		limits:         limits,
		ipBuckets:      make(map[string]*bucket),
		accountBuckets: make(map[string]*bucket),
	}
}

// Allow checks whether the request may proceed. It uses account id when present,
// otherwise client IP.
func (s *Service) Allow(accountID, clientIP string) (bool, time.Duration) {
	s.mu.Lock()
	defer s.mu.Unlock()

	now := time.Now().UTC()
	if accountID != "" {
		b := s.accountBuckets[accountID]
		if b == nil {
			b = newBucket(s.limits.AuthPerAccount, s.limits.Window)
			s.accountBuckets[accountID] = b
		}
		if !b.allow(now) {
			return false, s.limits.Window
		}
		return true, 0
	}

	b := s.ipBuckets[clientIP]
	if b == nil {
		b = newBucket(s.limits.PreAuthPerIP, s.limits.Window)
		s.ipBuckets[clientIP] = b
	}
	if !b.allow(now) {
		return false, s.limits.Window
	}
	return true, 0
}

// Middleware applies rate limiting to requests.
func Middleware(svc *Service) func(http.Handler) http.Handler {
	return func(next http.Handler) http.Handler {
		return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
			accountID := ctxutil.AccountID(r.Context())
			clientIP := r.RemoteAddr
			if forwarded := r.Header.Get("X-Forwarded-For"); forwarded != "" {
				clientIP = forwarded
			}
			ok, retry := svc.Allow(accountID, clientIP)
			if !ok {
				api.NewRateLimited(int(retry.Seconds())).Write(w, ctxutil.RequestID(r.Context()))
				return
			}
			next.ServeHTTP(w, r)
		})
	}
}
