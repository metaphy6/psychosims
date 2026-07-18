// Package ruleset implements the server-side ruleset_version registry, sunset
// schedule, and kill-switch extension for Phase 3.3.
package ruleset

import (
	"fmt"
	"sort"
	"time"
)

// Registry tracks known ruleset versions and their sunset windows.
type Registry struct {
	versions    map[string]VersionInfo
	sunsetExtra time.Duration
	killSwitch  bool
}

// VersionInfo describes a ruleset version.
type VersionInfo struct {
	Version    string
	ReleasedAt time.Time
	SunsetAt   *time.Time
}

// Config loads ruleset policy from server configuration.
type Config struct {
	KnownVersions   []string
	SunsetWindow    time.Duration
	KillSwitchAll   bool
}

// NewRegistry builds a registry from config.
func NewRegistry(cfg Config) *Registry {
	versions := make(map[string]VersionInfo, len(cfg.KnownVersions))
	now := time.Now().UTC()
	for _, v := range cfg.KnownVersions {
		versions[v] = VersionInfo{Version: v, ReleasedAt: now}
	}
	return &Registry{
		versions:    versions,
		sunsetExtra: cfg.SunsetWindow,
		killSwitch:  cfg.KillSwitchAll,
	}
}

// IsKnown reports whether a ruleset version is accepted.
func (r *Registry) IsKnown(version string) bool {
	_, ok := r.versions[version]
	return ok
}

// IsSunset reports whether a version is past its sunset window.
func (r *Registry) IsSunset(version string, now time.Time) bool {
	if r.killSwitch {
		return true
	}
	info, ok := r.versions[version]
	if !ok {
		return false
	}
	if info.SunsetAt != nil && now.After(*info.SunsetAt) {
		return true
	}
	return now.After(info.ReleasedAt.Add(r.sunsetExtra))
}

// KnownVersions returns the sorted list of registered versions.
func (r *Registry) KnownVersions() []string {
	out := make([]string, 0, len(r.versions))
	for v := range r.versions {
		out = append(out, v)
	}
	sort.Strings(out)
	return out
}

// SetKillSwitch enables or disables the global kill-switch.
func (r *Registry) SetKillSwitch(on bool) { r.killSwitch = on }

// Register adds a new version with an explicit optional sunset time.
func (r *Registry) Register(version string, releasedAt time.Time, sunsetAt *time.Time) error {
	if version == "" {
		return fmt.Errorf("version required")
	}
	r.versions[version] = VersionInfo{Version: version, ReleasedAt: releasedAt, SunsetAt: sunsetAt}
	return nil
}
