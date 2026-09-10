// Package ownership implements the C-8 patient ownership state machine for
// Phase 3.6: pool ⇄ owned, owned → owned′ (referral), owned ⇄ hospitalized,
// owned → cured → archived, owned → archived.
package ownership

import (
	"context"
	"database/sql"
	"fmt"
	"time"

	"psychosims.dev/server/internal/api"
	"psychosims.dev/server/internal/timeutil"
)

// State is an ownership state value.
type State string

const (
	StatePool         State = "pool"
	StateOwned        State = "owned"
	StateHospitalized State = "hospitalized"
	StateCured        State = "cured"
	StateArchived     State = "archived"
)

// MemoryClass classifies how much persistent history an ownership record may
// carry (C-8 / §17).
type MemoryClass string

const (
	MemoryClassStateless     MemoryClass = "stateless"
	MemoryClassSocialChronic MemoryClass = "social_chronic"
	MemoryClassPersistent    MemoryClass = "persistent"
)

// Record is the authoritative ownership row.
type Record struct {
	PatientID      string      `json:"patient_id"`
	AccountID      string      `json:"account_id"`
	State          State       `json:"state"`
	MemoryClass    MemoryClass `json:"memory_class"`
	Version        int         `json:"version"`
	LeaseExpiresAt *time.Time  `json:"lease_expires_at,omitempty"`
	UpdatedAt      time.Time   `json:"updated_at"`
}

// Service arbitrates ownership transitions with lease and memory-class checks.
type Service struct {
	repo  Repository
	clock timeutil.Clock
}

// NewService builds an ownership service.
func NewService(repo Repository, clock timeutil.Clock) *Service {
	return &Service{repo: repo, clock: clock}
}

// Transition applies a guarded ownership transition, reconciling against an
// expired lease instead of applying the transition.
func (s *Service) Transition(ctx context.Context, patientID, accountID string, from, to State, version int) error {
	rec, err := s.repo.Get(ctx, patientID)
	if err != nil {
		return err
	}
	if rec.LeaseExpiresAt != nil && s.clock.Now().After(*rec.LeaseExpiresAt) {
		return api.NewError(409, api.ErrUser, api.CodeLeaseExpired, "ownership lease expired; reconcile before transition")
	}
	if err := memoryClassGuard(rec.MemoryClass, from, to); err != nil {
		return err
	}
	return s.repo.Transition(ctx, patientID, accountID, from, to, version)
}

// Claim claims a patient from the pool, recording memory class.
func (s *Service) Claim(ctx context.Context, patientID, accountID string, version int, mc MemoryClass) error {
	return s.repo.Claim(ctx, patientID, accountID, version, mc)
}

func memoryClassGuard(mc MemoryClass, from, to State) error {
	// Legacy rows fail closed to the stateless privacy contract.
	if mc == "" {
		mc = MemoryClassStateless
	}
	// Stateless / social-chronic patients may not enter long-term hospitalization
	// because there is no persistent history envelope to carry.
	if (mc == MemoryClassStateless || mc == MemoryClassSocialChronic) && to == StateHospitalized {
		return api.NewUserError(api.CodeIllegalTransition, "stateless/social-chronic patients cannot be hospitalized")
	}
	return nil
}

// Repository abstracts ownership persistence.
type Repository interface {
	Get(ctx context.Context, patientID string) (*Record, error)
	Claim(ctx context.Context, patientID, accountID string, version int, classes ...MemoryClass) error
	Transition(ctx context.Context, patientID, accountID string, from, to State, version int) error
}

// SQLRepository is the Postgres-backed ownership store.
type SQLRepository struct {
	db *sql.DB
}

// NewSQLRepository creates a new ownership repository.
func NewSQLRepository(db *sql.DB) *SQLRepository {
	return &SQLRepository{db: db}
}

// Get returns the current ownership record.
func (r *SQLRepository) Get(ctx context.Context, patientID string) (*Record, error) {
	row := r.db.QueryRowContext(ctx, `
		SELECT patient_id, account_id, state, version, lease_expires_at, updated_at, memory_class
		FROM ownership_records WHERE patient_id = $1
	`, patientID)
	var rec Record
	var lease sql.NullTime
	if err := row.Scan(&rec.PatientID, &rec.AccountID, &rec.State, &rec.Version, &lease, &rec.UpdatedAt, &rec.MemoryClass); err != nil {
		if err == sql.ErrNoRows {
			return nil, api.NewNotFound("ownership record not found")
		}
		return nil, err
	}
	if lease.Valid {
		rec.LeaseExpiresAt = &lease.Time
	}
	return &rec, nil
}

// EnsureCatalogLease creates an account's isolated catalog instance or renews
// its expired owned lease. It never changes owner, state, or memory class.
// This transaction locks only ownership and commits before grant acquisition,
// so it cannot invert the receipt path's grant-before-ownership lock order.
func (r *SQLRepository) EnsureCatalogLease(ctx context.Context, patientID, accountID string, mc MemoryClass) error {
	if _, err := claimMemoryClass([]MemoryClass{mc}); err != nil {
		return err
	}
	tx, err := r.db.BeginTx(ctx, nil)
	if err != nil {
		return err
	}
	defer tx.Rollback()
	_, err = tx.ExecContext(ctx, `INSERT INTO ownership_records (patient_id,account_id,state,version,lease_expires_at,memory_class)
		VALUES ($1,$2,'owned',1,clock_timestamp()+INTERVAL '24 hours',$3) ON CONFLICT (patient_id) DO NOTHING`, patientID, accountID, mc)
	if err != nil {
		return err
	}
	var owner, state, memory string
	var lease sql.NullTime
	if err = tx.QueryRowContext(ctx, `SELECT account_id,state,memory_class,lease_expires_at FROM ownership_records WHERE patient_id=$1 FOR UPDATE`, patientID).Scan(&owner, &state, &memory, &lease); err != nil {
		return err
	}
	if owner != accountID || state != string(StateOwned) || memory != string(mc) || !lease.Valid {
		return api.NewConflict(api.CodeConflict, "catalog instance is not available to renew")
	}
	// Evaluated after the row lock: waiting must not extend an expired lease.
	_, err = tx.ExecContext(ctx, `UPDATE ownership_records SET lease_expires_at=clock_timestamp()+INTERVAL '24 hours',version=version+1,updated_at=clock_timestamp()
		WHERE patient_id=$1 AND lease_expires_at<=clock_timestamp()`, patientID)
	if err != nil {
		return err
	}
	return tx.Commit()
}

// Claim attempts pool → owned for an account with optimistic concurrency.
func (r *SQLRepository) Claim(ctx context.Context, patientID, accountID string, version int, classes ...MemoryClass) error {
	mc, err := claimMemoryClass(classes)
	if err != nil {
		return err
	}
	res, err := r.db.ExecContext(ctx, `
		INSERT INTO ownership_records (patient_id, account_id, state, version, lease_expires_at, memory_class)
		VALUES ($1, $2, 'owned', 1, NOW() + INTERVAL '24 hours', $4)
		ON CONFLICT (patient_id) DO UPDATE SET
			account_id = EXCLUDED.account_id,
			state = EXCLUDED.state,
			version = ownership_records.version + 1,
			lease_expires_at = EXCLUDED.lease_expires_at,
			updated_at = NOW()
		WHERE ownership_records.state = 'pool' AND ownership_records.version = $3 AND ownership_records.memory_class = $4
	`, patientID, accountID, version, mc)
	if err != nil {
		return err
	}
	n, _ := res.RowsAffected()
	if n == 0 {
		return api.NewConflict(api.CodeConflict, "patient is not available or version conflict")
	}
	return nil
}

// Transition moves a record from one state to another if owned by accountID.
func (r *SQLRepository) Transition(ctx context.Context, patientID, accountID string, from, to State, version int) error {
	if !legalTransition(from, to) {
		return api.NewUserError(api.CodeIllegalTransition, fmt.Sprintf("illegal transition %s → %s", from, to))
	}
	res, err := r.db.ExecContext(ctx, `
		UPDATE ownership_records
		SET state = $1, version = version + 1, updated_at = NOW()
        WHERE patient_id = $2 AND account_id = $3 AND state = $4 AND version = $5
            AND (lease_expires_at IS NULL OR lease_expires_at > NOW())
            AND ($1 <> 'hospitalized' OR memory_class = 'persistent')
	`, string(to), patientID, accountID, string(from), version)
	if err != nil {
		return err
	}
	n, _ := res.RowsAffected()
	if n == 0 {
		return api.NewConflict(api.CodeConflict, "ownership transition conflict")
	}
	return nil
}

func legalTransition(from, to State) bool {
	switch from {
	case StatePool:
		return to == StateOwned
	case StateOwned:
		return to == StateHospitalized || to == StateCured || to == StateArchived || to == StateOwned
	case StateHospitalized:
		return to == StateOwned
	case StateCured:
		return to == StateArchived
	default:
		return false
	}
}

// InMemoryRepository is a test implementation.
type InMemoryRepository struct {
	records map[string]*Record
}

// NewInMemoryRepository creates a test repository.
func NewInMemoryRepository() *InMemoryRepository {
	return &InMemoryRepository{records: make(map[string]*Record)}
}

// Get implements Repository.
func (r *InMemoryRepository) Get(ctx context.Context, patientID string) (*Record, error) {
	rec, ok := r.records[patientID]
	if !ok {
		return nil, api.NewNotFound("ownership record not found")
	}
	return rec, nil
}

// Claim implements Repository.
func (r *InMemoryRepository) Claim(ctx context.Context, patientID, accountID string, version int, classes ...MemoryClass) error {
	mc, err := claimMemoryClass(classes)
	if err != nil {
		return err
	}
	rec, ok := r.records[patientID]
	if !ok {
		r.records[patientID] = &Record{
			PatientID:   patientID,
			AccountID:   accountID,
			State:       StateOwned,
			MemoryClass: mc,
			Version:     1,
			UpdatedAt:   time.Now().UTC(),
		}
		return nil
	}
	if rec.State != StatePool || rec.Version != version || rec.MemoryClass != mc {
		return api.NewConflict(api.CodeConflict, "patient is not available")
	}
	rec.AccountID = accountID
	rec.State = StateOwned
	rec.Version++
	rec.UpdatedAt = time.Now().UTC()
	return nil
}

// Transition implements Repository.
func (r *InMemoryRepository) Transition(ctx context.Context, patientID, accountID string, from, to State, version int) error {
	if !legalTransition(from, to) {
		return api.NewUserError(api.CodeIllegalTransition, fmt.Sprintf("illegal transition %s → %s", from, to))
	}
	rec, ok := r.records[patientID]
	if !ok || rec.AccountID != accountID || rec.State != from || rec.Version != version {
		return api.NewConflict(api.CodeConflict, "ownership transition conflict")
	}
	if err := memoryClassGuard(rec.MemoryClass, from, to); err != nil {
		return err
	}
	if rec.LeaseExpiresAt != nil && !time.Now().Before(*rec.LeaseExpiresAt) {
		return api.NewConflict(api.CodeLeaseExpired, "ownership lease expired")
	}
	rec.State = to
	rec.Version++
	rec.UpdatedAt = time.Now().UTC()
	return nil
}

func claimMemoryClass(classes []MemoryClass) (MemoryClass, error) {
	mc := MemoryClassStateless
	if len(classes) > 0 {
		mc = classes[0]
	}
	switch mc {
	case MemoryClassStateless, MemoryClassSocialChronic, MemoryClassPersistent:
		return mc, nil
	}
	return "", api.NewUserError(api.CodeBadRequest, "valid memory class required")
}
