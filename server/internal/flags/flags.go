// Package flags implements server-side feature flags and kill-switches loaded
// from the config authority (Phase 3.7).
package flags

import "psychosims.dev/server/internal/config"

// Flags wraps config booleans with named accessors.
type Flags struct {
	cfg *config.Config
}

// New builds the flag surface from config.
func New(cfg *config.Config) *Flags {
	return &Flags{cfg: cfg}
}

// ReceiptValidationEnabled returns true unless the receipt-validation kill-switch is off.
func (f *Flags) ReceiptValidationEnabled() bool { return f.cfg.ReceiptValidationEnabled }

// MatchmakingEnabled returns the matchmaking toggle.
func (f *Flags) MatchmakingEnabled() bool { return f.cfg.MatchmakingEnabled }

// EconomyEnabled returns the economy toggle.
func (f *Flags) EconomyEnabled() bool { return f.cfg.EconomyEnabled }
