package receipts

import (
	"encoding/hex"
	"strings"

	"psychosims.dev/server/internal/api"
	"psychosims.dev/server/internal/schemas"
)

// validateStructuredFields defines the durable receipt vocabulary. Unknown
// additive JSON is projected out separately; supported fields must never be
// used as free-text or dialogue containers. Empty optional legacy metadata is
// allowed, and the complete start state is still bound to server authorization.
func validateStructuredFields(r schemas.SessionReceipt) error {
	invalid := func() error { return api.NewUserError(api.CodeBadRequest, "invalid structured receipt fields") }
	for _, id := range []string{r.ID, r.PatientID, r.IdempotencyKey, r.CorrelationID, r.RulesetVersion} {
		if !schemas.ValidIdentifier(id) {
			return invalid()
		}
	}
	start := r.StartState
	if start.CaseID != "" && !schemas.ValidIdentifier(start.CaseID) {
		return invalid()
	}
	if start.ManifestChecksum != "" {
		if !strings.HasPrefix(start.ManifestChecksum, "sha256:") || len(start.ManifestChecksum) != 71 {
			return invalid()
		}
		if _, err := hex.DecodeString(start.ManifestChecksum[7:]); err != nil {
			return invalid()
		}
	}
	if start.RootSeed < 0 || start.RootSeed > 2147483647 || start.Loadout.SlotCap < 1 || start.Loadout.SlotCap > 6 || len(start.Loadout.CardIds) > 6 || len(start.Library.OwnedCardIds) > 64 || len(start.InitialAxes) > 8 {
		return invalid()
	}
	for _, cards := range [][]string{start.Loadout.CardIds, start.Library.OwnedCardIds} {
		for _, card := range cards {
			if !schemas.ValidIdentifier(card) {
				return invalid()
			}
		}
	}
	switch start.Controllers.Focus {
	case "", schemas.FocusBalanced, schemas.FocusChildhood, schemas.FocusWorkspace:
	default:
		return invalid()
	}
	switch start.Controllers.EmotionalDelivery {
	case "", schemas.DeliveryBalanced, schemas.DeliveryWarm, schemas.DeliveryObjective:
	default:
		return invalid()
	}
	for axis, value := range start.InitialAxes {
		switch axis {
		case "trust", "agitation", "resistance", "trauma", "session_progress", "freeze_turns", "medication_tolerance", "medication_dependency", "activeDefense", "sessionProgress", "freezeTurns", "medicationTolerance", "medicationDependency":
		default:
			return invalid()
		}
		if value < 0 || value > 100 {
			return invalid()
		}
	}
	for _, action := range r.Actions {
		switch action {
		case schemas.OpenQuestion, schemas.Validate, schemas.Reframe, schemas.SetBoundary, schemas.Reflect, schemas.DiscloseParallel:
		default:
			return invalid()
		}
	}
	for _, d := range r.Deltas {
		if d.RulesetVersion != r.RulesetVersion || !schemas.ValidIdentifier(d.ReasonKey) {
			return invalid()
		}
		switch d.Axis {
		case schemas.AxisTrust, schemas.AxisAgitation, schemas.AxisActiveDefense, schemas.AxisTrauma, schemas.AxisFreezeTurns, schemas.AxisSessionProgress, schemas.AxisMedicationTolerance, schemas.AxisMedicationDependency:
		default:
			return invalid()
		}
		switch d.CardType {
		case schemas.CardTypeDisclosing, schemas.CardTypeRelatable, schemas.CardTypePostponing, schemas.CardTypeManipulative:
		default:
			return invalid()
		}
		switch d.CardSignature {
		case schemas.SignatureBreaker, schemas.SignatureBuffer, schemas.SignatureFreeze, schemas.SignatureGambit:
		default:
			return invalid()
		}
		switch d.ContextFit {
		case schemas.ContextFitAligned, schemas.ContextFitPartial, schemas.ContextFitMismatched:
		default:
			return invalid()
		}
	}
	return nil
}
