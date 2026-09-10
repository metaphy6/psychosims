package receipts

import (
	"context"
	"crypto/ed25519"
	"errors"
	"net/http"
	"strings"
	"testing"
	"time"

	"psychosims.dev/server/internal/api"
	"psychosims.dev/server/internal/audit"
	"psychosims.dev/server/internal/canonicaljson"
	"psychosims.dev/server/internal/crypto"
	"psychosims.dev/server/internal/ctxutil"
	"psychosims.dev/server/internal/devicekeys"
	"psychosims.dev/server/internal/idempotency"
	"psychosims.dev/server/internal/profile"
	"psychosims.dev/server/internal/ruleset"
	"psychosims.dev/server/internal/schemas"
)

func setupValidator(t *testing.T) (*Validator, *devicekeys.Service, ed25519.PrivateKey) {
	t.Helper()
	dkRepo := devicekeys.NewInMemoryRepository()
	dkSvc := devicekeys.NewService(dkRepo)
	verifier := crypto.NewVerifier(func(keyID string) (ed25519.PublicKey, error) {
		rec, err := dkSvc.Lookup(context.Background(), keyID)
		if err != nil || rec == nil {
			return nil, crypto.ErrKeyNotFound
		}
		return rec.PublicKey, nil
	})

	profRepo := profile.NewInMemoryProfileRepository()
	profRepo.Update(context.Background(), &profile.PrimitiveProfile{AccountID: "acc-1", Version: 0})

	// ledger requires sql.Tx; we pass nil and only test Validate path.
	cfg := DefaultLimits()
	v := NewVerifier(verifier, profRepo, nil, idempotency.NewService(idempotency.NewMemoryRepository(), 0), dkSvc, &cfg)

	pub, priv, _ := ed25519.GenerateKey(nil)
	_, _ = dkSvc.Register(context.Background(), "acc-1", pub, string(crypto.SuiteEd25519V1))
	return v, dkSvc, priv
}

func signEnvelope(receipt schemas.SessionReceipt, priv ed25519.PrivateKey, keyID string) schemas.SignedEnvelope {
	canon, _ := canonicaljson.Marshal(receipt)
	sig := ed25519.Sign(priv, canon)
	return schemas.SignedEnvelope{
		CanonicalReceiptBytes: canon,
		Signature:             sig,
		SuiteID:               string(crypto.SuiteEd25519V1),
		SigningKeyID:          keyID,
	}
}

func validReceipt() schemas.SessionReceipt {
	return schemas.SessionReceipt{
		ID:             "r-1",
		SchemaVersion:  schemas.CurrentReceiptSchemaVersion,
		RulesetVersion: "0.1.0",
		PatientID:      "fixture-p-001",
		IdempotencyKey: "idem-r1",
		CorrelationID:  "corr-r1",
		TurnCount:      1,
		StartState: schemas.SessionStartState{
			Loadout: schemas.Loadout{CardIds: []string{"open_question"}, SlotCap: 6},
			Library: schemas.CardLibrary{OwnedCardIds: []string{"open_question"}},
			Controllers: schemas.TherapyControllerSettings{
				Focus:             schemas.FocusBalanced,
				EmotionalDelivery: schemas.DeliveryBalanced,
			},
			InitialAxes: map[string]int{"trust": 0},
			RootSeed:    42,
		},
		Actions: []schemas.InteractionPattern{schemas.OpenQuestion},
		Deltas: []schemas.StructuredDelta{{
			RulesetVersion: "0.1.0",
			Axis:           schemas.AxisTrust,
			DeltaMillis:    50,
			ReasonKey:      "reason.open_question",
			CardType:       schemas.CardTypeRelatable,
			CardSignature:  schemas.SignatureBuffer,
			ContextFit:     schemas.ContextFitAligned,
		}},
		LedgerEvents: []schemas.LedgerEvent{{
			Kind:             "session_fee",
			IdempotencyKey:   "ledger-1",
			TimestampSeconds: 1700000000,
			Currency:         schemas.CurrencyCash,
			AmountMicros:     -100000,
			ReasonKey:        "reason.session_fee",
		}, {
			Kind:             "session_reward",
			IdempotencyKey:   "ledger-2",
			TimestampSeconds: 1700000000,
			Currency:         schemas.CurrencyCash,
			AmountMicros:     100000,
			ReasonKey:        "reason.session_reward",
		}},
	}
}

func TestValidateAcceptsGoldenReceipt(t *testing.T) {
	v, _, priv := setupValidator(t)
	env := signEnvelope(validReceipt(), priv, "key_1")
	_, err := v.Validate(context.Background(), "acc-1", env)
	if err != nil {
		t.Fatalf("validate: %v", err)
	}
}

func TestValidateFullSessionActionAndDeltaBounds(t *testing.T) {
	for _, count := range []int{100, 120, 121} {
		v, _, priv := setupValidator(t)
		r := validReceipt()
		r.LedgerEvents = nil
		r.TurnCount = count
		r.Actions = make([]schemas.InteractionPattern, count)
		for i := range r.Actions {
			r.Actions[i] = schemas.OpenQuestion
		}
		_, err := v.Validate(context.Background(), "acc-1", signEnvelope(r, priv, "key_1"))
		if (err == nil) != (count <= 120) {
			t.Fatalf("action count %d: %v", count, err)
		}
	}
	v, _, priv := setupValidator(t)
	r := validReceipt()
	delta := r.Deltas[0]
	// Exercise a stricter configured count while remaining below the separate
	// canonical-byte cap; a 1025-item full typed payload exceeds that cap first.
	v.cfg.MaxDeltas = 512
	r.Deltas = make([]schemas.StructuredDelta, 513)
	for i := range r.Deltas {
		r.Deltas[i] = delta
	}
	_, err := v.Validate(context.Background(), "acc-1", signEnvelope(r, priv, "key_1"))
	if err == nil || !strings.Contains(err.Error(), "delta") {
		t.Fatalf("delta bound not enforced: %v", err)
	}
}

func TestOversizedCanonicalReceiptRejectedBeforeKeyLookup(t *testing.T) {
	lookups := 0
	verifier := crypto.NewVerifier(func(string) (ed25519.PublicKey, error) {
		lookups++
		return nil, errors.New("key lookup must not run")
	})
	limits := DefaultLimits()
	v := NewVerifier(verifier, nil, nil, nil, nil, &limits)
	env := schemas.SignedEnvelope{CanonicalReceiptBytes: []byte(strings.Repeat(" ", 131073)), Signature: make([]byte, 64), SuiteID: "ed25519-v1", SigningKeyID: "key"}
	_, err := v.Validate(context.Background(), "account", env)
	var failure api.HTTPError
	if lookups != 0 || !errors.As(err, &failure) || failure.Status != http.StatusRequestEntityTooLarge {
		t.Fatalf("oversize reached key lookup or wrong error: lookups=%d error=%v", lookups, err)
	}
}

func TestValidateRejectsBadSignature(t *testing.T) {
	v, _, _ := setupValidator(t)
	_, wrongPriv, _ := ed25519.GenerateKey(nil)
	env := signEnvelope(validReceipt(), wrongPriv, "key_1")
	_, err := v.Validate(context.Background(), "acc-1", env)
	if err == nil {
		t.Fatal("expected error for bad signature")
	}
}

func TestValidateRejectsUnownedCard(t *testing.T) {
	v, _, priv := setupValidator(t)
	r := validReceipt()
	r.Actions = []schemas.InteractionPattern{schemas.Reframe}
	env := signEnvelope(r, priv, "key_1")
	_, err := v.Validate(context.Background(), "acc-1", env)
	if err == nil {
		t.Fatal("expected error for unowned card")
	}
}

func TestValidateRejectsNonConservingLedger(t *testing.T) {
	v, _, priv := setupValidator(t)
	r := validReceipt()
	r.LedgerEvents = []schemas.LedgerEvent{{
		Kind:           "mint",
		IdempotencyKey: "ledger-x",
		Currency:       schemas.CurrencyCash,
		AmountMicros:   100000,
		ReasonKey:      "reason.mint",
	}}
	env := signEnvelope(r, priv, "key_1")
	_, err := v.Validate(context.Background(), "acc-1", env)
	if err == nil {
		t.Fatal("expected error for non-conserving ledger")
	}
	if he, ok := err.(api.HTTPError); !ok || he.Body.Code != api.CodeInvalidLedger {
		t.Errorf("expected invalid ledger, got %v", err)
	}
}

func TestValidateRejectsUnknownRuleset(t *testing.T) {
	v, _, priv := setupValidator(t)
	reg := ruleset.NewRegistry(ruleset.Config{KnownVersions: []string{"0.1.0"}, SunsetWindow: 30 * 24 * time.Hour})
	v.WithRuleset(reg)
	r := validReceipt()
	r.RulesetVersion = "0.9.0"
	env := signEnvelope(r, priv, "key_1")
	_, err := v.Validate(context.Background(), "acc-1", env)
	if err == nil {
		t.Fatal("expected error for unknown ruleset")
	}
}

func TestValidateRejectsSunsetRuleset(t *testing.T) {
	v, _, priv := setupValidator(t)
	reg := ruleset.NewRegistry(ruleset.Config{KnownVersions: []string{"0.1.0"}, SunsetWindow: time.Hour})
	_ = reg.Register("0.1.0", time.Now().UTC().Add(-2*time.Hour), nil)
	v.WithRuleset(reg)
	r := validReceipt()
	env := signEnvelope(r, priv, "key_1")
	_, err := v.Validate(context.Background(), "acc-1", env)
	if err == nil {
		t.Fatal("expected error for sunset ruleset")
	}
}

func TestDeadLetterRecordsRejection(t *testing.T) {
	v, _, _ := setupValidator(t)
	memAudit := audit.NewMemoryAppender()
	svc := NewService(v, nil, idempotency.NewService(idempotency.NewMemoryRepository(), time.Hour), memAudit, nil)
	ctx := ctxutil.WithCorrelationID(context.Background(), "corr-dead")

	_, err := svc.Submit(ctx, "acc-1", schemas.SignedEnvelope{})
	if err == nil {
		t.Fatal("expected error for invalid envelope")
	}
	records := memAudit.Records()
	if len(records) != 1 {
		t.Fatalf("expected 1 audit record, got %d", len(records))
	}
	if records[0].Action != "receipt_reject" {
		t.Errorf("action = %q, want receipt_reject", records[0].Action)
	}
	if records[0].Outcome != string(api.CodeInvalidSignature) {
		t.Errorf("outcome = %q, want invalid_signature", records[0].Outcome)
	}
}

func TestValidateRejectsDialogueInSupportedFields(t *testing.T) {
	sentinel := "private patient dialogue"
	mutations := map[string]func(*schemas.SessionReceipt){
		"id":                  func(r *schemas.SessionReceipt) { r.ID = sentinel },
		"patient":             func(r *schemas.SessionReceipt) { r.PatientID = sentinel },
		"idempotency":         func(r *schemas.SessionReceipt) { r.IdempotencyKey = sentinel },
		"correlation":         func(r *schemas.SessionReceipt) { r.CorrelationID = sentinel },
		"oversize identifier": func(r *schemas.SessionReceipt) { r.CorrelationID = strings.Repeat("a", 129) },
		"case":                func(r *schemas.SessionReceipt) { r.StartState.CaseID = sentinel },
		"checksum":            func(r *schemas.SessionReceipt) { r.StartState.ManifestChecksum = sentinel },
		"axis key":            func(r *schemas.SessionReceipt) { r.StartState.InitialAxes[sentinel] = 1 },
		"axis value":          func(r *schemas.SessionReceipt) { r.StartState.InitialAxes["trust"] = 101 },
		"loadout": func(r *schemas.SessionReceipt) {
			r.StartState.Loadout.CardIds = append(r.StartState.Loadout.CardIds, sentinel)
		},
		"library": func(r *schemas.SessionReceipt) {
			r.StartState.Library.OwnedCardIds = append(r.StartState.Library.OwnedCardIds, sentinel)
		},
		"focus": func(r *schemas.SessionReceipt) { r.StartState.Controllers.Focus = schemas.FocusAxis(sentinel) },
		"delivery": func(r *schemas.SessionReceipt) {
			r.StartState.Controllers.EmotionalDelivery = schemas.EmotionalDelivery(sentinel)
		},
		"delta axis":     func(r *schemas.SessionReceipt) { r.Deltas[0].Axis = schemas.StateAxis(sentinel) },
		"delta rule":     func(r *schemas.SessionReceipt) { r.Deltas[0].RulesetVersion = sentinel },
		"delta reason":   func(r *schemas.SessionReceipt) { r.Deltas[0].ReasonKey = sentinel },
		"card type":      func(r *schemas.SessionReceipt) { r.Deltas[0].CardType = schemas.CardType(sentinel) },
		"card signature": func(r *schemas.SessionReceipt) { r.Deltas[0].CardSignature = schemas.CardSignature(sentinel) },
		"context fit":    func(r *schemas.SessionReceipt) { r.Deltas[0].ContextFit = schemas.ContextFit(sentinel) },
	}
	for name, mutate := range mutations {
		t.Run(name, func(t *testing.T) {
			v, _, priv := setupValidator(t)
			r := validReceipt()
			mutate(&r)
			_, err := v.Validate(context.Background(), "acc-1", signEnvelope(r, priv, "key_1"))
			if err == nil {
				t.Fatal("dialogue or unsupported structured value accepted")
			}
		})
	}
}

func TestReceiptFailureDoesNotEchoLedgerDialogue(t *testing.T) {
	v, _, priv := setupValidator(t)
	r := validReceipt()
	r.LedgerEvents = []schemas.LedgerEvent{{Currency: "private patient dialogue", AmountMicros: 1}}
	_, err := v.Validate(context.Background(), "acc-1", signEnvelope(r, priv, "key_1"))
	if err == nil || strings.Contains(err.Error(), "private patient dialogue") {
		t.Fatalf("unsafe ledger error: %v", err)
	}
}
