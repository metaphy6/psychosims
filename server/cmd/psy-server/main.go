// Command psy-server runs the Psychosims authoritative control plane.
package main

import (
	"context"
	"crypto/hmac"
	"crypto/sha256"
	"errors"
	"fmt"
	"net"
	"net/http"
	"os"
	"os/signal"
	"strings"
	"syscall"
	"time"

	"psychosims.dev/server/internal/config"
	"psychosims.dev/server/internal/identity"
	"psychosims.dev/server/internal/outcomes"
	"psychosims.dev/server/internal/psylog"
	"psychosims.dev/server/internal/server"
	"psychosims.dev/server/internal/store"
	"psychosims.dev/server/internal/tokens"
)

func main() {
	ctx, stop := signal.NotifyContext(context.Background(), syscall.SIGTERM, syscall.SIGINT)
	defer stop()
	if err := run(ctx, config.Default()); err != nil {
		psylog.Default().Error("server", "startup_or_runtime_failure", psylog.KV{"error": err.Error()})
		os.Exit(1)
	}
}
func readSecret(path string, required bool) ([]byte, error) {
	if path == "" && !required {
		return nil, nil
	}
	info, err := os.Stat(path)
	if err != nil {
		return nil, errors.New("secret file unavailable")
	}
	if !info.Mode().IsRegular() || info.Size() > 16384 || info.Mode().Perm()&0077 != 0 {
		return nil, errors.New("secret file must be a private regular file (0600)")
	}
	b, err := os.ReadFile(path)
	if err != nil {
		return nil, errors.New("secret file unreadable")
	}
	b = []byte(strings.TrimSpace(string(b)))
	if len(b) < 32 {
		return nil, errors.New("secret must contain at least 32 bytes")
	}
	return b, nil
}
func deriveKey(secret []byte, label string) []byte {
	m := hmac.New(sha256.New, secret)
	m.Write([]byte("psychosims/v1/" + label))
	return m.Sum(nil)
}
func run(ctx context.Context, cfg *config.Config) error {
	if err := cfg.ValidateRuntime(); err != nil {
		return err
	}
	secret, err := readSecret(cfg.TokenSecretFile, true)
	if err != nil {
		return err
	}
	catalog, err := server.LoadCatalog(cfg.CatalogManifestPaths)
	if err != nil {
		return err
	}
	if cfg.OutcomeCatalogPath != "" {
		f, err := os.Open(cfg.OutcomeCatalogPath)
		if err != nil {
			return errors.New("trusted outcome artifact unavailable")
		}
		info, err := f.Stat()
		if err != nil || !info.Mode().IsRegular() {
			f.Close()
			return errors.New("trusted outcome artifact must be a regular file")
		}
		proofs, err := outcomes.Load(f, cfg.OutcomeCatalogSHA256, cfg.OutcomeRevokedProofIDs)
		f.Close()
		if err != nil {
			return err
		}
		catalog = catalog.WithOutcomes(proofs)
	}
	startup, cancel := context.WithTimeout(ctx, 15*time.Second)
	defer cancel()
	st, err := store.New(startup, cfg)
	if err != nil {
		return errors.New("database initialization failed")
	}
	defer st.Close()
	redirects := map[string]string{}
	for channel, uri := range cfg.OAuthRedirects {
		if uri != "" {
			redirects[channel] = uri
		}
	}
	ids := identity.NewServiceWithPKCE(identity.NewSQLRepository(st.DB()), identity.NewSQLStateStore(st.DB()), deriveKey(secret, "oauth-state"), identity.OAuthConfig{DesktopRedirectURIs: redirects, PKCEEnabled: true})
	// Endpoints are from official provider metadata, never an HTTP request.
	providers := []identity.OIDCConfig{
		{Provider: "google", ClientID: cfg.GoogleClientID, Issuer: "https://accounts.google.com", JWKSURL: "https://www.googleapis.com/oauth2/v3/certs", AuthorizationURL: "https://accounts.google.com/o/oauth2/v2/auth", TokenURL: "https://oauth2.googleapis.com/token"},
		{Provider: "apple", ClientID: cfg.AppleClientID, Issuer: "https://appleid.apple.com", JWKSURL: "https://appleid.apple.com/auth/keys", AuthorizationURL: "https://appleid.apple.com/auth/authorize", TokenURL: "https://appleid.apple.com/auth/token"},
	}
	for _, p := range providers {
		if p.ClientID == "" {
			continue
		}
		secretPath := cfg.GoogleClientSecretFile
		if p.Provider == "apple" {
			secretPath = cfg.AppleClientSecretFile
		}
		clientSecret, err := readSecret(secretPath, false)
		if err != nil {
			return err
		}
		p.ClientSecret = string(clientSecret)
		verifier, err := identity.NewOIDCProvider(p, nil)
		if err != nil {
			return err
		}
		ids.RegisterProvider(p.Provider, verifier)
	}
	app := server.NewOnline(cfg, st.DB(), ids, tokens.NewSQLManager(st.DB(), deriveKey(secret, "session-token"), cfg.AccessTokenTTL, cfg.RefreshTokenTTL), catalog, deriveKey(secret, "case-seed"))
	listener, err := net.Listen("tcp", cfg.ListenAddr)
	if err != nil {
		return fmt.Errorf("listen failed: %w", err)
	}
	httpServer := &http.Server{Handler: app.Handler(), ReadHeaderTimeout: 5 * time.Second, ReadTimeout: 30 * time.Second, WriteTimeout: 35 * time.Second, IdleTimeout: 120 * time.Second, MaxHeaderBytes: 16 << 10}
	psylog.Default().Info("server", "listen", psylog.KV{"addr": listener.Addr().String(), "version": server.Version})
	done := make(chan error, 1)
	go func() { done <- httpServer.Serve(listener) }()
	select {
	case err := <-done:
		if errors.Is(err, http.ErrServerClosed) {
			return nil
		}
		return err
	case <-ctx.Done():
		shutdown, cancel := context.WithTimeout(context.Background(), 15*time.Second)
		defer cancel()
		if err := httpServer.Shutdown(shutdown); err != nil {
			httpServer.Close()
			return err
		}
		return nil
	}
}
