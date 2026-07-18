package main

import (
	"context"
	"crypto/ed25519"
	"encoding/json"
	"fmt"
	"time"

	"psychosims.dev/server/internal/canonicaljson"
	"psychosims.dev/server/internal/crypto"
	"psychosims.dev/server/internal/devicekeys"
	"psychosims.dev/server/internal/idempotency"
	"psychosims.dev/server/internal/profile"
	"psychosims.dev/server/internal/receipts"
	"psychosims.dev/server/internal/ruleset"
	"psychosims.dev/server/internal/schemas"
)

func receiptDemo(path string) error {
	r := newReport("Receipt validation")
	r.line("This demo certifies a device key, signs a minimal receipt, and validates it server-side.")
	r.line("")

	pub, priv := crypto.GenerateTestKeypair()
	dkRepo := devicekeys.NewInMemoryRepository()
	dkSvc := devicekeys.NewService(dkRepo)
	ctx := context.Background()
	keyID, err := dkSvc.Register(ctx, "acct-1", pub, string(crypto.SuiteEd25519V1))
	if err != nil {
		return err
	}

	r.h2("Device key provisioned")
	r.code(fmt.Sprintf("key_id = %s\nsuite = %s", keyID, crypto.SuiteEd25519V1))

	receiptMap := map[string]any{
		"id":              "r1",
		"schema_version":  schemas.CurrentReceiptSchemaVersion,
		"ruleset_version": "1.0.0",
		"patient_id":      "p1",
		"idempotency_key": "idem-1",
		"correlation_id":  "c1",
		"turn_count":      1,
		"start_state": map[string]any{
			"library": map[string]any{
				"owned_card_ids": []any{"c1"},
			},
			"loadout":      map[string]any{},
			"controllers":  map[string]any{},
			"initial_axes": map[string]any{},
			"root_seed":    42,
		},
		"actions":       []any{string("c1")},
		"deltas":        []any{},
		"ledger_events": []any{},
	}
	canonical, err := canonicaljson.Encode(receiptMap)
	if err != nil {
		return err
	}
	sig := ed25519.Sign(priv, canonical)

	env := schemas.SignedEnvelope{
		CanonicalReceiptBytes: canonical,
		Signature:             sig,
		SuiteID:               string(crypto.SuiteEd25519V1),
		SigningKeyID:          keyID,
	}

	reg := ruleset.NewRegistry(ruleset.Config{KnownVersions: []string{"1.0.0"}, SunsetWindow: 24 * time.Hour})
	verifier := crypto.NewVerifier(func(kid string) (ed25519.PublicKey, error) {
		rec, err := dkSvc.Lookup(ctx, kid)
		if err != nil || rec == nil {
			return nil, crypto.ErrKeyNotFound
		}
		return rec.PublicKey, nil
	})
	lim := receipts.DefaultLimits()
	validator := receipts.NewVerifier(verifier, profile.NewInMemoryProfileRepository(), nil,
		idempotency.NewService(idempotency.NewMemoryRepository(), time.Hour), dkSvc, &lim).WithRuleset(reg)

	validated, err := validator.Validate(ctx, "acct-1", env)
	r.h2("Validation result")
	if err != nil {
		r.code(fmt.Sprintf("error = %v", err))
	} else {
		b, _ := json.MarshalIndent(validated, "", "  ")
		r.code(fmt.Sprintf("accepted = true\n%v", string(b)))
	}
	return r.write(path)
}
