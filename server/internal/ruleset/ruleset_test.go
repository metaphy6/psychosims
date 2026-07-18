package ruleset

import (
	"testing"
	"time"
)

func TestRegistry(t *testing.T) {
	cfg := Config{
		KnownVersions: []string{"0.1.0", "0.2.0"},
		SunsetWindow:  30 * 24 * time.Hour,
	}
	r := NewRegistry(cfg)

	if !r.IsKnown("0.1.0") {
		t.Error("expected 0.1.0 to be known")
	}
	if r.IsKnown("0.3.0") {
		t.Error("expected 0.3.0 to be unknown")
	}

	// Not sunset immediately after creation.
	if r.IsSunset("0.1.0", time.Now().UTC()) {
		t.Error("expected fresh version not to be sunset")
	}

	// Far future version is sunset.
	future := time.Now().UTC().Add(365 * 24 * time.Hour)
	if !r.IsSunset("0.1.0", future) {
		t.Error("expected old version to be sunset in the future")
	}

	// Kill switch sunsets everything.
	r.SetKillSwitch(true)
	if !r.IsSunset("0.2.0", time.Now().UTC()) {
		t.Error("expected kill-switch to sunset all versions")
	}
}

func TestRegisterVersion(t *testing.T) {
	r := NewRegistry(Config{})
	now := time.Now().UTC()
	if err := r.Register("1.0.0", now, nil); err != nil {
		t.Fatalf("register: %v", err)
	}
	if !r.IsKnown("1.0.0") {
		t.Error("expected registered version to be known")
	}
}
