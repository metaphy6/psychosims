package config

import (
	"fmt"
	"strings"
	"time"
)

// CureRewardPolicy is the initial bounded, base-tier certified reward policy.
// XP/study defaults follow ProgressionConfig. Cash stays zero until priced cases
// are integrated. The rolling-window/cooldown controls are explicit local
// engineering defaults, not a claim of a tuned full economy.
type CureRewardPolicy struct {
	XP                int
	Study             int
	CashMicros        int64
	MaxCuresPerWindow int
	XPPerWindow       int
	StudyPerWindow    int
	CashPerWindow     int64
	Window            time.Duration
	MinimumInterval   time.Duration
}

func defaultCureRewards() CureRewardPolicy {
	return CureRewardPolicy{
		XP: getenvInt("PSY_CURE_XP", 100), Study: getenvInt("PSY_CURE_STUDY", 3), CashMicros: getenvInt64("PSY_CURE_CASH_MICROS", 0),
		MaxCuresPerWindow: getenvInt("PSY_CURE_MAX_PER_WINDOW", 5), XPPerWindow: getenvInt("PSY_CURE_XP_PER_WINDOW", 500), StudyPerWindow: getenvInt("PSY_CURE_STUDY_PER_WINDOW", 15), CashPerWindow: getenvInt64("PSY_CURE_CASH_PER_WINDOW", 0),
		Window: getenvDuration("PSY_CURE_WINDOW", 24*time.Hour), MinimumInterval: getenvDuration("PSY_CURE_MINIMUM_INTERVAL", time.Minute),
	}
}
func (p CureRewardPolicy) Validate() error {
	if p.XP < 0 || p.XP > 10000 || p.Study < 0 || p.Study > 1000 || p.CashMicros < 0 || p.CashMicros > 1_000_000_000 || p.MaxCuresPerWindow < 1 || p.MaxCuresPerWindow > 1000 || p.XPPerWindow < 0 || p.XPPerWindow > 1_000_000 || p.StudyPerWindow < 0 || p.StudyPerWindow > 100000 || p.CashPerWindow < 0 || p.CashPerWindow > 1_000_000_000_000 || p.Window < time.Minute || p.Window > 30*24*time.Hour || p.MinimumInterval < time.Second || p.MinimumInterval > p.Window {
		return fmt.Errorf("certified cure reward policy outside bounds")
	}
	return nil
}
func (c *Config) validateOutcomes() error {
	if (c.OutcomeCatalogPath == "") != (c.OutcomeCatalogSHA256 == "") || len(c.OutcomeCatalogPath) > 4096 || (c.OutcomeCatalogSHA256 != "" && !validSHA256(c.OutcomeCatalogSHA256)) {
		return fmt.Errorf("outcome catalog requires explicit path and exact SHA256 pin")
	}
	if len(c.OutcomeRevokedProofIDs) > 4096 {
		return fmt.Errorf("too many outcome proof revocations")
	}
	for _, id := range c.OutcomeRevokedProofIDs {
		if !validSHA256(id) {
			return fmt.Errorf("invalid outcome proof revocation")
		}
	}
	return c.CureRewards.Validate()
}
func validSHA256(s string) bool {
	if len(s) != 64 {
		return false
	}
	for _, c := range s {
		if !((c >= '0' && c <= '9') || (c >= 'a' && c <= 'f')) {
			return false
		}
	}
	return true
}
func nonemptyCSV(raw string) []string {
	if raw == "" {
		return nil
	}
	return strings.Split(raw, ",")
}
