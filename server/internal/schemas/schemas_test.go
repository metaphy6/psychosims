package schemas

import (
	"encoding/json"
	"os"
	"path/filepath"
	"testing"
)

// fixtures resolves the repo-root test_fixtures directory relative to this
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
		t.Errorf("schemaVersion = %q, want %q", manifest.SchemaVersion, "0.1.0")
	}
	if manifest.RulesetVersion != "0.1.0" {
		t.Errorf("rulesetVersion = %q, want %q", manifest.RulesetVersion, "0.1.0")
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

	if receipt.PatientID != "fixture-p-001" {
		t.Errorf("patientId = %q, want %q", receipt.PatientID, "fixture-p-001")
	}
	if receipt.TurnCount != 3 {
		t.Errorf("turnCount = %d, want %d", receipt.TurnCount, 3)
	}
	if receipt.SchemaVersion != "0.1.0" {
		t.Errorf("schemaVersion = %q, want %q", receipt.SchemaVersion, "0.1.0")
	}
}
