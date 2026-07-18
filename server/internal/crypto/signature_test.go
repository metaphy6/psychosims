package crypto

import (
	"crypto/ed25519"
	"testing"

	"psychosims.dev/server/internal/api"
	"psychosims.dev/server/internal/schemas"
)

func TestVerifyEnvelopeValid(t *testing.T) {
	pub, priv := GenerateTestKeypair()
	receiptBytes := []byte(`{"id":"r1","schema_version":"0.3.0"}`)
	sig := ed25519.Sign(priv, receiptBytes)

	v := NewVerifier(func(keyID string) (ed25519.PublicKey, error) {
		if keyID == "key-1" {
			return pub, nil
		}
		return nil, ErrKeyNotFound
	})

	err := v.VerifyEnvelope(schemas.SignedEnvelope{
		CanonicalReceiptBytes: receiptBytes,
		Signature:             sig,
		SuiteID:               string(SuiteEd25519V1),
		SigningKeyID:          "key-1",
	})
	if err != nil {
		t.Fatalf("expected valid signature: %v", err)
	}
}

func TestVerifyEnvelopeBadSignature(t *testing.T) {
	pub, _ := GenerateTestKeypair()
	v := NewVerifier(func(string) (ed25519.PublicKey, error) { return pub, nil })

	err := v.VerifyEnvelope(schemas.SignedEnvelope{
		CanonicalReceiptBytes: []byte(`{"id":"r1"}`),
		Signature:             []byte("bad-signature"),
		SuiteID:               string(SuiteEd25519V1),
		SigningKeyID:          "key-1",
	})
	if err == nil {
		t.Fatal("expected verification failure")
	}
	he, ok := err.(api.HTTPError)
	if !ok {
		t.Fatalf("expected HTTPError, got %T", err)
	}
	if he.Body.Code != api.CodeInvalidSignature {
		t.Errorf("code = %q, want %q", he.Body.Code, api.CodeInvalidSignature)
	}
}

func TestVerifyEnvelopeUnknownKey(t *testing.T) {
	v := NewVerifier(func(string) (ed25519.PublicKey, error) { return nil, ErrKeyNotFound })

	err := v.VerifyEnvelope(schemas.SignedEnvelope{
		CanonicalReceiptBytes: []byte(`{"id":"r1"}`),
		Signature:             []byte("sig"),
		SuiteID:               string(SuiteEd25519V1),
		SigningKeyID:          "missing",
	})
	if err == nil {
		t.Fatal("expected unknown key error")
	}
}

func TestVerifyEnvelopeUnsupportedSuite(t *testing.T) {
	v := NewVerifier(func(string) (ed25519.PublicKey, error) { return nil, nil })

	err := v.VerifyEnvelope(schemas.SignedEnvelope{
		CanonicalReceiptBytes: []byte(`{"id":"r1"}`),
		Signature:             []byte("sig"),
		SuiteID:               "rsa-v1",
		SigningKeyID:          "key-1",
	})
	if err == nil {
		t.Fatal("expected unsupported suite error")
	}
}
