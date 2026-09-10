//go:build postgres && flutter

package integration

import (
	"context"
	"errors"
	"net/http/httptest"
	"os"
	"os/exec"
	"path/filepath"
	"strings"
	"testing"
	"time"

	"psychosims.dev/server/internal/config"
	"psychosims.dev/server/internal/identity"
	"psychosims.dev/server/internal/server"
	"psychosims.dev/server/internal/tokens"
)

// The fixture accepts exactly one public local test credential. This adapter
// exists only in the explicitly tagged test binary, never the server executable.
type flutterFixtureProvider struct{}

func (flutterFixtureProvider) Verify(_ context.Context, token, nonce string) (identity.ProviderIdentity, error) {
	if token != "public-local-w3-fixture" || nonce != "public-local-w3-nonce" {
		return identity.ProviderIdentity{}, errors.New("invalid fixture credential")
	}
	return identity.ProviderIdentity{Provider: "google", ProviderID: "dart-http-fixture"}, nil
}
func TestPostgresDartControlPlane(t *testing.T) {
	for _, certified := range []bool{false, true} {
		name := "held"
		if certified {
			name = "certified"
		}
		t.Run(name, func(t *testing.T) { dartControlPlane(t, certified) })
	}
}

func dartControlPlane(t *testing.T, certified bool) {
	t.Helper()
	st := postgresStore(t)
	cfg := config.Default()
	cfg.RateLimitPreAuthPerIP = 1000
	cfg.RateLimitAuthPerAccount = 1000
	manifest, err := filepath.Abs("../../../content/manifests/siege_brumosis.json")
	if err != nil {
		t.Fatal(err)
	}
	catalog, err := server.LoadCatalog([]string{manifest})
	if err != nil {
		t.Fatal(err)
	}
	mode := "0"
	if certified {
		trusted, _, _ := trustedFixture(t)
		catalog = catalog.WithOutcomes(trusted)
		cfg.CureRewards.CashMicros = 2_500_000
		cfg.CureRewards.CashPerWindow = 12_500_000
		mode = "1"
	}
	ids := identity.NewService(identity.NewSQLRepository(st.DB()))
	ids.RegisterProvider("google", flutterFixtureProvider{})
	secret := []byte(strings.Repeat("local-test-key-", 3))
	app := server.NewOnline(cfg, st.DB(), ids, tokens.NewSQLManager(st.DB(), secret, time.Minute, time.Hour), catalog, secret)
	httpServer := httptest.NewServer(app.Handler())
	defer httpServer.Close()
	ctx, cancel := context.WithTimeout(context.Background(), 2*time.Minute)
	defer cancel()
	cmd := exec.CommandContext(ctx, "flutter", "test", "test_http/control_plane_http_test.dart")
	cmd.Dir = "../../../app"
	cmd.Env = append(os.Environ(), "PSY_W3_API_URL="+httpServer.URL, "PSY_W3_ID_TOKEN=public-local-w3-fixture", "PSY_W3_NONCE=public-local-w3-nonce", "PSY_W3_CASE_ID=siege.brumosis", "PSY_W3_MANIFEST_PATH="+manifest)
	cmd.Env = append(cmd.Env, "PSY_W3_EXPECT_CERTIFIED="+mode)
	if output, err := cmd.CombinedOutput(); err != nil {
		t.Fatalf("Dart to HTTP to PostgreSQL integration: %v\n%s", err, output)
	} else {
		t.Logf("Dart control-plane integration passed:\n%s", output)
	}
	if n := countRows(t, st.DB(), "session_authorizations"); n != 1 {
		t.Fatalf("Dart flow authorizations=%d want1", n)
	}
	var accepted int
	if err := st.DB().QueryRow(`SELECT count(*) FROM session_authorizations WHERE consumed_at IS NOT NULL`).Scan(&accepted); err != nil {
		t.Fatal(err)
	}
	if accepted != 1 {
		t.Fatalf("Dart flow accepted receipts=%d want1", accepted)
	}
	wantLedger, wantCures := 0, 0
	if certified {
		wantLedger, wantCures = 6, 1
	}
	if n := countRows(t, st.DB(), "ledger_events"); n != wantLedger {
		t.Fatalf("Dart receipt ledger rows=%d want%d", n, wantLedger)
	}
	if n := countRows(t, st.DB(), "certified_cures"); n != wantCures {
		t.Fatalf("Dart receipt cures=%d want%d", n, wantCures)
	}
	if n := countRows(t, st.DB(), "audit_log"); n != 1 {
		t.Fatalf("Dart receipt audit rows=%d want1", n)
	}
	if certified {
		var rewarded, cured, imbalanced int
		if err := st.DB().QueryRow(`SELECT count(*) FROM profiles WHERE version=2
			AND (payload->>'xp')::int=100 AND (payload->>'study_points')::int=3
			AND (payload->>'cash_micros')::bigint=2500000`).Scan(&rewarded); err != nil {
			t.Fatal(err)
		}
		if err := st.DB().QueryRow(`SELECT count(*) FROM ownership_records WHERE state='cured'`).Scan(&cured); err != nil {
			t.Fatal(err)
		}
		if err := st.DB().QueryRow(`SELECT count(*) FROM
			(SELECT currency FROM ledger_events GROUP BY currency HAVING sum(amount_micros)<>0) AS unbalanced`).Scan(&imbalanced); err != nil {
			t.Fatal(err)
		}
		if rewarded != 1 || cured != 1 || imbalanced != 0 {
			t.Fatalf("Dart certified state: rewarded=%d cured=%d imbalanced=%d", rewarded, cured, imbalanced)
		}
	}
}
