package integration

import (
	"context"
	"crypto/ed25519"
	"crypto/sha256"
	"encoding/json"
	"fmt"
	"testing"
	"time"

	"psychosims.dev/server/internal/canonicaljson"
	"psychosims.dev/server/internal/crypto"
	"psychosims.dev/server/internal/ctxutil"
	"psychosims.dev/server/internal/devicekeys"
	"psychosims.dev/server/internal/idempotency"
	"psychosims.dev/server/internal/ownership"
	"psychosims.dev/server/internal/presence"
	"psychosims.dev/server/internal/profile"
	"psychosims.dev/server/internal/receipts"
	"psychosims.dev/server/internal/schemas"
	"psychosims.dev/server/internal/timeutil"
)

// integrationContext returns a context wired with the account and idempotency
// key seams used by the receipt pipeline.
func integrationContext(accountID, idemKey string) context.Context {
	ctx := context.Background()
	ctx = ctxutil.WithAccountID(ctx, accountID)
	ctx = ctxutil.WithIdempotencyKey(ctx, idemKey)
	ctx = ctxutil.WithCorrelationID(ctx, "corr-"+idemKey)
	return ctx
}

func newTestReceipt(idemKey string) schemas.SessionReceipt {
	return schemas.SessionReceipt{
		ID:             "receipt-" + idemKey,
		SchemaVersion:  schemas.CurrentReceiptSchemaVersion,
		RulesetVersion: "0.5.0",
		PatientID:      "patient-1",
		IdempotencyKey: idemKey,
		CorrelationID:  "corr-" + idemKey,
		TurnCount:      3,
		StartState: schemas.SessionStartState{
			Loadout: schemas.Loadout{
				CardIds: []string{"open_question", "validate"},
				SlotCap: 2,
			},
			Library: schemas.CardLibrary{
				OwnedCardIds: []string{"open_question", "validate"},
			},
			Controllers: schemas.TherapyControllerSettings{
				Focus:             schemas.FocusBalanced,
				EmotionalDelivery: schemas.DeliveryBalanced,
			},
			InitialAxes: map[string]int{"trust": 0},
			RootSeed:    42,
		},
		Actions: []schemas.InteractionPattern{schemas.OpenQuestion, schemas.Validate},
		Deltas: []schemas.StructuredDelta{
			{
				RulesetVersion: "0.5.0",
				Axis:           schemas.AxisTrust,
				DeltaMillis:    5,
				ReasonKey:      "reason.open_question",
				CardType:       schemas.CardTypeDisclosing,
				CardSignature:  schemas.SignatureBuffer,
				ContextFit:     schemas.ContextFitAligned,
			},
		},
		LedgerEvents: []schemas.LedgerEvent{
			{
				Kind:             "session_fee",
				IdempotencyKey:   idemKey + "-fee",
				TimestampSeconds: 100,
				Currency:         schemas.CurrencyCash,
				AmountMicros:     -5000000,
				ReasonKey:        "reason.session_fee",
			},
			{
				Kind:             "session_payout",
				IdempotencyKey:   idemKey + "-payout",
				TimestampSeconds: 100,
				Currency:         schemas.CurrencyCash,
				AmountMicros:     5000000,
				ReasonKey:        "reason.session_payout",
			},
		},
	}
}

func canonicalReceiptBytes(t *testing.T, receipt schemas.SessionReceipt) []byte {
	t.Helper()
	// Mirror the Dart producer: struct → JSON map → canonical bytes. Using
	// encoding/json with the struct tags gives us the snake_case map keys;
	// canonicaljson then sorts and serialises deterministically.
	intermediate, err := json.Marshal(receipt)
	if err != nil {
		t.Fatalf("json marshal receipt: %v", err)
	}
	var m map[string]any
	if err := json.Unmarshal(intermediate, &m); err != nil {
		t.Fatalf("json unmarshal receipt map: %v", err)
	}
	canonical, err := canonicaljson.Encode(m)
	if err != nil {
		t.Fatalf("canonical encode: %v", err)
	}
	return canonical
}

func signReceipt(t *testing.T, keyID string, priv ed25519.PrivateKey, receipt schemas.SessionReceipt) schemas.SignedEnvelope {
	t.Helper()
	canonical := canonicalReceiptBytes(t, receipt)
	return schemas.SignedEnvelope{
		CanonicalReceiptBytes: canonical,
		Signature:             ed25519.Sign(priv, canonical),
		SuiteID:               string(crypto.SuiteEd25519V1),
		SigningKeyID:          keyID,
	}
}

func buildTestPipeline(t *testing.T) (
	*receipts.Validator,
	*devicekeys.Service,
	*profile.InMemoryProfileRepository,
	*profile.InMemoryLedger,
	*timeutil.FixedClock,
	*idempotency.Service,
) {
	t.Helper()
	clock := &timeutil.FixedClock{T: time.Unix(1000, 0).UTC()}

	dkRepo := devicekeys.NewInMemoryRepository()
	dkSvc := devicekeys.NewService(dkRepo)

	verifier := receipts.NewVerifierFromDeviceKeys(dkSvc)

	profRepo := profile.NewInMemoryProfileRepository()
	_ = profRepo.Update(context.Background(), &profile.PrimitiveProfile{
		AccountID: "acct-1",
		Version:   0,
		UpdatedAt: clock.Now(),
	})

	ledger := profile.NewInMemoryLedger(clock)
	idemSvc := idempotency.NewService(idempotency.NewMemoryRepository(), time.Hour)

	cfg := receipts.DefaultLimits()
	validator := receipts.NewVerifier(verifier, profRepo, ledger, idemSvc, dkSvc, &cfg)
	return validator, dkSvc, profRepo, ledger, clock, idemSvc
}

// TestReceiptByteIdenticalRoundTrip proves the Dart↔Go contract: a canonical
// receipt encodes to the same bytes after JSON round-trip, and the signed
// envelope preserves the exact bytes the signature covers.
func TestReceiptByteIdenticalRoundTrip(t *testing.T) {
	receipt := newTestReceipt("idem-roundtrip-1")

	canonical := canonicalReceiptBytes(t, receipt)

	var parsed map[string]any
	if err := canonicaljson.DecodeInto(canonical, &parsed); err != nil {
		t.Fatalf("decode receipt: %v", err)
	}
	reparsed, err := canonicaljson.Encode(parsed)
	if err != nil {
		t.Fatalf("re-encode receipt: %v", err)
	}
	if string(reparsed) != string(canonical) {
		t.Errorf("receipt bytes changed after round-trip:\n got: %s\nwant: %s", reparsed, canonical)
	}

	pub, priv := crypto.GenerateTestKeypair()
	env := signReceipt(t, "key-rt", priv, receipt)
	if !ed25519.Verify(pub, env.CanonicalReceiptBytes, env.Signature) {
		t.Error("signature did not verify over canonical bytes")
	}

	envJSON, err := json.Marshal(env)
	if err != nil {
		t.Fatalf("marshal envelope: %v", err)
	}
	var envBack schemas.SignedEnvelope
	if err := json.Unmarshal(envJSON, &envBack); err != nil {
		t.Fatalf("unmarshal envelope: %v", err)
	}
	if string(envBack.CanonicalReceiptBytes) != string(canonical) {
		t.Error("signed envelope lost canonical bytes after JSON round-trip")
	}
}

// TestReceiptValidationAndIdempotency exercises the auth → signing → validate
// flow and proves that replaying the same idempotency key is rejected.
func TestReceiptValidationAndIdempotency(t *testing.T) {
	validator, dkSvc, _, ledger, clock, idemSvc := buildTestPipeline(t)
	ctx := integrationContext("acct-1", "idem-validate-1")

	pub, priv := crypto.GenerateTestKeypair()
	keyID, err := dkSvc.Register(ctx, "acct-1", pub, string(crypto.SuiteEd25519V1))
	if err != nil {
		t.Fatalf("register device key: %v", err)
	}

	receipt := newTestReceipt("idem-validate-1")
	env := signReceipt(t, keyID, priv, receipt)

	validated, err := validator.Validate(ctx, "acct-1", env)
	if err != nil {
		t.Fatalf("validate receipt: %v", err)
	}
	if validated.PatientID != receipt.PatientID {
		t.Errorf("patient id = %q, want %q", validated.PatientID, receipt.PatientID)
	}

	// Simulate the atomic commit path (ledger append + idempotency record).
	if err := ledger.Append(ctx, nil, "acct-1", validated.LedgerEvents); err != nil {
		t.Fatalf("ledger append: %v", err)
	}
	if err := idemSvc.Record(ctx, stubHash()); err != nil {
		t.Fatalf("record idempotency: %v", err)
	}

	// Replay with the same idempotency key must be detected by the idempotency
	// service before any side-effect.
	shouldExec, _, err := idemSvc.CheckOrBegin(ctx)
	if err == nil {
		t.Fatal("expected idempotency conflict on replay, got nil")
	}
	if shouldExec {
		t.Error("shouldExec = true on replay")
	}

	// Wrong account must fail signature account-binding.
	_, err = validator.Validate(integrationContext("acct-2", "idem-validate-2"), "acct-2", env)
	if err == nil {
		t.Fatal("expected validation failure for wrong account")
	}

	_ = clock
}

// TestBatchReceiptDrain validates that multiple distinct receipts can be
// validated and committed in order, and that a partial duplicate in the batch
// does not double-apply.
func TestBatchReceiptDrain(t *testing.T) {
	validator, dkSvc, profRepo, ledger, _, idemSvc := buildTestPipeline(t)
	ctx := integrationContext("acct-1", "dummy")

	pub, priv := crypto.GenerateTestKeypair()
	keyID, err := dkSvc.Register(ctx, "acct-1", pub, string(crypto.SuiteEd25519V1))
	if err != nil {
		t.Fatalf("register device key: %v", err)
	}

	var seen []string
	for i := 0; i < 3; i++ {
		idem := fmt.Sprintf("idem-batch-%d", i)
		r := newTestReceipt(idem)
		r.PatientID = fmt.Sprintf("patient-%d", i)
		// Make ledger events currency-conserved per receipt.
		r.LedgerEvents = []schemas.LedgerEvent{
			{Kind: "fee", IdempotencyKey: idem + "-fee", Currency: schemas.CurrencyCash, AmountMicros: -100, ReasonKey: "fee"},
			{Kind: "payout", IdempotencyKey: idem + "-pay", Currency: schemas.CurrencyCash, AmountMicros: 100, ReasonKey: "payout"},
		}
		env := signReceipt(t, keyID, priv, r)

		vctx := integrationContext("acct-1", idem)
		validated, err := validator.Validate(vctx, "acct-1", env)
		if err != nil {
			t.Fatalf("validate %s: %v", idem, err)
		}
		if err := ledger.Append(vctx, nil, "acct-1", validated.LedgerEvents); err != nil {
			t.Fatalf("ledger append %s: %v", idem, err)
		}
		if err := idemSvc.Record(vctx, stubHash()); err != nil {
			t.Fatalf("record idempotency %s: %v", idem, err)
		}
		seen = append(seen, validated.PatientID)
	}

	if len(seen) != 3 {
		t.Fatalf("expected 3 validated receipts, got %d", len(seen))
	}

	// Replay the middle receipt; idempotency must reject it.
	midCtx := integrationContext("acct-1", "idem-batch-1")
	shouldExec, _, err := idemSvc.CheckOrBegin(midCtx)
	if err == nil || shouldExec {
		t.Error("expected idempotent replay rejection for middle receipt")
	}

	evts := ledger.Events()
	if len(evts) != 6 {
		t.Errorf("ledger events = %d, want 6 (no double-apply)", len(evts))
	}

	p, _ := profRepo.Get(context.Background(), "acct-1")
	if p == nil || p.Version < 1 {
		t.Error("profile should have been created/updated")
	}
}

// TestOwnershipLeaseExpiry proves that an expired lease is reconciled rather
// than allowing a transition.
func TestOwnershipLeaseExpiry(t *testing.T) {
	now := time.Unix(1000, 0).UTC()
	clock := &timeutil.FixedClock{T: now}
	repo := &leaseOwnershipRepository{record: &ownership.Record{
		PatientID:      "patient-lease",
		AccountID:      "acct-1",
		State:          ownership.StateOwned,
		Version:        1,
		LeaseExpiresAt: &now,
		UpdatedAt:      now,
	}}
	svc := ownership.NewService(repo, clock)

	// Lease has just expired; transition must fail.
	clock.Advance(time.Second)
	err := svc.Transition(context.Background(), "patient-lease", "acct-1", ownership.StateOwned, ownership.StateArchived, 1)
	if err == nil {
		t.Fatal("expected lease-expired error")
	}
}

type leaseOwnershipRepository struct {
	record *ownership.Record
}

func (r *leaseOwnershipRepository) Get(ctx context.Context, patientID string) (*ownership.Record, error) {
	return r.record, nil
}

func (r *leaseOwnershipRepository) Claim(ctx context.Context, patientID, accountID string, version int, classes ...ownership.MemoryClass) error {
	return fmt.Errorf("not used")
}

func (r *leaseOwnershipRepository) Transition(ctx context.Context, patientID, accountID string, from, to ownership.State, version int) error {
	return nil
}

// TestOwnershipStoreSlownessTimeout proves graceful degradation under a
// slow/timing-out store via context cancellation.
func TestOwnershipStoreSlownessTimeout(t *testing.T) {
	slowRepo := &slowOwnershipRepository{delay: 500 * time.Millisecond}
	svc := ownership.NewService(slowRepo, timeutil.RealClock{})

	ctx, cancel := context.WithTimeout(context.Background(), 50*time.Millisecond)
	defer cancel()

	err := svc.Claim(ctx, "patient-slow", "acct-1", 0, ownership.MemoryClassPersistent)
	if err == nil {
		t.Fatal("expected timeout error from slow store")
	}
}

type slowOwnershipRepository struct {
	delay time.Duration
}

func (r *slowOwnershipRepository) Get(ctx context.Context, patientID string) (*ownership.Record, error) {
	select {
	case <-time.After(r.delay):
		return nil, fmt.Errorf("store timeout")
	case <-ctx.Done():
		return nil, ctx.Err()
	}
}

func (r *slowOwnershipRepository) Claim(ctx context.Context, patientID, accountID string, version int, classes ...ownership.MemoryClass) error {
	select {
	case <-time.After(r.delay):
		return fmt.Errorf("store timeout")
	case <-ctx.Done():
		return ctx.Err()
	}
}

func (r *slowOwnershipRepository) Transition(ctx context.Context, patientID, accountID string, from, to ownership.State, version int) error {
	select {
	case <-time.After(r.delay):
		return fmt.Errorf("store timeout")
	case <-ctx.Done():
		return ctx.Err()
	}
}

// TestPresenceRoundTrip verifies the presence record schema round-trips and
// the server signature verifies.
func TestPresenceRoundTrip(t *testing.T) {
	repo := presence.NewInMemoryRepository()
	pub, priv := crypto.GenerateTestKeypair()
	svc := presence.NewService(repo, priv)

	rec, err := svc.Set(context.Background(), "acct-1", "online", string(crypto.SuiteEd25519V1))
	if err != nil {
		t.Fatalf("set presence: %v", err)
	}
	if !svc.Verify(pub, rec) {
		t.Error("presence signature did not verify")
	}

	jsonBytes, err := json.Marshal(rec)
	if err != nil {
		t.Fatalf("marshal presence: %v", err)
	}
	var back presence.Record
	if err := json.Unmarshal(jsonBytes, &back); err != nil {
		t.Fatalf("unmarshal presence: %v", err)
	}
	if back.AccountID != rec.AccountID || back.Status != rec.Status {
		t.Error("presence record lost fields after JSON round-trip")
	}
}

// TestReceiptTamperedCanonicalBytes proves verify-in-place: changing even one
// byte of the canonical receipt invalidates the signature.
func TestReceiptTamperedCanonicalBytes(t *testing.T) {
	_, dkSvc, _, _, _, _ := buildTestPipeline(t)
	ctx := integrationContext("acct-1", "idem-tamper-1")

	pub, priv := crypto.GenerateTestKeypair()
	keyID, err := dkSvc.Register(ctx, "acct-1", pub, string(crypto.SuiteEd25519V1))
	if err != nil {
		t.Fatalf("register device key: %v", err)
	}

	env := signReceipt(t, keyID, priv, newTestReceipt("idem-tamper-1"))
	env.CanonicalReceiptBytes[0] ^= 0xFF

	verifier := receipts.NewVerifierFromDeviceKeys(dkSvc)
	if err := verifier.VerifyEnvelope(env); err == nil {
		t.Fatal("expected verification failure for tampered canonical bytes")
	}
}

// TestProfileRoundTrip proves the primitive profile schema round-trips without
// field drift.
func TestProfileRoundTrip(t *testing.T) {
	prof := profile.PrimitiveProfile{
		AccountID:  "acct-rt",
		Version:    7,
		Level:      3,
		XP:         1200,
		CashMicros: 5000000,
		ClinicTier: 2,
		UpdatedAt:  time.Unix(2000, 0).UTC(),
	}
	payload, err := json.Marshal(prof)
	if err != nil {
		t.Fatalf("marshal profile: %v", err)
	}
	var parsed profile.PrimitiveProfile
	if err := json.Unmarshal(payload, &parsed); err != nil {
		t.Fatalf("unmarshal profile: %v", err)
	}
	if parsed.AccountID != prof.AccountID || parsed.Version != prof.Version || parsed.XP != prof.XP {
		t.Errorf("profile round-trip mismatch: %+v", parsed)
	}
}

func TestReceiptLedgerConservation(t *testing.T) {
	validator, dkSvc, _, _, _, _ := buildTestPipeline(t)
	ctx := integrationContext("acct-1", "idem-conservation")

	pub, priv := crypto.GenerateTestKeypair()
	keyID, err := dkSvc.Register(ctx, "acct-1", pub, string(crypto.SuiteEd25519V1))
	if err != nil {
		t.Fatalf("register device key: %v", err)
	}

	receipt := newTestReceipt("idem-conservation")
	receipt.LedgerEvents = []schemas.LedgerEvent{
		{Kind: "fee", IdempotencyKey: "ik-fee", Currency: schemas.CurrencyCash, AmountMicros: -100, ReasonKey: "fee"},
		// Missing offsetting event: net -100, should fail conservation.
	}
	env := signReceipt(t, keyID, priv, receipt)
	_, err = validator.Validate(ctx, "acct-1", env)
	if err == nil {
		t.Fatal("expected validation failure for unconserved ledger")
	}
}

// stubHash returns a deterministic response hash for idempotency tests.
func stubHash() []byte {
	h := sha256.Sum256([]byte("ok"))
	return h[:]
}
