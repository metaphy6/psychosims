// Package receipts anomaly-signal persistence for Phase 3.3.
package receipts

import (
	"context"
	"time"

	"psychosims.dev/server/internal/schemas"
)

// AnomalySignal is the small, bounded provenance signal persisted per accepted
// receipt for cross-session farming detection.
type AnomalySignal struct {
	AccountID     string    `json:"account_id"`
	ReceiptID     string    `json:"receipt_id"`
	PatientID     string    `json:"patient_id"`
	PayoutPerCase int64     `json:"payout_per_case"`
	CadenceBucket string    `json:"cadence_bucket"`
	Counterpart   string    `json:"counterpart,omitempty"`
	RecordedAt    time.Time `json:"recorded_at"`
}

// SignalStore persists anomaly signals.
type SignalStore interface {
	Record(ctx context.Context, signal AnomalySignal) error
	ListByAccount(ctx context.Context, accountID string, since time.Time) ([]AnomalySignal, error)
}

// MemorySignalStore is an in-memory signal store for tests.
type MemorySignalStore struct {
	records []AnomalySignal
}

// NewMemorySignalStore creates a test signal store.
func NewMemorySignalStore() *MemorySignalStore { return &MemorySignalStore{} }

// Record stores a signal.
func (m *MemorySignalStore) Record(ctx context.Context, signal AnomalySignal) error {
	signal.RecordedAt = time.Now().UTC()
	m.records = append(m.records, signal)
	return nil
}

// ListByAccount returns signals for an account after a cutoff.
func (m *MemorySignalStore) ListByAccount(ctx context.Context, accountID string, since time.Time) ([]AnomalySignal, error) {
	var out []AnomalySignal
	for _, s := range m.records {
		if s.AccountID == accountID && s.RecordedAt.After(since) {
			out = append(out, s)
		}
	}
	return out, nil
}

// deriveSignals extracts the bounded provenance signal from a receipt.
func deriveSignals(accountID string, receipt schemas.SessionReceipt) AnomalySignal {
	payout := int64(0)
	for _, ev := range receipt.LedgerEvents {
		if ev.Currency == schemas.CurrencyCash {
			payout += int64(ev.AmountMicros)
		}
	}
	return AnomalySignal{
		AccountID:     accountID,
		ReceiptID:     receipt.IdempotencyKey,
		PatientID:     receipt.PatientID,
		PayoutPerCase: payout,
		CadenceBucket: time.Now().UTC().Format("2006-01-02T15"),
	}
}


