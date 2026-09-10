package outcomes

import (
	"bytes"
	"crypto/sha256"
	"encoding/hex"
	"encoding/json"
	"os"
	"testing"

	"psychosims.dev/server/internal/canonicaljson"
	"psychosims.dev/server/internal/schemas"
)

func fixture(t *testing.T) []byte {
	t.Helper()
	b, err := os.ReadFile("../../../test_fixtures/outcomes/trusted_catalog_v1.json")
	if err != nil {
		t.Fatal(err)
	}
	return b
}
func digest(b []byte) string { h := sha256.Sum256(b); return hex.EncodeToString(h[:]) }
func loadFixture(t *testing.T) (*Catalog, []byte) {
	t.Helper()
	b := fixture(t)
	c, err := Load(bytes.NewReader(b), digest(b), nil)
	if err != nil {
		t.Fatal(err)
	}
	return c, b
}
func firstReceipt(t *testing.T, b []byte) (string, schemas.SessionReceipt) {
	t.Helper()
	var a artifact
	if err := json.Unmarshal(b, &a); err != nil {
		t.Fatal(err)
	}
	p := a.Proofs[0].Proof
	return a.Proofs[0].SHA256, schemas.SessionReceipt{SchemaVersion: p.ReceiptSchemaVersion, RulesetVersion: p.Manifest.RulesetVersion, StartState: p.StartState, Actions: p.Actions, Deltas: p.Deltas, TurnCount: p.TurnCount}
}

func TestDartProofSelectionAndExactReceiptMatch(t *testing.T) {
	c, b := loadFixture(t)
	id, receipt := firstReceipt(t, b)
	start := receipt.StartState
	owned := append(append([]string{}, start.Library.OwnedCardIds...), "reflect")
	permit, ok := c.Select(start.CaseID, start.ManifestChecksum, receipt.RulesetVersion, start.Loadout.CardIds, owned, start.InitialAxes, start.Controllers)
	if !ok || permit.ProofID != id || permit.StartState.RootSeed != 1729 || permit.StartState.Loadout.SlotCap != 5 {
		t.Fatalf("wrong selected proof: %#v, %v", permit, ok)
	}
	if !c.Match(id, receipt) {
		t.Fatal("actual Dart witness does not match")
	}
	// Returned collections must not mutate authority for future selections.
	permit.StartState.InitialAxes["trust"] = 99
	permit.StartState.Loadout.CardIds[0] = "reflect"
	if !c.Match(id, receipt) {
		t.Fatal("caller changed internal proof")
	}
	for _, change := range []func(*schemas.SessionReceipt){
		func(r *schemas.SessionReceipt) { r.Actions[0] = schemas.Reflect },
		func(r *schemas.SessionReceipt) { r.Deltas[0].DeltaMillis++ },
		func(r *schemas.SessionReceipt) { r.StartState.RootSeed++ },
		func(r *schemas.SessionReceipt) { r.StartState.InitialAxes["trust"]++ },
		func(r *schemas.SessionReceipt) {
			r.StartState.ManifestChecksum = "sha256:" + string(bytes.Repeat([]byte("0"), 64))
		},
		func(r *schemas.SessionReceipt) { r.StartState.Controllers.Focus = schemas.FocusWorkspace },
		func(r *schemas.SessionReceipt) { r.StartState.Loadout.SlotCap = 6 },
		func(r *schemas.SessionReceipt) {
			r.StartState.Library.OwnedCardIds = append(r.StartState.Library.OwnedCardIds, "reflect")
		},
		func(r *schemas.SessionReceipt) { r.Actions = r.Actions[:len(r.Actions)-1]; r.TurnCount-- },
		func(r *schemas.SessionReceipt) { r.LedgerEvents = []schemas.LedgerEvent{{AmountMicros: 100}} },
	} {
		_, altered := firstReceipt(t, b)
		change(&altered)
		if c.Match(id, altered) {
			t.Fatal("changed witness accepted")
		}
	}
	if _, ok := c.Select(start.CaseID, start.ManifestChecksum, receipt.RulesetVersion, start.Loadout.CardIds, nil, start.InitialAxes, start.Controllers); ok {
		t.Fatal("unowned proof selected")
	}
	revoked, err := Load(bytes.NewReader(b), digest(b), []string{id})
	if err != nil {
		t.Fatal(err)
	}
	if revoked.Match(id, receipt) {
		t.Fatal("revoked proof matched")
	}
	if _, ok := revoked.Select(start.CaseID, start.ManifestChecksum, receipt.RulesetVersion, start.Loadout.CardIds, owned, start.InitialAxes, start.Controllers); ok {
		t.Fatal("revoked proof selected")
	}
}

func TestArtifactPinTamperingAndStructuralRejection(t *testing.T) {
	b := fixture(t)
	for _, pin := range []string{"", string(bytes.Repeat([]byte("0"), 64)), "sha256:" + digest(b)} {
		if _, err := Load(bytes.NewReader(b), pin, nil); err == nil {
			t.Fatal("invalid artifact pin accepted")
		}
	}
	for name, mutate := range map[string]func(map[string]any){
		"unknown top field": func(a map[string]any) { a["unexpected"] = true },
		"wrong compiler":    func(a map[string]any) { a["build"].(map[string]any)["compiler_version"] = "future" },
		"wrong environment": func(a map[string]any) { a["build"].(map[string]any)["config_environment"] = "test" },
		"source traversal": func(a map[string]any) {
			a["build"].(map[string]any)["source_sha256"].(map[string]any)["../secret"] = digest(b)
		},
		"proof digest": func(a map[string]any) {
			a["proofs"].([]any)[0].(map[string]any)["proof_sha256"] = string(bytes.Repeat([]byte("0"), 64))
		},
		"duplicate proof": func(a map[string]any) { ps := a["proofs"].([]any); a["proofs"] = append(ps, ps[0]) },
	} {
		t.Run(name, func(t *testing.T) {
			var a map[string]any
			if err := json.Unmarshal(b, &a); err != nil {
				t.Fatal(err)
			}
			mutate(a)
			body, err := canonicaljson.Encode(a)
			if err != nil {
				t.Fatal(err)
			}
			if _, err := Load(bytes.NewReader(body), digest(body), nil); err == nil {
				t.Fatal("bad artifact accepted")
			}
		})
	}
	dup := bytes.Replace(b, []byte(`"artifact_schema_version":"1.0.0"`), []byte(`"artifact_schema_version":"0","artifact_schema_version":"1.0.0"`), 1)
	if _, err := Load(bytes.NewReader(dup), digest(dup), nil); err == nil {
		t.Fatal("duplicate JSON key accepted")
	}
	oversize := bytes.Repeat([]byte(" "), MaxArtifactBytes+1)
	if _, err := Load(bytes.NewReader(oversize), digest(oversize), nil); err == nil {
		t.Fatal("oversized artifact accepted")
	}
}

func TestRehashedUnsupportedProofsFailClosed(t *testing.T) {
	b := fixture(t)
	for name, mutate := range map[string]func(map[string]any){
		"unknown field":   func(p map[string]any) { p["future_authority"] = true },
		"missing field":   func(p map[string]any) { delete(p, "terminal") },
		"null start":      func(p map[string]any) { p["start_state"] = nil },
		"fractional seed": func(p map[string]any) { p["start_state"].(map[string]any)["root_seed"] = 0.5 },
		"overflow seed":   func(p map[string]any) { p["start_state"].(map[string]any)["root_seed"] = 1e30 },
		"unbounded actions": func(p map[string]any) {
			p["search"].(map[string]any)["limits"].(map[string]any)["max_actions"] = 100000
		},
		"oversized receipt":           func(p map[string]any) { p["wire_size_bounds"].(map[string]any)["canonical_receipt_bytes"] = 131073 },
		"incorrect measured receipt":  func(p map[string]any) { p["wire_size_bounds"].(map[string]any)["canonical_receipt_bytes"] = 100 },
		"incorrect measured envelope": func(p map[string]any) { p["wire_size_bounds"].(map[string]any)["signed_envelope_bytes"] = 200000 },
		"understated actual size": func(p map[string]any) {
			ds := p["deltas"].([]any)
			for len(ds) < 1024 {
				ds = append(ds, ds[0])
			}
			p["deltas"] = ds
		},
		"future axis": func(p map[string]any) { p["deltas"].([]any)[0].(map[string]any)["axis"] = "unknown" },
		"future controller": func(p map[string]any) {
			p["start_state"].(map[string]any)["controllers"].(map[string]any)["focus"] = "unknown"
		},
		"duplicate library": func(p map[string]any) {
			lib := p["start_state"].(map[string]any)["library"].(map[string]any)
			lib["owned_card_ids"] = []any{"open_question", "open_question"}
		},
		"prior progress": func(p map[string]any) {
			p["start_state"].(map[string]any)["initial_axes"].(map[string]any)["session_progress"] = 99
		},
		"not terminal":    func(p map[string]any) { p["terminal"].(map[string]any)["is_terminal"] = false },
		"crisis outcome":  func(p map[string]any) { p["terminal"].(map[string]any)["outcome"] = "crisis" },
		"different seed":  func(p map[string]any) { p["terminal"].(map[string]any)["state"].(map[string]any)["seed"] = 1730 },
		"missing balance": func(p map[string]any) { delete(p["effective_balance"].(map[string]any), "fit_buffer_trust") },
	} {
		t.Run(name, func(t *testing.T) {
			var a map[string]any
			if err := json.Unmarshal(b, &a); err != nil {
				t.Fatal(err)
			}
			r := a["proofs"].([]any)[0].(map[string]any)
			p := r["proof"].(map[string]any)
			mutate(p)
			proofBytes, err := canonicaljson.Encode(p)
			if err != nil {
				t.Fatal(err)
			}
			r["proof_sha256"] = digest(proofBytes)
			body, err := canonicaljson.Encode(a)
			if err != nil {
				t.Fatal(err)
			}
			if _, err := Load(bytes.NewReader(body), digest(body), nil); err == nil {
				t.Fatal("unsupported rehashed proof accepted")
			}
		})
	}
	dup := bytes.Replace(b, []byte(`"root_seed":1729`), []byte(`"root_seed":0,"root_seed":1729`), 1)
	if bytes.Equal(dup, b) {
		t.Fatal("nested duplicate fixture not planted")
	}
	if _, err := Load(bytes.NewReader(dup), digest(dup), nil); err == nil {
		t.Fatal("nested duplicate accepted")
	}
}
