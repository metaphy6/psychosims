// Package config is the server-side config authority.
//
// Values are resolved from validated environment variables and local files.
// Secrets are referenced by name, never embedded. Production custody
// (KMS/Vault resolution) is the 0.6 hardening pass; Phase 3 keeps the
// interface and resolves from the local dev environment.
package config

import (
	"fmt"
	"net"
	"net/url"
	"os"
	"strconv"
	"strings"
	"time"

	"psychosims.dev/server/internal/schemas"
)

// Config holds all server configuration in one validated struct.
type Config struct {
	ListenAddr      string
	HTTPMaxInFlight int

	// Database configuration.
	DatabaseDSN     string
	DatabasePoolMax int
	DatabasePoolMin int
	MigrationsPath  string

	// Auth / tokens.
	AccessTokenTTL         time.Duration
	RefreshTokenTTL        time.Duration
	GoogleClientID         string
	AppleClientID          string
	TokenSecretFile        string
	GoogleClientSecretFile string
	AppleClientSecretFile  string
	CatalogManifestPaths   []string
	OAuthRedirects         map[string]string
	OutcomeCatalogPath     string
	OutcomeCatalogSHA256   string
	OutcomeRevokedProofIDs []string
	CureRewards            CureRewardPolicy

	// Receipt validation.
	MaxReceiptBodyBytes    int64
	MaxReceiptActions      int
	MaxReceiptDeltas       int
	MaxReceiptLedgerEvents int
	MaxJSONDepth           int
	MaxStringFieldBytes    int
	RulesetSunsetWindow    time.Duration

	// Rate limiting.
	RateLimitPreAuthPerIP   int
	RateLimitAuthPerAccount int
	RateLimitWindow         time.Duration

	// Feature flags / kill switches.
	ReceiptValidationEnabled bool
	MatchmakingEnabled       bool
	EconomyEnabled           bool

	// Logging.
	LogLevel string
	LogMode  string
}

// Default returns a dev-local config with sensible defaults.
func Default() *Config {
	return &Config{
		HTTPMaxInFlight:          getenvInt("PSY_HTTP_MAX_IN_FLIGHT", 64),
		ListenAddr:               getenv("PSY_LISTEN_ADDR", "127.0.0.1:8080"),
		DatabaseDSN:              getenv("PSY_DATABASE_DSN", "postgres://postgres:postgres@localhost:5432/psychosims?sslmode=disable"),
		DatabasePoolMax:          getenvInt("PSY_DATABASE_POOL_MAX", 10),
		DatabasePoolMin:          getenvInt("PSY_DATABASE_POOL_MIN", 2),
		MigrationsPath:           getenv("PSY_MIGRATIONS_PATH", "internal/store/migrations"),
		AccessTokenTTL:           getenvDuration("PSY_ACCESS_TOKEN_TTL", 15*time.Minute),
		RefreshTokenTTL:          getenvDuration("PSY_REFRESH_TOKEN_TTL", 7*24*time.Hour),
		GoogleClientID:           getenv("PSY_GOOGLE_CLIENT_ID", ""),
		AppleClientID:            getenv("PSY_APPLE_CLIENT_ID", ""),
		TokenSecretFile:          getenv("PSY_TOKEN_SECRET_FILE", ""),
		GoogleClientSecretFile:   getenv("PSY_GOOGLE_CLIENT_SECRET_FILE", ""),
		AppleClientSecretFile:    getenv("PSY_APPLE_CLIENT_SECRET_FILE", ""),
		CatalogManifestPaths:     strings.Split(getenv("PSY_CATALOG_MANIFESTS", "../content/manifests/siege_brumosis.json"), ","),
		OAuthRedirects:           map[string]string{"steam": getenv("PSY_OAUTH_STEAM_REDIRECT_URI", ""), "direct_download": getenv("PSY_OAUTH_DIRECT_REDIRECT_URI", "")},
		OutcomeCatalogPath:       getenv("PSY_OUTCOME_CATALOG_PATH", ""),
		OutcomeCatalogSHA256:     getenv("PSY_OUTCOME_CATALOG_SHA256", ""),
		OutcomeRevokedProofIDs:   nonemptyCSV(getenv("PSY_OUTCOME_REVOKED_PROOFS", "")),
		CureRewards:              defaultCureRewards(),
		MaxReceiptBodyBytes:      getenvInt64("PSY_MAX_RECEIPT_BODY_BYTES", 1<<20),
		MaxReceiptActions:        getenvInt("PSY_MAX_RECEIPT_ACTIONS", schemas.MaxReceiptActions),
		MaxReceiptDeltas:         getenvInt("PSY_MAX_RECEIPT_DELTAS", schemas.MaxReceiptDeltas),
		MaxReceiptLedgerEvents:   getenvInt("PSY_MAX_RECEIPT_LEDGER_EVENTS", 64),
		MaxJSONDepth:             getenvInt("PSY_MAX_JSON_DEPTH", 32),
		MaxStringFieldBytes:      getenvInt("PSY_MAX_STRING_FIELD_BYTES", 1024),
		RulesetSunsetWindow:      getenvDuration("PSY_RULESET_SUNSET_WINDOW", 30*24*time.Hour),
		RateLimitPreAuthPerIP:    getenvInt("PSY_RATE_LIMIT_PRE_AUTH_PER_IP", 20),
		RateLimitAuthPerAccount:  getenvInt("PSY_RATE_LIMIT_AUTH_PER_ACCOUNT", 100),
		RateLimitWindow:          getenvDuration("PSY_RATE_LIMIT_WINDOW", time.Minute),
		ReceiptValidationEnabled: getenvBool("PSY_RECEIPT_VALIDATION_ENABLED", true),
		MatchmakingEnabled:       getenvBool("PSY_MATCHMAKING_ENABLED", false),
		EconomyEnabled:           getenvBool("PSY_ECONOMY_ENABLED", true),
		LogLevel:                 getenv("PSY_LOG_LEVEL", "info"),
		LogMode:                  getenv("PSY_LOG_MODE", "text"),
	}
}

// Validate checks required fields and invariants.
func (c *Config) Validate() error {
	if c.ListenAddr == "" {
		return fmt.Errorf("listen_addr is required")
	}
	if c.HTTPMaxInFlight < 1 || c.HTTPMaxInFlight > 4096 {
		return fmt.Errorf("http_max_in_flight must be between 1 and 4096")
	}
	if c.DatabaseDSN == "" {
		return fmt.Errorf("database_dsn is required")
	}
	if c.DatabasePoolMax < c.DatabasePoolMin {
		return fmt.Errorf("database_pool_max (%d) must be >= database_pool_min (%d)", c.DatabasePoolMax, c.DatabasePoolMin)
	}
	if c.MaxReceiptBodyBytes <= 0 {
		return fmt.Errorf("max_receipt_body_bytes must be positive")
	}
	if c.MaxReceiptActions < 1 || c.MaxReceiptActions > schemas.MaxReceiptActions || c.MaxReceiptDeltas < 1 || c.MaxReceiptDeltas > schemas.MaxReceiptDeltas {
		return fmt.Errorf("receipt count limits outside protocol bounds")
	}
	return c.validateOutcomes()
}

// ValidateRuntime adds executable-only requirements; isolated component tests
// may still use Validate without identity-provider credentials.
func (c *Config) ValidateRuntime() error {
	if err := c.Validate(); err != nil {
		return err
	}
	if c.TokenSecretFile == "" {
		return fmt.Errorf("PSY_TOKEN_SECRET_FILE is required")
	}
	if c.GoogleClientID == "" && c.AppleClientID == "" {
		return fmt.Errorf("at least one identity provider client ID is required")
	}
	if c.AccessTokenTTL < time.Second || c.AccessTokenTTL > time.Hour || c.RefreshTokenTTL < c.AccessTokenTTL || c.RefreshTokenTTL > 30*24*time.Hour {
		return fmt.Errorf("invalid token expiry configuration")
	}
	if c.DatabasePoolMin < 0 || c.DatabasePoolMax < 1 || c.MaxReceiptBodyBytes > 4<<20 || c.MaxReceiptLedgerEvents < 0 || c.MaxReceiptLedgerEvents > 256 || c.RateLimitPreAuthPerIP < 1 || c.RateLimitAuthPerAccount < 1 || c.RateLimitWindow <= 0 || len(c.CatalogManifestPaths) == 0 {
		return fmt.Errorf("runtime limits outside bounds")
	}
	for _, raw := range c.OAuthRedirects {
		if raw == "" {
			continue
		}
		u, err := url.Parse(raw)
		if err != nil || u.User != nil || u.Fragment != "" || u.Host == "" {
			return fmt.Errorf("invalid registered OAuth redirect")
		}
		if u.Scheme != "https" {
			ip := net.ParseIP(u.Hostname())
			if u.Scheme != "http" || ip == nil || !ip.IsLoopback() {
				return fmt.Errorf("OAuth redirect requires HTTPS or literal loopback")
			}
		}
	}
	for _, key := range []string{"PSY_ACCESS_TOKEN_TTL", "PSY_REFRESH_TOKEN_TTL", "PSY_RATE_LIMIT_WINDOW", "PSY_RULESET_SUNSET_WINDOW", "PSY_CURE_WINDOW", "PSY_CURE_MINIMUM_INTERVAL"} {
		if raw := os.Getenv(key); raw != "" {
			if _, err := time.ParseDuration(raw); err != nil {
				return fmt.Errorf("invalid duration in %s", key)
			}
		}
	}
	for _, key := range []string{"PSY_HTTP_MAX_IN_FLIGHT", "PSY_DATABASE_POOL_MIN", "PSY_DATABASE_POOL_MAX", "PSY_MAX_RECEIPT_BODY_BYTES", "PSY_MAX_RECEIPT_ACTIONS", "PSY_MAX_RECEIPT_DELTAS", "PSY_MAX_RECEIPT_LEDGER_EVENTS", "PSY_MAX_JSON_DEPTH", "PSY_MAX_STRING_FIELD_BYTES", "PSY_RATE_LIMIT_PRE_AUTH_PER_IP", "PSY_RATE_LIMIT_AUTH_PER_ACCOUNT", "PSY_CURE_XP", "PSY_CURE_STUDY", "PSY_CURE_CASH_MICROS", "PSY_CURE_MAX_PER_WINDOW", "PSY_CURE_XP_PER_WINDOW", "PSY_CURE_STUDY_PER_WINDOW", "PSY_CURE_CASH_PER_WINDOW"} {
		if raw := os.Getenv(key); raw != "" {
			if _, err := strconv.ParseInt(raw, 10, 64); err != nil {
				return fmt.Errorf("invalid integer in %s", key)
			}
		}
	}
	for _, key := range []string{"PSY_RECEIPT_VALIDATION_ENABLED", "PSY_MATCHMAKING_ENABLED", "PSY_ECONOMY_ENABLED"} {
		if raw := os.Getenv(key); raw != "" {
			if _, err := strconv.ParseBool(raw); err != nil {
				return fmt.Errorf("invalid boolean in %s", key)
			}
		}
	}
	return nil
}

func getenv(key, fallback string) string {
	if v, ok := os.LookupEnv(key); ok && v != "" {
		return v
	}
	return fallback
}

func getenvInt(key string, fallback int) int {
	v := getenv(key, "")
	if v == "" {
		return fallback
	}
	n, err := strconv.Atoi(v)
	if err != nil {
		return fallback
	}
	return n
}

func getenvInt64(key string, fallback int64) int64 {
	v := getenv(key, "")
	if v == "" {
		return fallback
	}
	n, err := strconv.ParseInt(v, 10, 64)
	if err != nil {
		return fallback
	}
	return n
}

func getenvDuration(key string, fallback time.Duration) time.Duration {
	v := getenv(key, "")
	if v == "" {
		return fallback
	}
	d, err := time.ParseDuration(v)
	if err != nil {
		return fallback
	}
	return d
}

func getenvBool(key string, fallback bool) bool {
	v := getenv(key, "")
	if v == "" {
		return fallback
	}
	b, err := strconv.ParseBool(v)
	if err != nil {
		return fallback
	}
	return b
}
