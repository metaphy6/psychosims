package main

import (
	"context"
	"psychosims.dev/server/internal/config"
	"testing"
)

func TestRunRejectsMissingSigningSecretBeforeConnecting(t *testing.T) {
	cfg := config.Default()
	cfg.TokenSecretFile = ""
	cfg.DatabaseDSN = "postgres://invalid-unreachable.example/unused"
	if err := run(context.Background(), cfg); err == nil {
		t.Fatal("incomplete executable configuration accepted")
	}
}
