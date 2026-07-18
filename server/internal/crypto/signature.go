// Package crypto implements the verify-in-place signature seam for the control
// plane (ADR-0006).
//
// The server verifies signatures over the exact received bytes. It never
// re-serializes or re-simulates to check. The suite id in the envelope selects
// the verification algorithm so the scheme can rotate.
package crypto

import (
	"crypto/ed25519"
	"errors"
	"fmt"

	"psychosims.dev/server/internal/api"
	"psychosims.dev/server/internal/schemas"
)

// SuiteID is a signature-suite identifier.
type SuiteID string

const (
	// SuiteEd25519V1 is the initial Ed25519 suite.
	SuiteEd25519V1 SuiteID = "ed25519-v1"
)

// Verifier verifies signed envelopes.
type Verifier struct {
	resolveKey func(signingKeyID string) (ed25519.PublicKey, error)
}

// NewVerifier builds a Verifier that looks up public keys by signing-key id.
func NewVerifier(resolveKey func(signingKeyID string) (ed25519.PublicKey, error)) *Verifier {
	return &Verifier{resolveKey: resolveKey}
}

// VerifyEnvelope checks the signature over the exact canonical receipt bytes
// using the suite id carried in the envelope. It returns an HTTPError so the
// caller can fail closed with the right taxonomy code.
func (v *Verifier) VerifyEnvelope(env schemas.SignedEnvelope) error {
	if len(env.CanonicalReceiptBytes) == 0 {
		return api.NewUserError(api.CodeInvalidSignature, "missing canonical receipt bytes")
	}
	if len(env.Signature) == 0 {
		return api.NewUserError(api.CodeInvalidSignature, "missing signature")
	}
	if env.SigningKeyID == "" {
		return api.NewUserError(api.CodeInvalidSignature, "missing signing key id")
	}

	switch SuiteID(env.SuiteID) {
	case SuiteEd25519V1:
		return v.verifyEd25519(env)
	case "":
		return api.NewUserError(api.CodeInvalidSignature, "missing suite id")
	default:
		return api.NewUserError(api.CodeInvalidSignature, fmt.Sprintf("unsupported suite id %q", env.SuiteID))
	}
}

func (v *Verifier) verifyEd25519(env schemas.SignedEnvelope) error {
	pub, err := v.resolveKey(env.SigningKeyID)
	if err != nil {
		if errors.Is(err, ErrKeyNotFound) {
			return api.NewUserError(api.CodeInvalidSignature, "unknown signing key")
		}
		return api.NewInternalError("key resolution failed: " + err.Error())
	}
	if len(pub) != ed25519.PublicKeySize {
		return api.NewUserError(api.CodeInvalidSignature, "invalid public key length")
	}
	if !ed25519.Verify(pub, env.CanonicalReceiptBytes, env.Signature) {
		return api.NewUserError(api.CodeInvalidSignature, "signature verification failed")
	}
	return nil
}

// ErrKeyNotFound is returned when a signing-key id cannot be resolved.
var ErrKeyNotFound = errors.New("signing key not found")

// GenerateTestKeypair returns a deterministic test keypair for unit tests.
// Never use these keys in production.
func GenerateTestKeypair() (ed25519.PublicKey, ed25519.PrivateKey) {
	seed := make([]byte, ed25519.SeedSize)
	for i := range seed {
		seed[i] = byte(i)
	}
	priv := ed25519.NewKeyFromSeed(seed)
	return priv.Public().(ed25519.PublicKey), priv
}
