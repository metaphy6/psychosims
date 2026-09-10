// Package schemas mirrors the Dart `packages/psychemas/` contract.
//
// These structs are the Go side of the shared-schema strategy documented in
// docs/code/SHARED_SCHEMAS.md. Field JSON tags use snake_case to match the
// Dart CanonicalJson encoder byte-for-byte. All exported types are pure data
// containers so the contract test can round-trip them against the Dart
// canonical bytes.
package schemas

// Protocol count caps cover the bounded core's full 120-turn horizon.
// Keep in sync with receipt.schema.json and the Dart configuration authority.
const MaxReceiptActions = 120
const MaxReceiptDeltas = 1024
const MaxCanonicalReceiptBytes = 131072
const MaxReceiptBatchBytes = 524288

// InteractionPattern is the core-facing action played during a session.
// Player-facing names are localization keys; this enum is never shown raw.
type InteractionPattern string

const (
	OpenQuestion     InteractionPattern = "open_question"
	Validate         InteractionPattern = "validate"
	Reframe          InteractionPattern = "reframe"
	SetBoundary      InteractionPattern = "set_boundary"
	Reflect          InteractionPattern = "reflect"
	DiscloseParallel InteractionPattern = "disclose_parallel"
)

// StateAxis is a typed state variable that a StructuredDelta can mutate.
type StateAxis string

const (
	AxisTrust                StateAxis = "trust"
	AxisAgitation            StateAxis = "agitation"
	AxisActiveDefense        StateAxis = "activeDefense"
	AxisTrauma               StateAxis = "trauma"
	AxisFreezeTurns          StateAxis = "freezeTurns"
	AxisSessionProgress      StateAxis = "sessionProgress"
	AxisMedicationTolerance  StateAxis = "medicationTolerance"
	AxisMedicationDependency StateAxis = "medicationDependency"
)

// CardType is the tactical role of a card.
type CardType string

const (
	CardTypeDisclosing   CardType = "disclosing"
	CardTypeRelatable    CardType = "relatable"
	CardTypePostponing   CardType = "postponing"
	CardTypeManipulative CardType = "manipulative"
)

// CardSignature is the context-fit hint for a card.
type CardSignature string

const (
	SignatureBreaker CardSignature = "breaker"
	SignatureBuffer  CardSignature = "buffer"
	SignatureFreeze  CardSignature = "freeze"
	SignatureGambit  CardSignature = "gambit"
)

// ContextFit is the computed context-fit band for a card play.
type ContextFit string

const (
	ContextFitAligned    ContextFit = "aligned"
	ContextFitPartial    ContextFit = "partial"
	ContextFitMismatched ContextFit = "mismatched"
)

// CurrencyType is a career currency token.
type CurrencyType string

const (
	CurrencyCash         CurrencyType = "cash"
	CurrencyStudy        CurrencyType = "study"
	CurrencySubspecialty CurrencyType = "subspecialty"
	CurrencyXP           CurrencyType = "xp"
	CurrencyReputation   CurrencyType = "reputation"
	CurrencyPrestige     CurrencyType = "prestige"
)

// Loadout is the capped active loadout a player brings into a session.
type Loadout struct {
	CardIds []string `json:"card_ids"`
	SlotCap int      `json:"slot_cap"`
}

// CardLibrary is a player's owned/unlocked card collection.
type CardLibrary struct {
	OwnedCardIds []string `json:"owned_card_ids"`
}

// FocusAxis is the Childhood ↔ Workspace slider.
type FocusAxis string

const (
	FocusChildhood FocusAxis = "childhood"
	FocusBalanced  FocusAxis = "balanced"
	FocusWorkspace FocusAxis = "workspace"
)

// EmotionalDelivery is the Warm ↔ Objective slider.
type EmotionalDelivery string

const (
	DeliveryWarm      EmotionalDelivery = "warm"
	DeliveryBalanced  EmotionalDelivery = "balanced"
	DeliveryObjective EmotionalDelivery = "objective"
)

// TherapyControllerSettings captures the pre-session controller sliders.
type TherapyControllerSettings struct {
	Focus             FocusAxis         `json:"focus"`
	EmotionalDelivery EmotionalDelivery `json:"emotional_delivery"`
}

// SessionStartState is the immutable snapshot that defines a session's starting
// conditions. It is bound to the receipt so the server can validate that every
// action references cards the player actually owns.
type SessionStartState struct {
	CaseID           string                    `json:"case_id,omitempty"`
	ManifestChecksum string                    `json:"manifest_checksum,omitempty"`
	Loadout          Loadout                   `json:"loadout"`
	Library          CardLibrary               `json:"library"`
	Controllers      TherapyControllerSettings `json:"controllers"`
	InitialAxes      map[string]int            `json:"initial_axes"`
	RootSeed         int                       `json:"root_seed"`
}

// StructuredDelta is a single structured, deterministic state-axis movement.
type StructuredDelta struct {
	RulesetVersion string        `json:"ruleset_version"`
	Axis           StateAxis     `json:"axis"`
	DeltaMillis    int           `json:"delta_millis"`
	ReasonKey      string        `json:"reason_key"`
	CardType       CardType      `json:"card_type"`
	CardSignature  CardSignature `json:"card_signature"`
	ContextFit     ContextFit    `json:"context_fit"`
}

// LedgerEvent is a single append-only, idempotent economy mutation.
type LedgerEvent struct {
	Kind             string       `json:"kind"`
	IdempotencyKey   string       `json:"idempotency_key"`
	TimestampSeconds int          `json:"timestamp_seconds"`
	Currency         CurrencyType `json:"currency"`
	AmountMicros     int          `json:"amount_micros"`
	ReasonKey        string       `json:"reason_key"`
}

// SessionReceipt is the authoritative record of a completed session turn set.
// It matches the Dart packages/psychemas/lib/src/receipt.dart schema 0.3.0
// exactly, including the additive LedgerEvent list.
type SessionReceipt struct {
	ID             string               `json:"id"`
	SchemaVersion  string               `json:"schema_version"`
	RulesetVersion string               `json:"ruleset_version"`
	PatientID      string               `json:"patient_id"`
	IdempotencyKey string               `json:"idempotency_key"`
	CorrelationID  string               `json:"correlation_id"`
	TurnCount      int                  `json:"turn_count"`
	StartState     SessionStartState    `json:"start_state"`
	Actions        []InteractionPattern `json:"actions"`
	Deltas         []StructuredDelta    `json:"deltas"`
	LedgerEvents   []LedgerEvent        `json:"ledger_events"`
}

// SignedEnvelope is the additive transport wrapper around a canonical receipt.
// It carries the exact canonical receipt bytes that were signed, the detached
// signature, the signature suite id, and the signing-key id. This is the single
// producer/consumer contract for client signing (3.5) and server verification
// (3.3).
type SignedEnvelope struct {
	CanonicalReceiptBytes []byte `json:"canonical_receipt_bytes"`
	Signature             []byte `json:"signature"`
	SuiteID               string `json:"suite_id"`
	SigningKeyID          string `json:"signing_key_id"`
}

// PatientManifest describes a patient definition shared between client and
// server.
type PatientManifest struct {
	ID              string `json:"id"`
	SchemaVersion   string `json:"schema_version"`
	RulesetVersion  string `json:"ruleset_version"`
	NameKey         string `json:"name_key"`
	PresentationKey string `json:"presentation_key"`
}

// CurrentReceiptSchemaVersion is the schema version the server expects for
// incoming receipts.
const CurrentReceiptSchemaVersion = "0.3.0"

// ValidIdentifier bounds opaque protocol identifiers to printable identifier
// syntax. They are never general prose fields or transcript storage.
func ValidIdentifier(value string) bool {
	if len(value) == 0 || len(value) > 128 {
		return false
	}
	for _, c := range []byte(value) {
		if !((c >= 'a' && c <= 'z') || (c >= 'A' && c <= 'Z') || (c >= '0' && c <= '9') || c == '_' || c == '-' || c == '.' || c == ':') {
			return false
		}
	}
	return true
}
