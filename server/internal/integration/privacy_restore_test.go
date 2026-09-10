//go:build postgres && restore

package integration

import (
	"bytes"
	"context"
	"crypto/ed25519"
	"fmt"
	"net/url"
	"os"
	"os/exec"
	"path/filepath"
	"strings"
	"testing"
	"time"

	"psychosims.dev/server/internal/audit"
	"psychosims.dev/server/internal/canonicaljson"
	"psychosims.dev/server/internal/config"
	"psychosims.dev/server/internal/ctxutil"
	"psychosims.dev/server/internal/devicekeys"
	"psychosims.dev/server/internal/identity"
	"psychosims.dev/server/internal/ownership"
	"psychosims.dev/server/internal/privacy"
	"psychosims.dev/server/internal/profile"
	"psychosims.dev/server/internal/schemas"
	"psychosims.dev/server/internal/store"
	"psychosims.dev/server/internal/timeutil"
	"psychosims.dev/server/internal/tokens"
)

func TestPostgresLogicalBackupRestoreErasure(t *testing.T) {
	container := os.Getenv("PSY_RESTORE_CONTAINER")
	restoreDSN := os.Getenv("PSY_RESTORE_DATABASE_DSN")
	if !strings.HasPrefix(container, "psychosims-restore-drill-") || restoreDSN == "" || restoreDSN == os.Getenv("PSY_TEST_DATABASE_DSN") {
		t.Fatal("run the disposable local restore drill")
	}
	ctx, cancel := context.WithTimeout(context.Background(), 2*time.Minute)
	defer cancel()
	source := postgresStore(t)
	db := source.DB()
	const account = "privacy-restore-account"
	sqlAccount(t, db, account)
	if err := identity.NewSQLRepository(db).LinkProvider(ctx, account, identity.ProviderIdentity{Provider: "google", ProviderID: "fixture-private-provider-subject"}); err != nil {
		t.Fatal(err)
	}
	secret := []byte("only-a-local-test-secret-32-bytes-long")
	manager := tokens.NewSQLManager(db, secret, time.Hour, 24*time.Hour)
	pair, err := manager.IssuePair(ctx, account, "pre-erasure-login")
	if err != nil {
		t.Fatal(err)
	}
	keys := devicekeys.NewSQLRepository(db)
	pub, priv, err := ed25519.GenerateKey(nil)
	if err != nil {
		t.Fatal(err)
	}
	keyID, err := keys.Register(ctx, account, pub, "ed25519-v1")
	if err != nil {
		t.Fatal(err)
	}
	if err := ownership.NewService(ownership.NewSQLRepository(db), timeutil.RealClock{}).Claim(ctx, "privacy-restore-patient", account, 0, ownership.MemoryClassPersistent); err != nil {
		t.Fatal(err)
	}
	service := restoreReceiptService(source)
	receipt := schemas.SessionReceipt{PatientID: "privacy-restore-patient", SchemaVersion: schemas.CurrentReceiptSchemaVersion, RulesetVersion: "0.1.0", IdempotencyKey: "privacy-restore-receipt", CorrelationID: "privacy-restore", TurnCount: 1, StartState: schemas.SessionStartState{Loadout: schemas.Loadout{CardIds: []string{"open_question"}, SlotCap: 6}, Library: schemas.CardLibrary{OwnedCardIds: []string{"open_question"}}}, Actions: []schemas.InteractionPattern{schemas.OpenQuestion}}
	permit, err := service.Authorize(ctx, account, receipt.PatientID, receipt.RulesetVersion, receipt.StartState)
	if err != nil {
		t.Fatal(err)
	}
	receipt.ID = permit.ID
	body, err := canonicaljson.Marshal(receipt)
	if err != nil {
		t.Fatal(err)
	}
	envelope := schemas.SignedEnvelope{CanonicalReceiptBytes: body, Signature: ed25519.Sign(priv, body), SuiteID: "ed25519-v1", SigningKeyID: keyID}
	if _, err = service.Submit(ctxutil.WithAccountID(ctx, account), account, envelope); err != nil {
		t.Fatal(err)
	}
	execSQL(t, db, `INSERT INTO ledger_events(account_id,idempotency_key,kind,currency,amount_micros,reason_key) VALUES($1,'fixture-credit','mint','xp',10,'test.credit'),($1,'fixture-debit','sink','xp',-3,'test.debit')`, account)
	dump := exec.CommandContext(ctx, "docker", "exec", container, "pg_dump", "-U", "postgres", "-d", "psychosims_source", "--format=custom", "--no-owner", "--no-privileges")
	var diagnostic bytes.Buffer
	dump.Stderr = &diagnostic
	backup, err := dump.Output()
	if err != nil {
		t.Fatalf("pre-erasure dump: %v %s", err, diagnostic.String())
	}
	if len(backup) == 0 || len(backup) > 8*1024*1024 {
		t.Fatal("unexpected local fixture backup size")
	}
	journal := filepath.Join(t.TempDir(), "external-erasure-journal")
	intent, err := privacy.WriteIntent(journal, account)
	if err != nil {
		t.Fatal(err)
	}
	if _, err = privacy.NewService(db, audit.NewAppender(db)).ApplyIntent(ctx, intent, true); err != nil {
		t.Fatal(err)
	}
	database := fmt.Sprintf("erasure_restore_%d", time.Now().UnixNano())
	if output, err := exec.CommandContext(ctx, "docker", "exec", container, "createdb", "-U", "postgres", database).CombinedOutput(); err != nil {
		t.Fatalf("create restore target: %v %s", err, output)
	}
	defer func() {
		cleanup, cancel := context.WithTimeout(context.Background(), 10*time.Second)
		defer cancel()
		if output, err := exec.CommandContext(cleanup, "docker", "exec", container, "dropdb", "--force", "-U", "postgres", database).CombinedOutput(); err != nil {
			t.Errorf("cleanup own restore database: %v %s", err, output)
		}
	}()
	restore := exec.CommandContext(ctx, "docker", "exec", "-i", container, "pg_restore", "--exit-on-error", "--no-owner", "--no-privileges", "-U", "postgres", "-d", database)
	restore.Stdin = bytes.NewReader(backup)
	if output, err := restore.CombinedOutput(); err != nil {
		t.Fatalf("pre-erasure restore: %v %s", err, output)
	}
	target, err := url.Parse(restoreDSN)
	if err != nil {
		t.Fatal(err)
	}
	target.Path = "/" + database
	cfg := config.Default()
	cfg.DatabaseDSN = target.String()
	restored, err := store.New(ctx, cfg)
	if err != nil {
		t.Fatal(err)
	}
	defer restored.Close()
	restoredTokens := tokens.NewSQLManager(restored.DB(), secret, time.Hour, 24*time.Hour)
	if _, err = restoredTokens.Verify(ctx, pair.AccessToken); err != nil {
		t.Fatal("fixture did not restore the actual pre-erasure authority")
	}
	intents, err := privacy.ReadIntents(journal, 10)
	if err != nil || len(intents) != 1 {
		t.Fatal("external journal lost")
	}
	reapply := privacy.NewService(restored.DB(), audit.NewAppender(restored.DB()))
	if _, err = reapply.ApplyIntent(ctx, intents[0], true); err != nil {
		t.Fatal(err)
	}
	if _, err = reapply.ApplyIntent(ctx, intents[0], true); err != nil {
		t.Fatal("restore replay not idempotent")
	}
	if _, err = restoredTokens.Verify(ctx, pair.AccessToken); err == nil {
		t.Fatal("old backup reactivated erased access")
	}
	if _, err = restoredTokens.Rotate(ctx, pair.RefreshToken, "post-restore"); err == nil {
		t.Fatal("old backup reactivated erased refresh")
	}
	for _, table := range []string{"profiles", "provider_identities", "auth_sessions", "device_keys"} {
		if countRows(t, restored.DB(), table) != 0 {
			t.Fatalf("restored identity retained: %s", table)
		}
	}
	revoked, err := devicekeys.NewSQLRepository(restored.DB()).ListRevoked(ctx)
	if err != nil || len(revoked) != 1 || revoked[0].KeyID != keyID {
		t.Fatal("restored key revocation missing")
	}
	balances, err := profile.NewLedger(restored.DB()).Balance(ctx, account)
	if err != nil || balances["xp"] != 7 {
		t.Fatal("restored financial history changed")
	}
	if _, err = audit.NewAppender(restored.DB()).ValidateChain(ctx); err != nil {
		t.Fatal(err)
	}
	var tombstones int
	if err = restored.DB().QueryRow(`SELECT count(*) FROM session_authorizations WHERE id=$1 AND receipt_hash IS NOT NULL AND receipt_bytes IS NULL`, receipt.ID).Scan(&tombstones); err != nil || tombstones != 1 {
		t.Fatal("accepted receipt replay tombstone lost")
	}
	t.Logf("ERASURE_RESTORE_EVIDENCE backup_bytes=%d old_backup_authority_demonstrated=true external_journal_reapplied=true access_refresh_keys_revoked=true ledger_sum=7 audit_chain_valid=true accepted_hash_retained=true", len(backup))
}
