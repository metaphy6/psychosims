// Package ratelimit implements Phase 3.1 abuse prevention: per-IP (pre-auth),
// per-account, and per-endpoint rate limits with 429 Retry-After.
package ratelimit

import (
	"net"
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

type authPeer struct {
	failures, inFlight int
	expires            time.Time
}

// AuthAttemptGate reserves a bounded peer allowance before expensive bearer
// verification. Only failed authentication consumes the window's budget;
// successful verification and dependency outages release their reservation.
type AuthAttemptGate struct {
	mu              sync.Mutex
	peers           map[string]*authPeer
	limit, maxPeers int
	window          time.Duration
	now             func() time.Time
}

func NewAuthAttemptGate(limit int, window time.Duration) *AuthAttemptGate {
	return &AuthAttemptGate{peers: make(map[string]*authPeer), limit: limit, maxPeers: 4096, window: window, now: time.Now}
}

// Begin returns nil when admission is denied. A permitted caller must invoke
// the returned completion once (true when no authentication failure occurred).
func (g *AuthAttemptGate) Begin(peer string) (func(bool), time.Duration) {
	g.mu.Lock()
	defer g.mu.Unlock()
	now := g.now()
	for key, p := range g.peers {
		if p.inFlight == 0 && !now.Before(p.expires) {
			delete(g.peers, key)
		}
	}
	p := g.peers[peer]
	if p == nil {
		if len(g.peers) >= g.maxPeers {
			return nil, g.window
		}
		p = &authPeer{expires: now.Add(g.window)}
		g.peers[peer] = p
	}
	if p.failures+p.inFlight >= g.limit {
		return nil, g.window
	}
	p.inFlight++
	var once sync.Once
	return func(success bool) {
		once.Do(func() {
			g.mu.Lock()
			defer g.mu.Unlock()
			p.inFlight--
			if !success {
				p.failures++
				p.expires = g.now().Add(g.window)
			}
			if p.inFlight == 0 && p.failures == 0 {
				delete(g.peers, peer)
			}
		})
	}, 0
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
	mu     sync.Mutex
	window time.Duration
	limit  int
	events []time.Time
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
	limits         Limits
	ipBuckets      map[string]*bucket
	accountBuckets map[string]*bucket
	mu             sync.Mutex
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
			if host, _, err := net.SplitHostPort(clientIP); err == nil {
				clientIP = host
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
