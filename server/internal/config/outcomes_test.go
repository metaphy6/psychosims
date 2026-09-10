package config

import (
	"strings"
	"testing"
)

func TestOutcomeCatalogRequiresPinAndBoundedRewardPolicy(t *testing.T) {
	for name, mutate := range map[string]func(*Config){
		"path without pin":      func(c *Config) { c.OutcomeCatalogPath = "catalog.json" },
		"pin without path":      func(c *Config) { c.OutcomeCatalogSHA256 = strings.Repeat("0", 64) },
		"invalid pin":           func(c *Config) { c.OutcomeCatalogPath = "catalog.json"; c.OutcomeCatalogSHA256 = "wrong" },
		"invalid revocation":    func(c *Config) { c.OutcomeRevokedProofIDs = []string{"wrong"} },
		"negative xp":           func(c *Config) { c.CureRewards.XP = -1 },
		"unbounded xp":          func(c *Config) { c.CureRewards.XP = 10001 },
		"zero window":           func(c *Config) { c.CureRewards.Window = 0 },
		"unbounded daily cures": func(c *Config) { c.CureRewards.MaxCuresPerWindow = 1001 },
		"zero cooldown":         func(c *Config) { c.CureRewards.MinimumInterval = 0 },
	} {
		t.Run(name, func(t *testing.T) {
			c := Default()
			mutate(c)
			if err := c.Validate(); err == nil {
				t.Fatal("invalid outcome configuration accepted")
			}
		})
	}
	c := Default()
	if c.OutcomeCatalogPath != "" || c.OutcomeCatalogSHA256 != "" {
		t.Fatal("unconfigured catalog enabled by default")
	}
	c.OutcomeCatalogPath = "catalog.json"
	c.OutcomeCatalogSHA256 = strings.Repeat("0", 64)
	if err := c.Validate(); err != nil {
		t.Fatal(err)
	}
}

func TestOutcomeConfigurationReadsExplicitValues(t *testing.T) {
	t.Setenv("PSY_OUTCOME_CATALOG_PATH", "reviewed.json")
	t.Setenv("PSY_OUTCOME_CATALOG_SHA256", strings.Repeat("a", 64))
	t.Setenv("PSY_OUTCOME_REVOKED_PROOFS", strings.Repeat("b", 64)+","+strings.Repeat("c", 64))
	t.Setenv("PSY_CURE_XP", "200")
	c := Default()
	if c.OutcomeCatalogPath != "reviewed.json" || c.OutcomeCatalogSHA256 != strings.Repeat("a", 64) || len(c.OutcomeRevokedProofIDs) != 2 || c.CureRewards.XP != 200 {
		t.Fatal("operator configuration not resolved")
	}
	if err := c.Validate(); err != nil {
		t.Fatal(err)
	}
}
