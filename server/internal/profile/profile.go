// Package profile implements the authoritative primitive profile store and
// economy ledger for Phase 3.2.
package profile

import (
	"context"
	"database/sql"
	"encoding/json"
	"errors"
	"sync"
	"time"

	"psychosims.dev/server/internal/api"
	"psychosims.dev/server/internal/schemas"
	"psychosims.dev/server/internal/timeutil"
)

// PrimitiveProfile is the <0.5 KB atomic player snapshot.
type PrimitiveProfile struct {
	OwnedCardIDs       []string  `json:"owned_card_ids"`
	AccountID          string    `json:"account_id"`
	Version            int       `json:"version"`
	Level              int       `json:"level"`
	XP                 int       `json:"xp"`
	StudyPoints        int       `json:"study_points"`
	SubspecialtyPoints int       `json:"subspecialty_points"`
	Reputation         int       `json:"reputation"`
	Prestige           int       `json:"prestige"`
	CashMicros         int64     `json:"cash_micros"`
	ClinicTier         int       `json:"clinic_tier"`
	OnboardingDone     bool      `json:"onboarding_done"`
	UpdatedAt          time.Time `json:"updated_at"`
}

// Repository persists primitive profiles.
type Repository interface {
	Get(ctx context.Context, accountID string) (*PrimitiveProfile, error)
	Update(ctx context.Context, profile *PrimitiveProfile) error
	Erase(ctx context.Context, accountID string) error
}

// SQLRepository is the Postgres-backed profile store.
type SQLRepository struct {
	db *sql.DB
	tx *sql.Tx
}

type queryer interface {
	QueryRowContext(context.Context, string, ...any) *sql.Row
	ExecContext(context.Context, string, ...any) (sql.Result, error)
}

// NewSQLRepositoryTx binds every profile read/write to the receipt transaction.
func NewSQLRepositoryTx(tx *sql.Tx) *SQLRepository { return &SQLRepository{tx: tx} }
func (r *SQLRepository) queryer() queryer {
	if r.tx != nil {
		return r.tx
	}
	return r.db
}

// NewSQLRepository creates a new SQL profile repository.
func NewSQLRepository(db *sql.DB) *SQLRepository {
	return &SQLRepository{db: db}
}

// Get implements Repository.
func (r *SQLRepository) Get(ctx context.Context, accountID string) (*PrimitiveProfile, error) {
	query := `SELECT version, payload, updated_at FROM profiles WHERE account_id = $1`
	if r.tx != nil {
		query += ` FOR UPDATE`
	}
	row := r.queryer().QueryRowContext(ctx, query, accountID)
	var version int
	var payload []byte
	var updatedAt time.Time
	if err := row.Scan(&version, &payload, &updatedAt); err != nil {
		if err == sql.ErrNoRows {
			return nil, api.NewNotFound("profile not found")
		}
		return nil, err
	}
	var p PrimitiveProfile
	if err := json.Unmarshal(payload, &p); err != nil {
		return nil, err
	}
	p.AccountID = accountID
	p.Version = version
	p.UpdatedAt = updatedAt
	return &p, nil
}

// Erase removes account-linked PII from the profile while leaving the account
// and its ledger events in place. The ledger stays conservation-valid because
// only the mutable snapshot is zeroed; no events are deleted.
func (r *SQLRepository) Erase(ctx context.Context, accountID string) error {
	empty := &PrimitiveProfile{AccountID: accountID, Version: 1, UpdatedAt: time.Now().UTC()}
	payload, err := json.Marshal(empty)
	if err != nil {
		return err
	}
	_, err = r.db.ExecContext(ctx, `
		INSERT INTO profiles (account_id, version, payload, updated_at)
		VALUES ($1, 1, $2, NOW())
		ON CONFLICT (account_id) DO UPDATE SET
			version = EXCLUDED.version,
			payload = EXCLUDED.payload,
			updated_at = EXCLUDED.updated_at
	`, accountID, payload)
	return err
}

// Update creates version-zero profiles and optimistically updates existing snapshots.
// The caller's version changes only after a successful write.
func (r *SQLRepository) Update(ctx context.Context, p *PrimitiveProfile) error {
	if p.AccountID == "" {
		return api.NewUnauthorized("account id required")
	}
	if p.Version == 0 && r.tx == nil {
		tx, err := r.db.BeginTx(ctx, nil)
		if err != nil {
			return err
		}
		defer tx.Rollback()
		copy := *p
		if err := NewSQLRepositoryTx(tx).Update(ctx, &copy); err != nil {
			return err
		}
		if err := tx.Commit(); err != nil {
			return err
		}
		*p = copy
		return nil
	}
	next := *p
	next.Version++
	next.UpdatedAt = time.Now().UTC()
	payload, err := json.Marshal(&next)
	if err != nil {
		return err
	}
	q := r.queryer()
	var res sql.Result
	if p.Version == 0 {
		if _, err := q.ExecContext(ctx, `INSERT INTO accounts(id) VALUES($1) ON CONFLICT DO NOTHING`, p.AccountID); err != nil {
			return err
		}
		res, err = q.ExecContext(ctx, `INSERT INTO profiles(account_id,version,payload,updated_at) VALUES($1,1,$2,$3) ON CONFLICT DO NOTHING`, p.AccountID, payload, next.UpdatedAt)
	} else {
		res, err = q.ExecContext(ctx, `UPDATE profiles SET version=$1,payload=$2,updated_at=$3 WHERE account_id=$4 AND version=$5`, next.Version, payload, next.UpdatedAt, p.AccountID, p.Version)
	}
	if err != nil {
		return err
	}
	n, err := res.RowsAffected()
	if err != nil {
		return err
	}
	if n != 1 {
		return api.NewConflict(api.CodeConflict, "profile version conflict")
	}
	*p = next
	return nil
}

// Ledger is the authoritative append-only economy event log.
type Ledger struct {
	db    *sql.DB
	clock timeutil.Clock
}

// NewLedger creates a ledger service using the real clock.
func NewLedger(db *sql.DB) *Ledger {
	return NewLedgerWithClock(db, timeutil.RealClock{})
}

// NewLedgerWithClock creates a ledger service with an injected clock.
func NewLedgerWithClock(db *sql.DB, clock timeutil.Clock) *Ledger {
	return &Ledger{db: db, clock: clock}
}

// Append ingests ledger events idempotently inside a transaction using the
// server's authoritative clock. The client-provided timestamp is recorded only
// as a non-authoritative hint; ordering, cadence, and TTLs use server_time.
func (l *Ledger) Append(ctx context.Context, tx *sql.Tx, accountID string, events []schemas.LedgerEvent) error {
	serverTime := l.clock.Now().UTC()
	for _, ev := range events {
		if ev.IdempotencyKey == "" {
			return api.NewUserError(api.CodeBadRequest, "ledger event missing idempotency key")
		}
		_, err := tx.ExecContext(ctx, `
			INSERT INTO ledger_events (account_id, idempotency_key, kind, currency, amount_micros, reason_key, server_time)
			VALUES ($1, $2, $3, $4, $5, $6, $7)
			ON CONFLICT (account_id, idempotency_key) DO NOTHING
		`, accountID, ev.IdempotencyKey, ev.Kind, ev.Currency, ev.AmountMicros, ev.ReasonKey, serverTime)
		if err != nil {
			return err
		}
	}
	return nil
}

// Balance returns the sum of all ledger events per currency. Production would
// use snapshot rows; this is the reference replay.
func (l *Ledger) Balance(ctx context.Context, accountID string) (map[string]int64, error) {
	rows, err := l.db.QueryContext(ctx, `
		SELECT currency, COALESCE(SUM(amount_micros), 0)
		FROM ledger_events
		WHERE account_id = $1
		GROUP BY currency
	`, accountID)
	if err != nil {
		return nil, err
	}
	defer rows.Close()

	balances := make(map[string]int64)
	for rows.Next() {
		var currency string
		var amount int64
		if err := rows.Scan(&currency, &amount); err != nil {
			return nil, err
		}
		balances[currency] = amount
	}
	return balances, rows.Err()
}

// InMemoryLedger is a test ledger that records events using an authoritative
// clock so ordering is independent of any client timestamp.
type InMemoryLedger struct {
	events []schemas.LedgerEvent
	clock  timeutil.Clock
}

// NewInMemoryLedger creates a test ledger.
func NewInMemoryLedger(clock timeutil.Clock) *InMemoryLedger {
	return &InMemoryLedger{clock: clock}
}

// Append records events with the server clock.
func (l *InMemoryLedger) Append(ctx context.Context, tx *sql.Tx, accountID string, events []schemas.LedgerEvent) error {
	for _, ev := range events {
		if ev.IdempotencyKey == "" {
			return api.NewUserError(api.CodeBadRequest, "ledger event missing idempotency key")
		}
		evCopy := ev
		evCopy.TimestampSeconds = int(l.clock.Now().Unix())
		l.events = append(l.events, evCopy)
	}
	return nil
}

// Events returns recorded events.
func (l *InMemoryLedger) Events() []schemas.LedgerEvent {
	return append([]schemas.LedgerEvent(nil), l.events...)
}

// SnapshotRepository manages ledger compaction checkpoints.
type SnapshotRepository struct {
	db *sql.DB
}

// NewSnapshotRepository creates a snapshot repository.
func NewSnapshotRepository(db *sql.DB) *SnapshotRepository {
	return &SnapshotRepository{db: db}
}

// Save writes a snapshot. Used for compaction / bounded replay.
func (r *SnapshotRepository) Save(ctx context.Context, accountID string, version int, balances map[string]int64) error {
	payload, err := json.Marshal(balances)
	if err != nil {
		return err
	}
	_, err = r.db.ExecContext(ctx, `
		INSERT INTO ledger_snapshots (account_id, version, balances)
		VALUES ($1, $2, $3)
		ON CONFLICT (account_id) DO UPDATE SET version = EXCLUDED.version, balances = EXCLUDED.balances, snapshot_time = NOW()
	`, accountID, version, payload)
	return err
}

// InMemoryProfileRepository is a test implementation.
type InMemoryProfileRepository struct {
	mu       sync.Mutex
	profiles map[string]*PrimitiveProfile
}

// NewInMemoryProfileRepository creates a test repository.
func NewInMemoryProfileRepository() *InMemoryProfileRepository {
	return &InMemoryProfileRepository{profiles: make(map[string]*PrimitiveProfile)}
}

// Get implements Repository.
func (r *InMemoryProfileRepository) Get(ctx context.Context, accountID string) (*PrimitiveProfile, error) {
	r.mu.Lock()
	defer r.mu.Unlock()
	p, ok := r.profiles[accountID]
	if !ok {
		return nil, api.NewNotFound("profile not found")
	}
	copy := *p
	copy.OwnedCardIDs = append([]string(nil), p.OwnedCardIDs...)
	return &copy, nil
}

// Update implements Repository with optimistic concurrency.
func (r *InMemoryProfileRepository) Update(ctx context.Context, profile *PrimitiveProfile) error {
	r.mu.Lock()
	defer r.mu.Unlock()
	existing, ok := r.profiles[profile.AccountID]
	if ok && existing.Version != profile.Version {
		return api.NewConflict(api.CodeConflict, "profile version conflict")
	}
	profile.Version++
	copy := *profile
	copy.OwnedCardIDs = append([]string(nil), profile.OwnedCardIDs...)
	r.profiles[profile.AccountID] = &copy
	return nil
}

// Erase implements Repository by zeroing the profile snapshot.
func (r *InMemoryProfileRepository) Erase(ctx context.Context, accountID string) error {
	r.mu.Lock()
	defer r.mu.Unlock()
	r.profiles[accountID] = &PrimitiveProfile{AccountID: accountID, Version: 1, UpdatedAt: time.Now().UTC()}
	return nil
}

// ErrProfileNotFound is returned when a profile is missing.
var ErrProfileNotFound = errors.New("profile not found")
