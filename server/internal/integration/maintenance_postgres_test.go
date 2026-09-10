//go:build postgres

package integration

import (
	"bytes"
	"context"
	"crypto/ed25519"
	"crypto/sha256"
	"database/sql"
	"encoding/json"
	"errors"
	"fmt"
	"os"
	"os/exec"
	"path/filepath"
	"strings"
	"sync"
	"testing"
	"time"

	"psychosims.dev/server/internal/audit"
	"psychosims.dev/server/internal/ctxutil"
	"psychosims.dev/server/internal/devicekeys"
	"psychosims.dev/server/internal/identity"
	"psychosims.dev/server/internal/maintenance"
	"psychosims.dev/server/internal/privacy"
	"psychosims.dev/server/internal/profile"
	"psychosims.dev/server/internal/schemas"
	"psychosims.dev/server/internal/tokens"
)

func execSQL(t *testing.T, db *sql.DB, q string, args ...any) {
	t.Helper()
	if _, err := db.Exec(q, args...); err != nil {
		t.Fatal(err)
	}
}

func TestPostgresMaintenanceCompactsReceiptsButNeverDoubleAccepts(t *testing.T) {
	st := postgresStore(t)
	db := st.DB()
	sqlAccount(t, db, "a")
	svc, env, ctx, _ := sqlReceipt(t, st, "a", "p", "r", audit.NewAppender(db))
	if _, err := svc.Submit(ctx, "a", env); err != nil {
		t.Fatal(err)
	}
	execSQL(t, db, `UPDATE session_authorizations SET consumed_at=clock_timestamp()-interval '91 days'; UPDATE idempotency_keys SET expires_at=clock_timestamp()-interval '2 days'`)
	gc := maintenance.NewService(db, audit.NewAppender(db))
	policy := maintenance.DefaultPolicy()
	preview, err := gc.Collect(ctx, policy, false)
	if err != nil {
		t.Fatal(err)
	}
	if preview.Counts["receipt_payloads"] != 1 || preview.Counts["idempotency_keys"] != 1 {
		t.Fatalf("preview: %+v", preview)
	}
	var body []byte
	if err := db.QueryRow(`SELECT receipt_bytes FROM session_authorizations`).Scan(&body); err != nil || len(body) == 0 {
		t.Fatal("dry run changed receipt")
	}
	failed, failure := maintenance.NewService(db, failingAudit{audit.NewAppender(db)}).Collect(ctx, policy, true)
	if failure == nil || failed.Applied {
		t.Fatal("cleanup falsely reported an audit-failed transaction as applied")
	}
	if err := db.QueryRow(`SELECT receipt_bytes FROM session_authorizations`).Scan(&body); err != nil || len(body) == 0 || countRows(t, db, "idempotency_keys") != 1 {
		t.Fatal("cleanup escaped audit rollback")
	}
	if _, err = gc.Collect(ctx, policy, true); err != nil {
		t.Fatal(err)
	}
	if err := db.QueryRow(`SELECT receipt_bytes FROM session_authorizations`).Scan(&body); err != nil || len(body) != 0 {
		t.Fatal("old projection retained")
	}
	if _, err = svc.Submit(ctx, "a", env); err != nil {
		t.Fatal(err)
	}
	prof, err := profile.NewSQLRepository(db).Get(ctx, "a")
	if err != nil || prof.Version != 2 || prof.XP != 5 {
		t.Fatalf("duplicate commit: %+v %v", prof, err)
	}
	if _, err = audit.NewAppender(db).ValidateChain(ctx); err != nil {
		t.Fatal(err)
	}
}

func TestPostgresMaintenancePreservesActiveRotationAndRetiresOldIssueKeys(t *testing.T) {
	st := postgresStore(t)
	db := st.DB()
	sqlAccount(t, db, "a")
	ctx := context.Background()
	manager := tokens.NewSQLManager(db, []byte("only-a-local-test-secret-32-bytes-long"), time.Minute, 7*24*time.Hour)
	initial, err := manager.IssuePair(ctx, "a", "live")
	if err != nil {
		t.Fatal(err)
	}
	rotated, err := manager.Rotate(ctx, initial.RefreshToken, "rotate")
	if err != nil {
		t.Fatal(err)
	}
	if _, err = manager.IssuePair(ctx, "a", "old"); err != nil {
		t.Fatal(err)
	}
	execSQL(t, db, `UPDATE auth_sessions SET created_at=clock_timestamp()-interval '10 days', initial_pair=jsonb_set(jsonb_set(initial_pair,'{access,expires_at}',to_jsonb(1::bigint)),'{refresh,expires_at}',to_jsonb(1::bigint)) WHERE issue_key='old'`)
	execSQL(t, db, `UPDATE refresh_tokens SET expires_at=clock_timestamp()-interval '2 days' WHERE session_id IN(SELECT id FROM auth_sessions WHERE issue_key='old')`)
	gc := maintenance.NewService(db, audit.NewAppender(db))
	if _, err = gc.Collect(ctx, maintenance.DefaultPolicy(), true); err != nil {
		t.Fatal(err)
	}
	replay, err := manager.Rotate(ctx, initial.RefreshToken, "rotate")
	if err != nil || replay != rotated {
		t.Fatalf("live replay lost: %v", err)
	}
	if _, err = manager.Verify(ctx, rotated.AccessToken); err != nil {
		t.Fatal(err)
	}
	if _, err = manager.IssuePair(ctx, "a", "old"); !errors.Is(err, tokens.ErrTokenExpired) && !errors.Is(err, tokens.ErrTokenRevoked) {
		t.Fatalf("old issue key minted authority: %v", err)
	}
	var retired bool
	var material string
	if err := db.QueryRow(`SELECT retired_at IS NOT NULL,initial_pair::text FROM auth_sessions WHERE issue_key='old'`).Scan(&retired, &material); err != nil || !retired || material != "{}" {
		t.Fatalf("claims not retired: %s %v", material, err)
	}
}

func TestPostgresMaintenanceBoundedConcurrentAndLegalHold(t *testing.T) {
	st := postgresStore(t)
	db := st.DB()
	sqlAccount(t, db, "held")
	ctx := context.Background()
	execSQL(t, db, `INSERT INTO account_legal_holds(account_id) VALUES('held')`)
	for i := 0; i < 9; i++ {
		execSQL(t, db, `INSERT INTO oauth_states(state,payload,expires_at) VALUES($1,'{}',clock_timestamp()-interval '2 days')`, fmt.Sprint("old", i))
	}
	execSQL(t, db, `INSERT INTO idempotency_keys(account_id,key,expires_at) VALUES('held','k',clock_timestamp()-interval '2 days')`)
	p := maintenance.DefaultPolicy()
	p.BatchSize = 2
	gc := maintenance.NewService(db, audit.NewAppender(db))
	var wg sync.WaitGroup
	for i := 0; i < 3; i++ {
		wg.Add(1)
		go func() {
			defer wg.Done()
			r, err := gc.Collect(ctx, p, true)
			if err != nil {
				t.Error(err)
				return
			}
			if r.Counts["oauth_states"] > 2 {
				t.Error("batch cap exceeded")
			}
		}()
	}
	wg.Wait()
	if countRows(t, db, "oauth_states") != 3 {
		t.Fatal("concurrent batches lost rows")
	}
	if countRows(t, db, "idempotency_keys") != 1 {
		t.Fatal("legal hold deleted")
	}
}

func TestPostgresAccountErasureRevokesRemovesLinksAndPreservesLedgerAudit(t *testing.T) {
	st := postgresStore(t)
	db := st.DB()
	sqlAccount(t, db, "erase")
	sqlAccount(t, db, "other")
	ctx := context.Background()
	if err := identity.NewSQLRepository(db).LinkProvider(ctx, "erase", identity.ProviderIdentity{Provider: "google", ProviderID: "private-subject"}); err != nil {
		t.Fatal(err)
	}
	manager := tokens.NewSQLManager(db, []byte("only-a-local-test-secret-32-bytes-long"), time.Minute, time.Hour)
	pair, err := manager.IssuePair(ctx, "erase", "login")
	if err != nil {
		t.Fatal(err)
	}
	keys := devicekeys.NewSQLRepository(db)
	pub, _, _ := ed25519.GenerateKey(nil)
	key, err := keys.Register(ctxutil.WithIdempotencyKey(ctx, "keyop"), "erase", pub, "ed25519-v1")
	if err != nil {
		t.Fatal(err)
	}
	svc, env, receiptCtx, _ := sqlReceipt(t, st, "erase", "p", "r", audit.NewAppender(db))
	if _, err = svc.Submit(receiptCtx, "erase", env); err != nil {
		t.Fatal(err)
	}
	execSQL(t, db, `INSERT INTO ledger_events(account_id,idempotency_key,kind,currency,amount_micros,reason_key) VALUES('erase','credit','mint','xp',10,'test.credit'),('erase','debit','sink','xp',-3,'test.debit')`)
	eraser := privacy.NewService(db, audit.NewAppender(db))
	if _, err = eraser.Erase(ctx, "erase", false); err != nil {
		t.Fatal(err)
	}
	if _, err = manager.Verify(ctx, pair.AccessToken); err != nil {
		t.Fatal("dry-run revoked token")
	}
	if _, err = eraser.Erase(ctx, "erase", true); err != nil {
		t.Fatal(err)
	}
	if _, err = eraser.Erase(ctx, "erase", true); err != nil {
		t.Fatalf("erase retry: %v", err)
	}
	if _, err = manager.Verify(ctx, pair.AccessToken); err == nil {
		t.Fatal("erased access alive")
	}
	if _, err = manager.Rotate(ctx, pair.RefreshToken, "rotation"); err == nil {
		t.Fatal("erased refresh alive")
	}
	for _, table := range []string{"provider_identities", "profiles", "auth_sessions", "device_keys", "device_key_requests", "session_start_requests", "presence", "idempotency_keys"} {
		var n int
		if err := db.QueryRow("SELECT count(*) FROM " + table + " WHERE account_id='erase'").Scan(&n); err != nil || n != 0 {
			t.Fatalf("%s retained %d %v", table, n, err)
		}
	}
	revoked, err := keys.ListRevoked(ctx)
	if err != nil || len(revoked) != 1 || revoked[0].KeyID != key {
		t.Fatalf("revocation lost: %+v %v", revoked, err)
	}
	balances, err := profile.NewLedger(db).Balance(ctx, "erase")
	if err != nil || balances["xp"] != 7 {
		t.Fatalf("ledger changed: %v %v", balances, err)
	}
	if _, err = audit.NewAppender(db).ValidateChain(ctx); err != nil {
		t.Fatal(err)
	}
	var n int
	execSQL(t, db, `SELECT 1`)
	if err = db.QueryRow(`SELECT count(*) FROM session_authorizations WHERE account_id='erase' AND consumed_at IS NOT NULL AND receipt_hash IS NOT NULL AND receipt_bytes IS NULL`).Scan(&n); err != nil || n != 1 {
		t.Fatal("acceptance tombstone lost")
	}
	for _, q := range []string{`INSERT INTO profiles(account_id,payload) VALUES('erase','{}')`, `DELETE FROM accounts WHERE id='erase'`, `INSERT INTO provider_identities(provider,subject,account_id) VALUES('google','new','erase')`} {
		if _, err = db.Exec(q); err == nil {
			t.Fatalf("erased authority resurrected: %s", q)
		}
	}
	if _, err = manager.IssuePair(ctx, "erase", "new-login"); err == nil {
		t.Fatal("erased account token issued")
	}
	if _, err = profile.NewSQLRepository(db).Get(ctx, "other"); err != nil {
		t.Fatal("other account touched")
	}
}

func TestPostgresErasureRollbackAndLegalHold(t *testing.T) {
	st := postgresStore(t)
	db := st.DB()
	sqlAccount(t, db, "a")
	ctx := context.Background()
	eraser := privacy.NewService(db, failingAudit{audit.NewAppender(db)})
	if report, err := eraser.Erase(ctx, "a", true); err == nil || report.Applied {
		t.Fatal("missing injected rollback or falsely reported commit")
	}
	if countRows(t, db, "profiles") != 1 || countRows(t, db, "account_erasures") != 0 {
		t.Fatal("erasure escaped rollback")
	}
	execSQL(t, db, `INSERT INTO account_legal_holds(account_id) VALUES('a')`)
	if _, err := privacy.NewService(db, audit.NewAppender(db)).Erase(ctx, "a", true); !errors.Is(err, privacy.ErrLegalHold) {
		t.Fatalf("hold ignored %v", err)
	}
}

func TestPostgresMaintenanceRetiresStartResponseWithoutReissuing(t *testing.T) {
	st := postgresStore(t)
	db := st.DB()
	sqlAccount(t, db, "a")
	service, env, _, _ := sqlReceipt(t, st, "a", "patient", "r", audit.NewAppender(db))
	var receipt schemas.SessionReceipt
	if err := json.Unmarshal(env.CanonicalReceiptBytes, &receipt); err != nil {
		t.Fatal(err)
	}
	ctx := ctxutil.WithIdempotencyKey(context.Background(), "start-operation")
	requestHash := sha256.Sum256([]byte("trusted-request"))
	permit, err := service.AuthorizeRequest(ctx, "a", "patient", receipt.RulesetVersion, receipt.StartState, requestHash[:])
	if err != nil {
		t.Fatal(err)
	}
	execSQL(t, db, `UPDATE session_start_requests SET response_payload=jsonb_set(response_payload,'{expires_at}',to_jsonb((clock_timestamp()-interval '2 days')::text))`)
	execSQL(t, db, `UPDATE session_authorizations SET expires_at=clock_timestamp()-interval '2 days' WHERE id=$1`, permit.ID)
	if _, err = maintenance.NewService(db, audit.NewAppender(db)).Collect(ctx, maintenance.DefaultPolicy(), true); err != nil {
		t.Fatal(err)
	}
	if _, err = service.AuthorizeRequest(ctx, "a", "patient", receipt.RulesetVersion, receipt.StartState, requestHash[:]); err == nil || !strings.Contains(err.Error(), "retired") {
		t.Fatalf("retired start reused: %v", err)
	}
	if countRows(t, db, "session_authorizations") != 0 || countRows(t, db, "session_start_requests") != 1 {
		t.Fatal("lost refusal marker or reissued permit")
	}
}

type pausedErasureAudit struct {
	audit.Appender
	entered chan struct{}
	release chan struct{}
}

func (a pausedErasureAudit) Append(ctx context.Context, tx *sql.Tx, record audit.Record) error {
	close(a.entered)
	select {
	case <-a.release:
	case <-ctx.Done():
		return ctx.Err()
	}
	return a.Appender.Append(ctx, tx, record)
}
func TestPostgresErasureFencesAWriteAlreadyWaitingOnAccount(t *testing.T) {
	st := postgresStore(t)
	db := st.DB()
	sqlAccount(t, db, "a")
	ctx, cancel := context.WithTimeout(context.Background(), 5*time.Second)
	defer cancel()
	entered, release := make(chan struct{}), make(chan struct{})
	var once sync.Once
	defer once.Do(func() { close(release) })
	eraser := privacy.NewService(db, pausedErasureAudit{audit.NewAppender(db), entered, release})
	erased := make(chan error, 1)
	go func() { _, err := eraser.Erase(ctx, "a", true); erased <- err }()
	select {
	case <-entered:
	case <-ctx.Done():
		t.Fatal("erasure did not reach guarded transaction")
	}
	written := make(chan error, 1)
	go func() {
		_, err := db.ExecContext(ctx, `/* privacy_late_write */ INSERT INTO profiles(account_id,payload) VALUES('a','{}')`)
		written <- err
	}()
	waiting := false
	for deadline := time.Now().Add(time.Second); time.Now().Before(deadline); {
		if err := db.QueryRowContext(ctx, `SELECT EXISTS(SELECT 1 FROM pg_stat_activity WHERE query LIKE '%privacy_late_write%' AND wait_event_type='Lock')`).Scan(&waiting); err != nil {
			t.Fatal(err)
		}
		if waiting {
			break
		}
		time.Sleep(time.Millisecond)
	}
	if !waiting {
		t.Fatal("late writer was not actually blocked by erasure")
	}
	once.Do(func() { close(release) })
	if err := <-erased; err != nil {
		t.Fatal(err)
	}
	if err := <-written; err == nil {
		t.Fatal("waiting writer bypassed committed erasure fence")
	}
	if countRows(t, db, "profiles") != 0 || countRows(t, db, "account_erasures") != 1 {
		t.Fatal("erased profile resurrected")
	}
}

func TestPostgresMaintenanceActualLocalCommandDryRunApplyAndJournal(t *testing.T) {
	st := postgresStore(t)
	sqlAccount(t, st.DB(), "command-account")
	ctx, cancel := context.WithTimeout(context.Background(), 30*time.Second)
	defer cancel()
	binary := filepath.Join(t.TempDir(), "psy-maintenance")
	build := exec.CommandContext(ctx, "go", "build", "-o", binary, "./cmd/psy-maintenance")
	build.Dir = "../.."
	if output, err := build.CombinedOutput(); err != nil {
		t.Fatalf("command build: %v %s", err, output)
	}
	journal := filepath.Join(t.TempDir(), "journal")
	runCommand := func(args ...string) []byte {
		t.Helper()
		command := exec.CommandContext(ctx, binary, args...)
		command.Env = append(os.Environ(), "PSY_MAINTENANCE_DATABASE_DSN="+os.Getenv("PSY_TEST_DATABASE_DSN"))
		out, err := command.CombinedOutput()
		if err != nil {
			t.Fatalf("command failed: %v %s", err, out)
		}
		return out
	}
	preview := runCommand("erase-account", "--account=command-account")
	if !bytes.Contains(preview, []byte(`"applied":false`)) || countRows(t, st.DB(), "profiles") != 1 {
		t.Fatal("command dry-run changed state")
	}
	runCommand("erase-account", "--account=command-account", "--journal-dir="+journal, "--apply")
	intents, err := privacy.ReadIntents(journal, 10)
	if err != nil || len(intents) != 1 {
		t.Fatal("durable erasure journal missing")
	}
	runCommand("reapply-erasures", "--journal-dir="+journal, "--apply")
	runCommand("gc")
	if countRows(t, st.DB(), "profiles") != 0 || countRows(t, st.DB(), "account_erasures") != 1 {
		t.Fatal("command did not fence account")
	}
}

func TestPostgresMaintenanceSkipsAccountLockedForIncomingLegalHold(t *testing.T) {
	st := postgresStore(t)
	db := st.DB()
	sqlAccount(t, db, "held-later")
	ctx, cancel := context.WithTimeout(context.Background(), 3*time.Second)
	defer cancel()
	execSQL(t, db, `INSERT INTO idempotency_keys(account_id,key,expires_at) VALUES('held-later','old',clock_timestamp()-interval '2 days')`)
	tx, err := db.BeginTx(ctx, nil)
	if err != nil {
		t.Fatal(err)
	}
	defer tx.Rollback()
	if _, err = tx.ExecContext(ctx, `SELECT id FROM accounts WHERE id='held-later' FOR UPDATE`); err != nil {
		t.Fatal(err)
	}
	report, err := maintenance.NewService(db, audit.NewAppender(db)).Collect(ctx, maintenance.DefaultPolicy(), true)
	if err != nil || report.Counts["idempotency_keys"] != 0 {
		t.Fatalf("GC bypassed pending hold lock: %+v %v", report, err)
	}
	if _, err = tx.ExecContext(ctx, `INSERT INTO account_legal_holds(account_id) VALUES('held-later')`); err != nil {
		t.Fatal(err)
	}
	if err = tx.Commit(); err != nil {
		t.Fatal(err)
	}
	if countRows(t, db, "idempotency_keys") != 1 {
		t.Fatal("held data deleted")
	}
}

func TestPostgresMaintenanceLimitsAccountLocksToCandidateBatch(t *testing.T) {
	st := postgresStore(t)
	db := st.DB()
	for i := 0; i < 5; i++ {
		account := fmt.Sprintf("bounded-account-%d", i)
		sqlAccount(t, db, account)
		execSQL(t, db, `INSERT INTO idempotency_keys(account_id,key,expires_at) VALUES($1,'old',clock_timestamp()-interval '2 days')`, account)
	}
	ctx, cancel := context.WithTimeout(context.Background(), 5*time.Second)
	defer cancel()
	entered, release := make(chan struct{}), make(chan struct{})
	var once sync.Once
	defer once.Do(func() { close(release) })
	collector := maintenance.NewService(db, pausedErasureAudit{audit.NewAppender(db), entered, release})
	result := make(chan error, 1)
	policy := maintenance.DefaultPolicy()
	policy.BatchSize = 1
	go func() { _, err := collector.Collect(ctx, policy, true); result <- err }()
	select {
	case <-entered:
	case <-ctx.Done():
		t.Fatal("GC did not reach audit")
	}
	_, lockErr := db.ExecContext(ctx, `SELECT id FROM accounts WHERE id='bounded-account-4' FOR UPDATE NOWAIT`)
	once.Do(func() { close(release) })
	if err := <-result; err != nil {
		t.Fatal(err)
	}
	if lockErr != nil {
		t.Fatalf("GC locked beyond one candidate: %v", lockErr)
	}
}

func TestPostgresErasureIntentPreviewsAccountMissingFromOldBackup(t *testing.T) {
	st := postgresStore(t)
	db := st.DB()
	ctx := context.Background()
	intent, err := privacy.WriteIntent(filepath.Join(t.TempDir(), "journal"), "absent-in-backup")
	if err != nil {
		t.Fatal(err)
	}
	service := privacy.NewService(db, audit.NewAppender(db))
	preview, err := service.ApplyIntent(ctx, intent, false)
	if err != nil || preview.Applied || countRows(t, db, "accounts") != 0 {
		t.Fatalf("restore preview failed or wrote rows: %+v %v", preview, err)
	}
	applied, err := service.ApplyIntent(ctx, intent, true)
	if err != nil || !applied.Applied || countRows(t, db, "account_erasures") != 1 {
		t.Fatalf("missing-account fence: %+v %v", applied, err)
	}
}
