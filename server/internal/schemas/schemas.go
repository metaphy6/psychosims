// Package schemas mirrors the Dart `packages/psychemas/` contract.
//
// These structs are the Go side of the shared-schema strategy documented in
// docs/code/SHARED_SCHEMAS.md. Field JSON tags must stay byte-for-byte aligned
// with the Dart canonical serializer and the golden fixtures under
// test_fixtures/.
package schemas

// StructuredDelta is a single axis movement recorded during a session.
type StructuredDelta struct {
	Axis        string `json:"axis"`
	DeltaMillis int    `json:"deltaMillis"`
	ReasonKey   string `json:"reasonKey"`
}

// SessionReceipt is the authoritative record of a completed session turn set.
type SessionReceipt struct {
	ID             string           `json:"id"`
	SchemaVersion  string           `json:"schemaVersion"`
	RulesetVersion string           `json:"rulesetVersion"`
	PatientID      string           `json:"patientId"`
	TurnCount      int              `json:"turnCount"`
	Deltas         []map[string]any `json:"deltas"`
}

// PatientManifest describes a patient definition shared between client and
// server.
type PatientManifest struct {
	ID              string `json:"id"`
	SchemaVersion   string `json:"schemaVersion"`
	RulesetVersion  string `json:"rulesetVersion"`
	NameKey         string `json:"nameKey"`
	PresentationKey string `json:"presentationKey"`
}
