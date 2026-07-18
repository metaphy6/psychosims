package config

import (
	"testing"
	"time"
)

func TestDefaultConfig(t *testing.T) {
	cfg := Default()
	if cfg.ListenAddr == "" {
		t.Error("ListenAddr should have a default")
	}
	if cfg.DatabaseDSN == "" {
		t.Error("DatabaseDSN should have a default")
	}
}

func TestValidate(t *testing.T) {
	cfg := Default()
	if err := cfg.Validate(); err != nil {
		t.Errorf("valid config failed validation: %v", err)
	}

	cfg.ListenAddr = ""
	if err := cfg.Validate(); err == nil {
		t.Error("expected error for empty listen_addr")
	}

	cfg = Default()
	cfg.DatabasePoolMin = 100
	cfg.DatabasePoolMax = 10
	if err := cfg.Validate(); err == nil {
		t.Error("expected error when pool max < min")
	}
}

func TestGetenvDuration(t *testing.T) {
	if getenvDuration("PSY_NOT_SET_TEST", time.Second) != time.Second {
		t.Error("fallback duration not returned")
	}
}
