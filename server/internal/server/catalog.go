package server

import (
	"crypto/sha256"
	"encoding/hex"
	"encoding/json"
	"errors"
	"fmt"
	"io"
	"os"
	"sort"

	"psychosims.dev/server/internal/canonicaljson"
	"psychosims.dev/server/internal/outcomes"
	"psychosims.dev/server/internal/ownership"
	"psychosims.dev/server/internal/schemas"
)

// CatalogCase is a trusted operator-loaded case, not an HTTP request schema.
// Certified solver witnesses may later extend this entry; absent them rewards
// are always held. No client-selected axes, seed or payout enters this object.
type CatalogCase struct {
	ID               string
	ManifestChecksum string
	RulesetVersion   string
	MemoryClass      ownership.MemoryClass
	InitialAxes      map[string]int
	Controllers      schemas.TherapyControllerSettings
}
type Catalog struct {
	cases    map[string]CatalogCase
	outcomes *outcomes.Catalog
}

// WithOutcomes attaches an already operator-pinned, immutable certificate set.
// Call before composing the server. Case manifests remain separately verified.
func (c *Catalog) WithOutcomes(proofs *outcomes.Catalog) *Catalog {
	return &Catalog{cases: c.cases, outcomes: proofs}
}

func NewCatalog(cases []CatalogCase) (*Catalog, error) {
	c := &Catalog{cases: map[string]CatalogCase{}}
	for _, item := range cases {
		if item.ID == "" || len(item.ID) > 128 || item.RulesetVersion == "" || item.InitialAxes == nil {
			return nil, errors.New("invalid catalog case")
		}
		if _, exists := c.cases[item.ID]; exists {
			return nil, errors.New("duplicate catalog case")
		}
		if item.MemoryClass != ownership.MemoryClassPersistent && item.MemoryClass != ownership.MemoryClassStateless && item.MemoryClass != ownership.MemoryClassSocialChronic {
			return nil, errors.New("invalid catalog memory class")
		}
		axes := map[string]int{}
		for key, value := range item.InitialAxes {
			if value < 0 || value > 100 {
				return nil, errors.New("catalog initial axis outside bounds")
			}
			axes[key] = value
		}
		item.InitialAxes = axes
		c.cases[item.ID] = item
	}
	return c, nil
}
func (c *Catalog) rulesets() []string {
	set := map[string]bool{}
	for _, item := range c.cases {
		set[item.RulesetVersion] = true
	}
	out := []string{}
	for v := range set {
		out = append(out, v)
	}
	sort.Strings(out)
	return out
}

// LoadCatalog reads the existing content manifest format with its embedded
// checksum. Paths are explicit operator configuration, never caller input.
func LoadCatalog(paths []string) (*Catalog, error) {
	entries := []CatalogCase{}
	for _, path := range paths {
		f, err := os.Open(path)
		if err != nil {
			return nil, fmt.Errorf("open catalog manifest: %w", err)
		}
		body, readErr := io.ReadAll(io.LimitReader(f, 1<<20+1))
		f.Close()
		if readErr != nil || len(body) > 1<<20 {
			return nil, errors.New("catalog manifest exceeds bounds")
		}
		var raw map[string]any
		if json.Unmarshal(body, &raw) != nil {
			return nil, errors.New("invalid catalog manifest JSON")
		}
		checksum, ok := raw["content_checksum"].(string)
		if !ok {
			return nil, errors.New("catalog checksum required")
		}
		raw["content_checksum"] = ""
		canonical, err := canonicaljson.Marshal(raw)
		if err != nil {
			return nil, err
		}
		digest := sha256.Sum256(canonical)
		if checksum != "sha256:"+hex.EncodeToString(digest[:]) {
			return nil, errors.New("catalog checksum mismatch")
		}
		var manifest struct {
			ID          string                `json:"id"`
			Schema      string                `json:"schema_version"`
			Ruleset     string                `json:"ruleset_version"`
			MemoryClass ownership.MemoryClass `json:"memory_class"`
			Initial     map[string]int        `json:"initial_state"`
		}
		if json.Unmarshal(body, &manifest) != nil || manifest.Schema != "1.0.0" {
			return nil, errors.New("unsupported catalog manifest")
		}
		axes := map[string]int{}
		for k, v := range manifest.Initial {
			axes[k] = v
		}
		entries = append(entries, CatalogCase{ID: manifest.ID, ManifestChecksum: checksum, RulesetVersion: manifest.Ruleset, MemoryClass: manifest.MemoryClass, InitialAxes: axes, Controllers: schemas.TherapyControllerSettings{Focus: schemas.FocusBalanced, EmotionalDelivery: schemas.DeliveryBalanced}})
	}
	return NewCatalog(entries)
}
