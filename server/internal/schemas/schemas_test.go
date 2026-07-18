package schemas

import (
	"encoding/json"
	"os"
	"path/filepath"
	"reflect"
	"testing"
)

// fixturePath resolves the repo-root test_fixtures directory relative to this
// package (server/internal/schemas -> repo root is three parents up).
func fixturePath(t *testing.T, parts ...string) string {
	t.Helper()
	root := filepath.Join("..", "..", "..", "test_fixtures")
	return filepath.Join(append([]string{root}, parts...)...)
}

func TestPatientManifestRoundTrip(t *testing.T) {
	raw, err := os.ReadFile(fixturePath(t, "manifests", "sample_patient.json"))
	if err != nil {
		t.Fatalf("read fixture: %v", err)
	}

	var manifest PatientManifest
	if err := json.Unmarshal(raw, &manifest); err != nil {
		t.Fatalf("unmarshal manifest: %v", err)
	}

	if manifest.ID != "fixture-p-001" {
		t.Errorf("id = %q, want %q", manifest.ID, "fixture-p-001")
	}
	if manifest.SchemaVersion != "0.1.0" {
		t.Errorf("schema_version = %q, want %q", manifest.SchemaVersion, "0.1.0")
	}
	if manifest.RulesetVersion != "0.1.0" {
		t.Errorf("ruleset_version = %q, want %q", manifest.RulesetVersion, "0.1.0")
	}
	if manifest.NameKey != "manifests.fixture_p001.name" {
		t.Errorf("name_key = %q, want %q", manifest.NameKey, "manifests.fixture_p001.name")
	}
}

func TestSessionReceiptRoundTrip(t *testing.T) {
	raw, err := os.ReadFile(fixturePath(t, "receipts", "sample_receipt.json"))
	if err != nil {
		t.Fatalf("read fixture: %v", err)
	}

	var receipt SessionReceipt
	if err := json.Unmarshal(raw, &receipt); err != nil {
		t.Fatalf("unmarshal receipt: %v", err)
	}

	if receipt.ID != "fixture-receipt-001" {
		t.Errorf("id = %q, want %q", receipt.ID, "fixture-receipt-001")
	}
	if receipt.SchemaVersion != CurrentReceiptSchemaVersion {
		t.Errorf("schema_version = %q, want %q", receipt.SchemaVersion, CurrentReceiptSchemaVersion)
	}
	if receipt.RulesetVersion != "0.1.0" {
		t.Errorf("ruleset_version = %q, want %q", receipt.RulesetVersion, "0.1.0")
	}
	if receipt.PatientID != "fixture-p-001" {
		t.Errorf("patient_id = %q, want %q", receipt.PatientID, "fixture-p-001")
	}
	if receipt.IdempotencyKey != "idem-fixture-001" {
		t.Errorf("idempotency_key = %q, want %q", receipt.IdempotencyKey, "idem-fixture-001")
	}
	if receipt.CorrelationID != "corr-fixture-001" {
		t.Errorf("correlation_id = %q, want %q", receipt.CorrelationID, "corr-fixture-001")
	}
	if receipt.TurnCount != 3 {
		t.Errorf("turn_count = %d, want %d", receipt.TurnCount, 3)
	}

	wantLoadout := Loadout{CardIds: []string{"open_question", "validate", "reframe"}, SlotCap: 6}
	if !reflect.DeepEqual(receipt.StartState.Loadout, wantLoadout) {
		t.Errorf("start_state.loadout = %+v, want %+v", receipt.StartState.Loadout, wantLoadout)
	}

	if len(receipt.Actions) != 3 || receipt.Actions[0] != OpenQuestion || receipt.Actions[1] != Validate || receipt.Actions[2] != Reframe {
		t.Errorf("actions = %v, want [open_question validate reframe]", receipt.Actions)
	}

	if len(receipt.Deltas) != 2 {
		t.Fatalf("len(deltas) = %d, want 2", len(receipt.Deltas))
	}
	if receipt.Deltas[0].Axis != AxisTrust {
		t.Errorf("deltas[0].axis = %q, want %q", receipt.Deltas[0].Axis, AxisTrust)
	}
	if receipt.Deltas[0].DeltaMillis != 50 {
		t.Errorf("deltas[0].delta_millis = %d, want 50", receipt.Deltas[0].DeltaMillis)
	}

	if len(receipt.LedgerEvents) != 2 {
		t.Fatalf("len(ledger_events) = %d, want 2", len(receipt.LedgerEvents))
	}
	if receipt.LedgerEvents[0].Currency != CurrencyCash {
		t.Errorf("ledger_events[0].currency = %q, want %q", receipt.LedgerEvents[0].Currency, CurrencyCash)
	}
}

func TestSignedEnvelopeRoundTrip(t *testing.T) {
	env := SignedEnvelope{
		CanonicalReceiptBytes: []byte(`{"id":"r1","schema_version":"0.3.0"}`),
		Signature:             []byte("sig"),
		SuiteID:               "ed25519-v1",
		SigningKeyID:          "key-1",
	}

	b, err := json.Marshal(env)
	if err != nil {
		t.Fatalf("marshal: %v", err)
	}

	var got SignedEnvelope
	if err := json.Unmarshal(b, &got); err != nil {
		t.Fatalf("unmarshal: %v", err)
	}

	if !reflect.DeepEqual(got, env) {
		t.Errorf("round-trip = %+v, want %+v", got, env)
	}
}
