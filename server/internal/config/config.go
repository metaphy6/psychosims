// Package config is the server-side config authority.
//
// Values are resolved from validated environment variables and local files.
// Secrets are referenced by name, never embedded. Production custody
// (KMS/Vault resolution) is the 0.6 hardening pass; Phase 3 keeps the
// interface and resolves from the local dev environment.
package config

import (
	"fmt"
	"os"
	"strconv"
	"time"
)

// Config holds all server configuration in one validated struct.
type Config struct {
	ListenAddr string

	// Database configuration.
	DatabaseDSN     string
	DatabasePoolMax int
	DatabasePoolMin int
	MigrationsPath  string

	// Auth / tokens.
	AccessTokenTTL  time.Duration
	RefreshTokenTTL time.Duration
	GoogleClientID  string
	AppleClientID   string

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
		ListenAddr:               getenv("PSY_LISTEN_ADDR", "0.0.0.0:8080"),
		DatabaseDSN:              getenv("PSY_DATABASE_DSN", "postgres://postgres:postgres@localhost:5432/psychosims?sslmode=disable"),
		DatabasePoolMax:          getenvInt("PSY_DATABASE_POOL_MAX", 10),
		DatabasePoolMin:          getenvInt("PSY_DATABASE_POOL_MIN", 2),
		MigrationsPath:           getenv("PSY_MIGRATIONS_PATH", "internal/store/migrations"),
		AccessTokenTTL:           getenvDuration("PSY_ACCESS_TOKEN_TTL", 15*time.Minute),
		RefreshTokenTTL:          getenvDuration("PSY_REFRESH_TOKEN_TTL", 7*24*time.Hour),
		GoogleClientID:           getenv("PSY_GOOGLE_CLIENT_ID", ""),
		AppleClientID:            getenv("PSY_APPLE_CLIENT_ID", ""),
		MaxReceiptBodyBytes:      getenvInt64("PSY_MAX_RECEIPT_BODY_BYTES", 1<<20),
		MaxReceiptActions:        getenvInt("PSY_MAX_RECEIPT_ACTIONS", 64),
		MaxReceiptDeltas:         getenvInt("PSY_MAX_RECEIPT_DELTAS", 256),
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
	if c.DatabaseDSN == "" {
		return fmt.Errorf("database_dsn is required")
	}
	if c.DatabasePoolMax < c.DatabasePoolMin {
		return fmt.Errorf("database_pool_max (%d) must be >= database_pool_min (%d)", c.DatabasePoolMax, c.DatabasePoolMin)
	}
	if c.MaxReceiptBodyBytes <= 0 {
		return fmt.Errorf("max_receipt_body_bytes must be positive")
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
