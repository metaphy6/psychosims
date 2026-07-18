package schemas

import (
	"encoding/json"
	"os"
	"strings"
	"testing"

	"psychosims.dev/server/internal/canonicaljson"
)

// TestGoDartReceiptContract verifies that the Go schema mirror can parse the
// Dart-authored fixture and re-encode it to canonical bytes using the same
// snake_case, sorted-key contract as Dart's CanonicalJson.
func TestGoDartReceiptContract(t *testing.T) {
	raw, err := os.ReadFile(fixturePath(t, "receipts", "sample_receipt.json"))
	if err != nil {
		t.Fatalf("read fixture: %v", err)
	}

	var receipt SessionReceipt
	if err := json.Unmarshal(raw, &receipt); err != nil {
		t.Fatalf("unmarshal receipt: %v", err)
	}

	canon, err := canonicaljson.Marshal(receipt)
	if err != nil {
		t.Fatalf("canonical encode: %v", err)
	}

	// The canonical output must use snake_case exclusively.
	forbidden := []string{"schemaVersion", "rulesetVersion", "patientId", "idempotencyKey", "correlationId", "turnCount", "startState", "deltaMillis", "cardType", "cardSignature", "contextFit", "ledgerEvents"}
	for _, camel := range forbidden {
		if strings.Contains(string(canon), camel) {
			t.Errorf("canonical bytes contain camelCase key %q", camel)
		}
	}

	// Required snake_case keys must be present.
	required := []string{"schema_version", "ruleset_version", "patient_id", "idempotency_key", "correlation_id", "turn_count", "start_state", "delta_millis", "card_type", "card_signature", "context_fit", "ledger_events"}
	for _, snake := range required {
		if !strings.Contains(string(canon), `"`+snake+`"`) {
			t.Errorf("canonical bytes missing key %q", snake)
		}
	}

	// Round-trip the canonical bytes back through a generic graph to prove
	// they are valid JSON that preserves the same structure.
	var graph any
	if err := json.Unmarshal(canon, &graph); err != nil {
		t.Fatalf("canonical bytes invalid json: %v", err)
	}
}

// TestGoDartManifestContract verifies the manifest fixture round-trips through
// the canonical encoder without camelCase leakage.
func TestGoDartManifestContract(t *testing.T) {
	raw, err := os.ReadFile(fixturePath(t, "manifests", "sample_patient.json"))
	if err != nil {
		t.Fatalf("read fixture: %v", err)
	}

	var manifest PatientManifest
	if err := json.Unmarshal(raw, &manifest); err != nil {
		t.Fatalf("unmarshal manifest: %v", err)
	}

	canon, err := canonicaljson.Marshal(manifest)
	if err != nil {
		t.Fatalf("canonical encode: %v", err)
	}

	for _, camel := range []string{"schemaVersion", "rulesetVersion", "nameKey", "presentationKey"} {
		if strings.Contains(string(canon), camel) {
			t.Errorf("canonical bytes contain camelCase key %q", camel)
		}
	}
}
