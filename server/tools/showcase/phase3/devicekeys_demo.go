package main

import (
	"context"
	"crypto/ed25519"
	"crypto/rand"
	"fmt"
	"time"

	"psychosims.dev/server/internal/crypto"
	"psychosims.dev/server/internal/devicekeys"
	"psychosims.dev/server/internal/timeutil"
)

func devicekeysDemo(path string) error {
	r := newReport("Device key rotation")
	r.line("This demo provisions a device key, rotates to a new suite, and builds a revocation list.")
	r.line("")

	ctx := context.Background()
	repo := devicekeys.NewInMemoryRepository()
	svc := devicekeys.NewService(repo)

	pubA, _ := crypto.GenerateTestKeypair()
	keyIDA, _ := svc.Provision(ctx, "acct-1", pubA, "ed25519-v1")
	r.h2("Initial key")
	r.code(fmt.Sprintf("key_id = %s\nsuite = ed25519-v1", keyIDA))

	pubB, _, _ := ed25519.GenerateKey(rand.Reader)
	policy := &devicekeys.RotationPolicy{
		Active:             "ed25519-v2",
		Previous:           "ed25519-v1",
		PreviousValidUntil: time.Now().UTC().Add(24 * time.Hour),
	}
	svc = svc.WithRotationPolicy(policy)
	keyIDB, revokedID, err := svc.Recover(ctx, "acct-1", pubB, "ed25519-v2", true)
	if err != nil {
		return err
	}

	r.h2("Rotation")
	r.code(fmt.Sprintf("new_key_id = %s\nrevoked_key_id = %s", keyIDB, revokedID))

	revoked, _ := repo.ListRevoked(ctx)
	r.h2("Revocation list")
	r.code(fmt.Sprintf("count = %d\nentries = %+v", len(revoked), revoked))

	rec, _ := repo.Lookup(ctx, keyIDB)
	r.h2("Verification")
	r.code(fmt.Sprintf("record valid = %v", svc.VerifyRecord(rec, timeutil.RealClock{}.Now())))

	return r.write(path)
}
