// Package store is the persistence boundary for all authoritative server state.
//
// It provides connection pooling, ordered schema migrations, and a transactional
// primitive so profile/ledger/ownership/audit mutations commit atomically.
// Phase 3 targets a managed Postgres-compatible store (ADR-0007).
package store

import (
	"context"
	"database/sql"
	"fmt"
	"sort"
	"time"

	_ "github.com/lib/pq"

	"psychosims.dev/server/internal/config"
)

// Migration is an ordered, reviewable schema change step.
type Migration struct {
	Version     int
	Description string
	Up          string
	Down        string
}

// Store is the authoritative persistence handle.
type Store struct {
	db  *sql.DB
	cfg *config.Config
}

// New opens the configured database, runs migrations, and warms the pool.
func New(ctx context.Context, cfg *config.Config) (*Store, error) {
	db, err := sql.Open("postgres", cfg.DatabaseDSN)
	if err != nil {
		return nil, fmt.Errorf("open database: %w", err)
	}

	db.SetMaxOpenConns(cfg.DatabasePoolMax)
	db.SetMaxIdleConns(cfg.DatabasePoolMin)
	db.SetConnMaxLifetime(30 * time.Minute)

	if err := db.PingContext(ctx); err != nil {
		_ = db.Close()
		return nil, fmt.Errorf("ping database: %w", err)
	}

	s := &Store{db: db, cfg: cfg}
	if err := s.ensureMigrationsTable(ctx); err != nil {
		_ = db.Close()
		return nil, fmt.Errorf("ensure migrations table: %w", err)
	}
	if err := s.MigrateUp(ctx); err != nil {
		_ = db.Close()
		return nil, fmt.Errorf("migrate up: %w", err)
	}

	return s, nil
}

// Close closes the connection pool.
func (s *Store) Close() error { return s.db.Close() }

// DB exposes the underlying pool for repositories.
func (s *Store) DB() *sql.DB { return s.db }

// Ping reports whether the store is reachable.
func (s *Store) Ping(ctx context.Context) error { return s.db.PingContext(ctx) }

// Tx runs fn inside a single SQL transaction.
func (s *Store) Tx(ctx context.Context, fn func(*sql.Tx) error) error {
	tx, err := s.db.BeginTx(ctx, nil)
	if err != nil {
		return fmt.Errorf("begin tx: %w", err)
	}
	if err := fn(tx); err != nil {
		if rbErr := tx.Rollback(); rbErr != nil {
			return fmt.Errorf("rollback failed after error (%v): %w", err, rbErr)
		}
		return err
	}
	if err := tx.Commit(); err != nil {
		return fmt.Errorf("commit tx: %w", err)
	}
	return nil
}

// ensureMigrationsTable creates the migration bookkeeping table.
func (s *Store) ensureMigrationsTable(ctx context.Context) error {
	_, err := s.db.ExecContext(ctx, `
		CREATE TABLE IF NOT EXISTS schema_migrations (
			version INTEGER PRIMARY KEY,
			applied_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
		)
	`)
	return err
}

// CurrentSchemaVersion returns the highest applied migration version.
func (s *Store) CurrentSchemaVersion(ctx context.Context) (int, error) {
	var version sql.NullInt64
	row := s.db.QueryRowContext(ctx, `SELECT COALESCE(MAX(version), 0) FROM schema_migrations`)
	if err := row.Scan(&version); err != nil {
		return 0, err
	}
	return int(version.Int64), nil
}

// MigrateUp applies all pending migrations in version order.
func (s *Store) MigrateUp(ctx context.Context) error {
	migs := Migrations()
	sort.Slice(migs, func(i, j int) bool { return migs[i].Version < migs[j].Version })

	current, err := s.CurrentSchemaVersion(ctx)
	if err != nil {
		return err
	}

	for _, m := range migs {
		if m.Version <= current {
			continue
		}
		if _, err := s.db.ExecContext(ctx, m.Up); err != nil {
			return fmt.Errorf("migration %d (%s) up failed: %w", m.Version, m.Description, err)
		}
		if _, err := s.db.ExecContext(ctx, `INSERT INTO schema_migrations (version) VALUES ($1)`, m.Version); err != nil {
			return fmt.Errorf("record migration %d: %w", m.Version, err)
		}
		current = m.Version
	}
	return nil
}

// MigrateDown rolls back migrations to targetVersion.
func (s *Store) MigrateDown(ctx context.Context, targetVersion int) error {
	migs := Migrations()
	sort.Slice(migs, func(i, j int) bool { return migs[i].Version > migs[j].Version })

	current, err := s.CurrentSchemaVersion(ctx)
	if err != nil {
		return err
	}

	for _, m := range migs {
		if m.Version > current || m.Version <= targetVersion {
			continue
		}
		if m.Down == "" {
			return fmt.Errorf("migration %d has no rollback", m.Version)
		}
		if _, err := s.db.ExecContext(ctx, m.Down); err != nil {
			return fmt.Errorf("migration %d (%s) down failed: %w", m.Version, m.Description, err)
		}
		if _, err := s.db.ExecContext(ctx, `DELETE FROM schema_migrations WHERE version = $1`, m.Version); err != nil {
			return fmt.Errorf("unrecord migration %d: %w", m.Version, err)
		}
	}
	return nil
}
