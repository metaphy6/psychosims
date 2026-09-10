package config

import (
	"encoding/json"
	"os"
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

func TestReceiptLimitsCoverFullBoundedSession(t *testing.T) {
	cfg := Default()
	if cfg.MaxReceiptActions != 120 || cfg.MaxReceiptDeltas != 1024 {
		t.Fatalf("receipt defaults cannot cover full session: actions=%d deltas=%d", cfg.MaxReceiptActions, cfg.MaxReceiptDeltas)
	}
	cfg.MaxReceiptActions = 121
	if cfg.Validate() == nil {
		t.Fatal("accepted action limit beyond protocol cap")
	}
}

func TestReceiptDefaultsMatchSharedSchema(t *testing.T) {
	body, err := os.ReadFile("../../../packages/psychemas/schema/receipt.schema.json")
	if err != nil {
		t.Fatal(err)
	}
	var contract struct {
		Properties map[string]struct {
			MaxItems int `json:"maxItems"`
		} `json:"properties"`
	}
	if err = json.Unmarshal(body, &contract); err != nil {
		t.Fatal(err)
	}
	cfg := Default()
	if contract.Properties["actions"].MaxItems != cfg.MaxReceiptActions || contract.Properties["deltas"].MaxItems != cfg.MaxReceiptDeltas {
		t.Fatal("Go receipt bounds drifted from shared wire schema")
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

func TestHTTPAdmissionConfigRejectsInvalidLimit(t *testing.T) {
	for _, value := range []string{"0", "-1", "4097"} {
		t.Run(value, func(t *testing.T) {
			t.Setenv("PSY_HTTP_MAX_IN_FLIGHT", value)
			if err := Default().Validate(); err == nil {
				t.Fatal("invalid admission cap accepted")
			}
		})
	}
}
