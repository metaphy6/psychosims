// Package outcomes consumes an operator-pinned output of the trusted Dart
// compiler. It matches finite witnessed paths; it does not simulate gameplay or
// accept client-provided certificates. Source hashes are build provenance only.
package outcomes

import (
	"bytes"
	"crypto/sha256"
	"encoding/hex"
	"encoding/json"
	"errors"
	"io"
	"path"
	"reflect"
	"sort"
	"strings"

	"psychosims.dev/server/internal/canonicaljson"
	"psychosims.dev/server/internal/schemas"
)

const MaxArtifactBytes = 16 << 20
const compilerVersion = "psycore-outcome-v1"

type artifact struct {
	Schema string        `json:"artifact_schema_version"`
	Build  build         `json:"build"`
	Proofs []proofRecord `json:"proofs"`
}
type build struct {
	Compiler      string            `json:"compiler_version"`
	Environment   string            `json:"config_environment"`
	Sources       map[string]string `json:"source_sha256"`
	Specification string            `json:"specification_sha256"`
}
type proofRecord struct {
	Proof  proof  `json:"proof"`
	SHA256 string `json:"proof_sha256"`
}
type proof struct {
	Actions              []schemas.InteractionPattern `json:"actions"`
	CatalogVersion       string                       `json:"catalog_version"`
	CompilerVersion      string                       `json:"compiler_version"`
	Deltas               []schemas.StructuredDelta    `json:"deltas"`
	Balance              map[string]int               `json:"effective_balance"`
	Manifest             manifest                     `json:"manifest"`
	Schema               string                       `json:"proof_schema_version"`
	ReceiptSchemaVersion string                       `json:"receipt_schema_version"`
	Search               search                       `json:"search"`
	StartState           schemas.SessionStartState    `json:"start_state"`
	Terminal             terminal                     `json:"terminal"`
	TurnCount            int                          `json:"turn_count"`
	Wire                 wire                         `json:"wire_size_bounds"`
}
type manifest struct {
	Checksum       string `json:"content_checksum"`
	ID             string `json:"id"`
	RulesetVersion string `json:"ruleset_version"`
	Schema         string `json:"schema_version"`
}
type search struct {
	Explored int `json:"explored_transitions"`
	Limits   struct {
		Actions      int `json:"max_actions"`
		Deltas       int `json:"max_deltas"`
		ProofBytes   int `json:"max_proof_bytes"`
		ReceiptBytes int `json:"max_receipt_bytes"`
		Transitions  int `json:"max_transitions"`
	} `json:"limits"`
}
type terminal struct {
	IsTerminal bool   `json:"is_terminal"`
	Lifecycle  string `json:"lifecycle"`
	Outcome    string `json:"outcome"`
	State      struct {
		Defense    string `json:"active_defense"`
		Agitation  int    `json:"agitation_level"`
		Freeze     int    `json:"freeze_turns"`
		Medication struct {
			Dependency int     `json:"dependency"`
			Dosage     int     `json:"dosage"`
			Drug       *string `json:"drug"`
			Tolerance  int     `json:"tolerance"`
		} `json:"medication"`
		Seed     int `json:"seed"`
		Progress int `json:"session_progress"`
		Trauma   int `json:"trauma"`
		Trust    int `json:"trust_score"`
		Turn     int `json:"turn"`
	} `json:"state"`
}
type wire struct {
	ReceiptBytes   int `json:"canonical_receipt_bytes"`
	ReceiptIDBytes int `json:"receipt_identifier_max_bytes"`
	EnvelopeBytes  int `json:"signed_envelope_bytes"`
	KeyIDBytes     int `json:"signing_key_identifier_max_bytes"`
}

// Permit is a detached snapshot. Integration must persist ProofID with the
// authenticated account/patient/start authorization, and recheck Match at commit.
type Permit struct {
	ProofID        string
	CatalogVersion string
	RulesetVersion string
	StartState     schemas.SessionStartState
}
type Catalog struct {
	artifactSHA256 string
	proofs         map[string]proof
	ids            []string
	revoked        map[string]bool
}

func (c *Catalog) ArtifactSHA256() string { return c.artifactSHA256 }

// Load requires the exact approved artifact SHA256, including its final newline.
// The explicit artifact pin authorizes its proofs except the supplied revocations.
// Only the compiler's canonical JSON form is supported: round-trip equality
// rejects duplicate keys, unknown/missing fields, case aliases and lossy numbers.
func Load(r io.Reader, expectedSHA256 string, revoked []string) (*Catalog, error) {
	if !validHash(expectedSHA256) {
		return nil, errors.New("outcome artifact pin required")
	}
	body, err := io.ReadAll(io.LimitReader(r, MaxArtifactBytes+1))
	if err != nil || len(body) > MaxArtifactBytes {
		return nil, errors.New("outcome artifact unreadable or oversized")
	}
	hash := sha256.Sum256(body)
	if hex.EncodeToString(hash[:]) != expectedSHA256 {
		return nil, errors.New("outcome artifact pin mismatch")
	}
	var a artifact
	if err = json.Unmarshal(body, &a); err != nil {
		return nil, errors.New("invalid outcome artifact JSON")
	}
	canonical, err := canonicaljson.Marshal(a)
	if err != nil || !bytes.Equal(bytes.TrimSpace(body), canonical) {
		return nil, errors.New("outcome artifact must have exact canonical fields")
	}
	if a.Schema != "1.0.0" || a.Build.Compiler != compilerVersion || a.Build.Environment != "prod" || !validHash(a.Build.Specification) || len(a.Proofs) < 1 || len(a.Proofs) > 64 || len(a.Build.Sources) < 1 || len(a.Build.Sources) > 2048 {
		return nil, errors.New("unsupported outcome artifact metadata")
	}
	for source, hash := range a.Build.Sources {
		if len(source) > 256 || path.IsAbs(source) || path.Clean(source) != source || source == "." || source == ".." || strings.HasPrefix(source, "../") || strings.ContainsAny(source, "\\\x00\r\n") || !validHash(hash) {
			return nil, errors.New("invalid outcome source provenance")
		}
	}
	c := &Catalog{artifactSHA256: expectedSHA256, proofs: map[string]proof{}, revoked: map[string]bool{}}
	if len(revoked) > 4096 {
		return nil, errors.New("too many outcome revocations")
	}
	for _, id := range revoked {
		if !validHash(id) {
			return nil, errors.New("invalid outcome revocation")
		}
		c.revoked[id] = true
	}
	for _, record := range a.Proofs {
		p := record.Proof
		b, err := canonicaljson.Marshal(p)
		if err != nil {
			return nil, err
		}
		hash := sha256.Sum256(b)
		if !validHash(record.SHA256) || record.SHA256 != hex.EncodeToString(hash[:]) {
			return nil, errors.New("outcome proof digest mismatch")
		}
		if _, ok := c.proofs[record.SHA256]; ok {
			return nil, errors.New("duplicate outcome proof")
		}
		if err = p.validate(len(b)); err != nil {
			return nil, err
		}
		c.proofs[record.SHA256] = p
		c.ids = append(c.ids, record.SHA256)
	}
	sort.Strings(c.ids)
	return c, nil
}

func validHash(s string) bool {
	if len(s) != 64 {
		return false
	}
	for _, ch := range s {
		if !((ch >= '0' && ch <= '9') || (ch >= 'a' && ch <= 'f')) {
			return false
		}
	}
	return true
}
func validChecksum(s string) bool {
	return strings.HasPrefix(s, "sha256:") && validHash(strings.TrimPrefix(s, "sha256:"))
}
func allowed(s string, values ...string) bool {
	for _, v := range values {
		if s == v {
			return true
		}
	}
	return false
}
func validCard(s string) bool {
	return allowed(s, "open_question", "validate", "reframe", "set_boundary", "reflect", "disclose_parallel")
}

var balanceFields = strings.Fields("active_card_slots calm_threshold crisis_threshold dependency_per_dose fit_breaker_resistance fit_buffer_agitation fit_buffer_trust fit_freeze_agitation fit_gambit_trust manipulative_partial_trust manipulative_success_trust medication_agitation_shift postponing_decay_max postponing_decay_per_session postponing_freeze_turns stable_trust_floor success_progress_threshold tolerance_per_dose transference_spike_agitation transference_spike_trauma walkout_threshold")

func (p proof) validate(size int) error {
	invalid := errors.New("unsupported or inconsistent outcome proof")
	s := p.StartState
	l := p.Search.Limits
	if p.Schema != "1.0.0" || p.CompilerVersion != compilerVersion || p.ReceiptSchemaVersion != schemas.CurrentReceiptSchemaVersion || p.Manifest.Schema != "1.0.0" || !schemas.ValidIdentifier(p.Manifest.ID) || !schemas.ValidIdentifier(p.Manifest.RulesetVersion) || !schemas.ValidIdentifier(p.CatalogVersion) || !validChecksum(p.Manifest.Checksum) || s.CaseID != p.Manifest.ID || s.ManifestChecksum != p.Manifest.Checksum {
		return invalid
	}
	if len(p.Balance) != len(balanceFields) {
		return invalid
	}
	for _, key := range balanceFields {
		v, ok := p.Balance[key]
		if !ok || v < 0 || v > 100 {
			return invalid
		}
	}
	if p.Balance["active_card_slots"] < 1 || p.Balance["active_card_slots"] > 6 || p.Balance["success_progress_threshold"] == 0 {
		return invalid
	}
	if l.Actions < 1 || l.Actions > schemas.MaxReceiptActions || l.Deltas < 1 || l.Deltas > schemas.MaxReceiptDeltas || l.ReceiptBytes < 1 || l.ReceiptBytes > schemas.MaxCanonicalReceiptBytes || l.ProofBytes < 1 || l.ProofBytes > 262144 || size > l.ProofBytes || l.Transitions < 1 || l.Transitions > 100000 || p.Search.Explored < 1 || p.Search.Explored > l.Transitions {
		return invalid
	}
	if p.TurnCount != len(p.Actions) || p.TurnCount < 1 || p.TurnCount > l.Actions || len(p.Deltas) < 1 || len(p.Deltas) > l.Deltas {
		return invalid
	}
	if s.RootSeed < 0 || s.RootSeed > 2147483647 || len(s.InitialAxes) > 6 || s.InitialAxes == nil || s.InitialAxes["session_progress"] != 0 || s.InitialAxes["agitation"] >= p.Balance["walkout_threshold"] {
		return invalid
	}
	for axis, v := range s.InitialAxes {
		if !allowed(axis, "trust", "agitation", "resistance", "trauma", "freeze_turns", "session_progress") || v < 0 || v > 100 {
			return invalid
		}
	}
	if !allowed(string(s.Controllers.Focus), "childhood", "balanced", "workspace") || !allowed(string(s.Controllers.EmotionalDelivery), "warm", "balanced", "objective") {
		return invalid
	}
	if len(s.Loadout.CardIds) < 1 || s.Loadout.SlotCap < 1 || s.Loadout.SlotCap > 6 || len(s.Loadout.CardIds) > s.Loadout.SlotCap || len(s.Loadout.CardIds) > p.Balance["active_card_slots"] || len(s.Library.OwnedCardIds) < 1 || len(s.Library.OwnedCardIds) > 64 {
		return invalid
	}
	owned := map[string]bool{}
	last := ""
	for _, id := range s.Library.OwnedCardIds {
		if !schemas.ValidIdentifier(id) || id <= last {
			return invalid
		}
		owned[id] = true
		last = id
	}
	equipped := map[string]bool{}
	for _, id := range s.Loadout.CardIds {
		if !validCard(id) || !owned[id] || equipped[id] {
			return invalid
		}
		equipped[id] = true
	}
	for _, action := range p.Actions {
		if !equipped[string(action)] {
			return invalid
		}
	}
	for _, d := range p.Deltas {
		if d.RulesetVersion != p.Manifest.RulesetVersion || !schemas.ValidIdentifier(d.ReasonKey) || d.DeltaMillis < -1000 || d.DeltaMillis > 1000 || !allowed(string(d.Axis), "trust", "agitation", "activeDefense", "trauma", "freezeTurns", "sessionProgress", "medicationTolerance", "medicationDependency") || !allowed(string(d.CardType), "disclosing", "relatable", "postponing", "manipulative") || !allowed(string(d.CardSignature), "breaker", "buffer", "freeze", "gambit") || !allowed(string(d.ContextFit), "aligned", "partial", "mismatched") {
			return invalid
		}
	}
	t := p.Terminal
	if !t.IsTerminal || t.Lifecycle != "cured" || t.Outcome != "succeed" || t.State.Turn != p.TurnCount || t.State.Seed != s.RootSeed || t.State.Progress < p.Balance["success_progress_threshold"] || t.State.Agitation >= p.Balance["crisis_threshold"] || !allowed(t.State.Defense, "none", "guarded", "rigid") {
		return invalid
	}
	for _, v := range []int{t.State.Agitation, t.State.Freeze, t.State.Progress, t.State.Trauma, t.State.Trust, t.State.Medication.Dependency, t.State.Medication.Dosage, t.State.Medication.Tolerance} {
		if v < 0 || v > 100 {
			return invalid
		}
	}
	if t.State.Medication.Drug != nil && !allowed(*t.State.Medication.Drug, "ferveAxine", "torpidol", "quiescetine", "vexanil", "dormisal") {
		return invalid
	}
	if p.Wire.ReceiptIDBytes != 128 || p.Wire.KeyIDBytes != 256 || p.Wire.ReceiptBytes < 1 || p.Wire.ReceiptBytes > l.ReceiptBytes || p.Wire.EnvelopeBytes < p.Wire.ReceiptBytes || p.Wire.EnvelopeBytes > 2*schemas.MaxCanonicalReceiptBytes {
		return invalid
	}
	// Measure the compiler's actual maximum-identifier wire shape; declarations
	// alone cannot establish that the proof is usable by a bounded client/server.
	longID := strings.Repeat("x", 128)
	r := schemas.SessionReceipt{ID: longID, PatientID: longID, IdempotencyKey: longID, CorrelationID: longID, SchemaVersion: p.ReceiptSchemaVersion, RulesetVersion: p.Manifest.RulesetVersion, TurnCount: p.TurnCount, StartState: s, Actions: p.Actions, Deltas: p.Deltas}
	standard, err := json.Marshal(r)
	if err != nil {
		return invalid
	}
	var graph map[string]any
	if err = json.Unmarshal(standard, &graph); err != nil {
		return invalid
	}
	// Dart SessionReceipt omits its optional ledger_events when empty.
	delete(graph, "ledger_events")
	receiptBytes, err := canonicaljson.Encode(graph)
	if err != nil || len(receiptBytes) != p.Wire.ReceiptBytes || len(receiptBytes) > l.ReceiptBytes {
		return invalid
	}
	envelopeBytes, err := canonicaljson.Marshal(schemas.SignedEnvelope{CanonicalReceiptBytes: receiptBytes, Signature: make([]byte, 64), SuiteID: "ed25519-v1", SigningKeyID: strings.Repeat("x", 256)})
	if err != nil || len(envelopeBytes) != p.Wire.EnvelopeBytes {
		return invalid
	}
	return nil
}

// Select chooses a stable proof for an ordered loadout whose complete certified
// library is owned. Additional account inventory is deliberately excluded from
// the permitted simulation snapshot. The compiler chooses the exact seed.
func (c *Catalog) Select(caseID, checksum, ruleset string, cards, owned []string, axes map[string]int, controllers schemas.TherapyControllerSettings) (Permit, bool) {
	if c == nil {
		return Permit{}, false
	}
	ownership := map[string]bool{}
	for _, id := range owned {
		ownership[id] = true
	}
	for _, id := range c.ids {
		p := c.proofs[id]
		if c.revoked[id] || p.Manifest.ID != caseID || p.Manifest.Checksum != checksum || p.Manifest.RulesetVersion != ruleset || !reflect.DeepEqual(p.StartState.Loadout.CardIds, cards) || !reflect.DeepEqual(p.StartState.InitialAxes, axes) || p.StartState.Controllers != controllers {
			continue
		}
		entitled := true
		for _, card := range p.StartState.Library.OwnedCardIds {
			if !ownership[card] {
				entitled = false
				break
			}
		}
		if !entitled {
			continue
		}
		start := cloneStart(p.StartState)
		return Permit{ProofID: id, CatalogVersion: p.CatalogVersion, RulesetVersion: ruleset, StartState: start}, true
	}
	return Permit{}, false
}
func cloneStart(s schemas.SessionStartState) schemas.SessionStartState {
	s.Loadout.CardIds = append([]string{}, s.Loadout.CardIds...)
	s.Library.OwnedCardIds = append([]string{}, s.Library.OwnedCardIds...)
	axes := map[string]int{}
	for k, v := range s.InitialAxes {
		axes[k] = v
	}
	s.InitialAxes = axes
	return s
}

// Match compares every supported deterministic input and output field. Device
// signatures, account/lease ownership and permit pinning are enforced separately.
func (c *Catalog) Match(id string, r schemas.SessionReceipt) bool {
	if c == nil || c.revoked[id] {
		return false
	}
	p, ok := c.proofs[id]
	return ok && r.SchemaVersion == p.ReceiptSchemaVersion && r.RulesetVersion == p.Manifest.RulesetVersion && r.TurnCount == p.TurnCount && len(r.LedgerEvents) == 0 && reflect.DeepEqual(r.StartState, p.StartState) && reflect.DeepEqual(r.Actions, p.Actions) && reflect.DeepEqual(r.Deltas, p.Deltas)
}
