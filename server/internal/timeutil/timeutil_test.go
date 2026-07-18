package timeutil

import (
	"testing"
	"time"
)

func TestRealClockNowUTC(t *testing.T) {
	before := time.Now().UTC()
	now := RealClock{}.Now()
	after := time.Now().UTC()
	if now.Before(before) || now.After(after) {
		t.Errorf("clock now = %v, expected between %v and %v", now, before, after)
	}
	if now.Location().String() != "UTC" {
		t.Errorf("location = %v, want UTC", now.Location())
	}
}

func TestFixedClockAdvance(t *testing.T) {
	start := time.Date(2026, 1, 1, 0, 0, 0, 0, time.UTC)
	clock := &FixedClock{T: start}
	clock.Advance(time.Hour)
	if !clock.Now().Equal(start.Add(time.Hour)) {
		t.Errorf("time = %v, want %v", clock.Now(), start.Add(time.Hour))
	}
}

func TestNewServerTimeResponse(t *testing.T) {
	start := time.Date(2026, 1, 1, 0, 0, 0, 0, time.UTC)
	resp := NewServerTimeResponse(FixedClock{T: start})
	if resp.ServerTimeUnix != start.Unix() {
		t.Errorf("unix = %d, want %d", resp.ServerTimeUnix, start.Unix())
	}
}
