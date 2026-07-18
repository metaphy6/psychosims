package main

import (
	"context"
	"encoding/json"
	"fmt"

	"psychosims.dev/server/internal/identity"
)

func identityDemo(path string) error {
	r := newReport("Identity — PKCE + signed state")
	r.line("This demo shows the desktop OAuth state/nonce flow used by the identity package.")
	r.line("")

	cfg := identity.DefaultOAuthConfig()
	r.h2("OAuth config")
	data, _ := json.MarshalIndent(cfg, "", "  ")
	r.code(string(data))

	secret := []byte("demo-secret")
	svc := identity.NewServiceWithPKCE(identity.NewInMemoryRepository(), identity.NewInMemoryStateStore(), secret, cfg)

	state, nonce, err := svc.StartAuthSession(context.Background(), "google", "steam", "challenge123", "S256")
	if err != nil {
		return err
	}

	r.h2("Started auth session")
	r.line("- State: `%s...`", state[:16])
	r.line("- Nonce: `%s...`", nonce[:16])
	r.line("")

	verifiedNonce, err := svc.VerifyState(context.Background(), state, "challenge123")
	if err != nil {
		return err
	}
	r.h2("State verification")
	r.code(fmt.Sprintf("verified nonce = %s\nok = true", verifiedNonce))

	return r.write(path)
}
