package flags

import (
	"testing"

	"psychosims.dev/server/internal/config"
)

func TestFlags(t *testing.T) {
	cfg := config.Default()
	cfg.ReceiptValidationEnabled = true
	cfg.MatchmakingEnabled = false
	cfg.EconomyEnabled = true

	f := New(cfg)
	if !f.ReceiptValidationEnabled() {
		t.Error("expected receipt validation enabled")
	}
	if f.MatchmakingEnabled() {
		t.Error("expected matchmaking disabled")
	}
	if !f.EconomyEnabled() {
		t.Error("expected economy enabled")
	}
}
