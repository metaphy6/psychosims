package schemas_test

import (
	"crypto/ed25519"
	"crypto/sha256"
	"encoding/hex"
	"encoding/json"
	"os"
	"testing"

	"psychosims.dev/server/internal/schemas"
)

func TestDartEd25519WireFixture(t *testing.T) {
	body, err := os.ReadFile("../../../test_fixtures/receipts/signed_ed25519_v1.json")
	if err != nil {
		t.Fatal(err)
	}
	var fixture struct {
		PublicKey []byte                 `json:"public_key"`
		WireHash  string                 `json:"wire_sha256"`
		Envelope  schemas.SignedEnvelope `json:"envelope"`
		Receipt   schemas.SessionReceipt `json:"receipt"`
	}
	if err := json.Unmarshal(body, &fixture); err != nil {
		t.Fatal(err)
	}
	env := fixture.Envelope
	digest := sha256.Sum256(env.CanonicalReceiptBytes)
	if hex.EncodeToString(digest[:]) != fixture.WireHash || !ed25519.Verify(fixture.PublicKey, env.CanonicalReceiptBytes, env.Signature) {
		t.Fatal("Dart wire bytes or signature do not match")
	}
	var receipt schemas.SessionReceipt
	if err := json.Unmarshal(env.CanonicalReceiptBytes, &receipt); err != nil {
		t.Fatal(err)
	}
	if receipt.ID != fixture.Receipt.ID || receipt.StartState.InitialAxes["trust"] != 40 || receipt.StartState.Loadout.CardIds[0] != "core.disclosing.breaker" || receipt.Actions[0] != schemas.OpenQuestion {
		t.Fatal("typed Dart receipt changed")
	}
	changed := append([]byte(nil), env.CanonicalReceiptBytes...)
	changed[0] ^= 1
	if ed25519.Verify(fixture.PublicKey, changed, env.Signature) {
		t.Fatal("altered wire accepted")
	}
	signature := append([]byte(nil), env.Signature...)
	signature[0] ^= 1
	if ed25519.Verify(fixture.PublicKey, env.CanonicalReceiptBytes, signature) {
		t.Fatal("altered signature accepted")
	}
}
