//go:build postgres && restore

package integration

import (
	"bytes"
	"context"
	"crypto/ed25519"
	"crypto/rand"
	"crypto/sha256"
	"encoding/hex"
	"encoding/json"
	"fmt"
	"os"
	"os/exec"
	"path/filepath"
	"reflect"
	"strings"
	"testing"
	"time"

	"psychosims.dev/server/internal/audit"
	"psychosims.dev/server/internal/canonicaljson"
	"psychosims.dev/server/internal/config"
	"psychosims.dev/server/internal/ctxutil"
	"psychosims.dev/server/internal/devicekeys"
	"psychosims.dev/server/internal/idempotency"
	"psychosims.dev/server/internal/ownership"
	"psychosims.dev/server/internal/profile"
	"psychosims.dev/server/internal/receipts"
	"psychosims.dev/server/internal/ruleset"
	"psychosims.dev/server/internal/schemas"
	"psychosims.dev/server/internal/store"
	"psychosims.dev/server/internal/timeutil"
	"psychosims.dev/server/internal/tokens"
)

func restoreReceiptService(st *store.Store) *receipts.Service {
	keys := devicekeys.NewService(devicekeys.NewSQLRepository(st.DB()))
	idem := idempotency.NewService(idempotency.NewSQLRepository(st.DB()), time.Hour)
	limits := receipts.DefaultLimits()
	validator := receipts.NewVerifier(receipts.NewVerifierFromDeviceKeys(keys), profile.NewSQLRepository(st.DB()), profile.NewLedger(st.DB()), idem, keys, &limits)
	validator.WithRuleset(ruleset.NewRegistry(ruleset.Config{KnownVersions: []string{"0.1.0"}, SunsetWindow: 24 * time.Hour}))
	return receipts.NewService(validator, st.DB(), idem, audit.NewAppender(st.DB()), nil)
}

// This is an explicit integration gate: absent prerequisites fail, never skip.
// The script provisions both databases in its own local container.
func TestPostgresLogicalBackupRestore(t *testing.T) {
	container := os.Getenv("PSY_RESTORE_CONTAINER")
	restoreDSN := os.Getenv("PSY_RESTORE_DATABASE_DSN")
	if !strings.HasPrefix(container, "psychosims-restore-drill-") || restoreDSN == "" || restoreDSN == os.Getenv("PSY_TEST_DATABASE_DSN") {
		t.Fatal("run scripts/local_restore_drill.sh with its own source and restore databases")
	}
	ctx, cancel := context.WithTimeout(context.Background(), 2*time.Minute)
	defer cancel()
	source := postgresStore(t)
	const account = "restore-account"
	const revokedAccount = "restore-revoked"
	const patient = "restore-patient"
	sqlAccount(t, source.DB(), account)
	sqlAccount(t, source.DB(), revokedAccount)
	keys := devicekeys.NewService(devicekeys.NewSQLRepository(source.DB()))
	public, private, err := ed25519.GenerateKey(rand.Reader)
	if err != nil {
		t.Fatal(err)
	}
	keyID, err := keys.Register(ctx, account, public, "ed25519-v1")
	if err != nil {
		t.Fatal(err)
	}
	if err = ownership.NewService(ownership.NewSQLRepository(source.DB()), timeutil.RealClock{}).Claim(ctx, patient, account, 0, ownership.MemoryClassPersistent); err != nil {
		t.Fatal(err)
	}
	service := restoreReceiptService(source)
	receipt := schemas.SessionReceipt{PatientID: patient, SchemaVersion: schemas.CurrentReceiptSchemaVersion, RulesetVersion: "0.1.0", IdempotencyKey: "restore-receipt", CorrelationID: "restore-drill", TurnCount: 1,
		StartState: schemas.SessionStartState{Loadout: schemas.Loadout{CardIds: []string{"open_question"}, SlotCap: 6}, Library: schemas.CardLibrary{OwnedCardIds: []string{"open_question"}}},
		Actions:    []schemas.InteractionPattern{schemas.OpenQuestion}, LedgerEvents: []schemas.LedgerEvent{}}
	authorization, err := service.Authorize(ctx, account, patient, receipt.RulesetVersion, receipt.StartState)
	if err != nil {
		t.Fatal(err)
	}
	receipt.ID = authorization.ID
	body, err := canonicaljson.Marshal(receipt)
	if err != nil {
		t.Fatal(err)
	}
	envelope := schemas.SignedEnvelope{CanonicalReceiptBytes: body, Signature: ed25519.Sign(private, body), SuiteID: "ed25519-v1", SigningKeyID: keyID}
	submitContext := ctxutil.WithIdempotencyKey(ctxutil.WithAccountID(ctx, account), receipt.IdempotencyKey)
	if _, err = service.Submit(submitContext, account, envelope); err != nil {
		t.Fatal(err)
	}
	beforeProfile, err := profile.NewSQLRepository(source.DB()).Get(ctx, account)
	if err != nil {
		t.Fatal(err)
	}
	beforeAudit, err := audit.NewAppender(source.DB()).ValidateChain(ctx)
	if err != nil {
		t.Fatal(err)
	}
	// The runtime signing secret is deliberately outside the database backup.
	secret := make([]byte, 32)
	if _, err = rand.Read(secret); err != nil {
		t.Fatal(err)
	}
	tokenManager := tokens.NewSQLManager(source.DB(), secret, time.Hour, 24*time.Hour)
	active, err := tokenManager.IssuePair(ctx, account, "restore-login-active")
	if err != nil {
		t.Fatal(err)
	}
	revoked, err := tokenManager.IssuePair(ctx, revokedAccount, "restore-login-revoked")
	if err != nil {
		t.Fatal(err)
	}
	if err = tokenManager.RevokeAccount(ctx, revokedAccount); err != nil {
		t.Fatal(err)
	}
	for _, table := range []string{"accounts", "profiles", "device_keys", "session_authorizations", "idempotency_keys", "audit_log", "auth_sessions"} {
		if countRows(t, source.DB(), table) == 0 {
			t.Fatalf("drill would omit populated %s", table)
		}
	}
	dumpStart := time.Now()
	dump := exec.CommandContext(ctx, "docker", "exec", container, "pg_dump", "-U", "postgres", "-d", "psychosims_source", "--format=custom", "--no-owner", "--no-privileges")
	var diagnostic bytes.Buffer
	dump.Stderr = &diagnostic
	backup, err := dump.Output()
	if err != nil {
		t.Fatalf("pg_dump failed: %v: %s", err, diagnostic.String())
	}
	dumpDuration := time.Since(dumpStart)
	if len(backup) == 0 || len(backup) > 8*1024*1024 {
		t.Fatalf("unexpected drill backup size: %d", len(backup))
	}
	fingerprint := sha256.Sum256(backup)
	backupPath := filepath.Join(t.TempDir(), "local-drill.dump")
	if err = os.WriteFile(backupPath, backup, 0600); err != nil {
		t.Fatal(err)
	}
	restoredBytes, err := os.ReadFile(backupPath)
	if err != nil {
		t.Fatal(err)
	}
	if sha256.Sum256(restoredBytes) != fingerprint {
		t.Fatal("backup checksum changed before restore")
	}
	restoreStart := time.Now()
	restore := exec.CommandContext(ctx, "docker", "exec", "-i", container, "pg_restore", "--exit-on-error", "--no-owner", "--no-privileges", "-U", "postgres", "-d", "psychosims_restore")
	restore.Stdin = bytes.NewReader(restoredBytes)
	if output, err := restore.CombinedOutput(); err != nil {
		t.Fatalf("pg_restore failed: %v: %s", err, output)
	}
	restoreDuration := time.Since(restoreStart)
	verifyStart := time.Now()
	cfg := config.Default()
	cfg.DatabaseDSN = restoreDSN
	recovered, err := store.New(ctx, cfg)
	if err != nil {
		t.Fatal(err)
	}
	defer recovered.Close()
	for _, table := range []string{"accounts", "profiles", "device_keys", "session_authorizations", "idempotency_keys", "audit_log", "auth_sessions"} {
		if countRows(t, recovered.DB(), table) != countRows(t, source.DB(), table) {
			t.Fatalf("restored %s row count differs", table)
		}
	}
	afterProfile, err := profile.NewSQLRepository(recovered.DB()).Get(ctx, account)
	if err != nil || !reflect.DeepEqual(beforeProfile, afterProfile) {
		t.Fatalf("restored profile mismatch: %v", err)
	}
	afterAudit, err := audit.NewAppender(recovered.DB()).ValidateChain(ctx)
	if err != nil || !reflect.DeepEqual(beforeAudit, afterAudit) {
		t.Fatalf("restored audit mismatch: %v", err)
	}
	// Recreate every service from the recovered database and replay the actual
	// signed receipt. No memory-only deduplication or key registry can rescue it.
	if _, err = restoreReceiptService(recovered).Submit(submitContext, account, envelope); err != nil {
		t.Fatalf("restored receipt retry failed: %v", err)
	}
	replayedProfile, err := profile.NewSQLRepository(recovered.DB()).Get(ctx, account)
	if err != nil || !reflect.DeepEqual(beforeProfile, replayedProfile) {
		t.Fatalf("restored retry changed profile: %v", err)
	}
	if countRows(t, recovered.DB(), "audit_log") != len(beforeAudit) || countRows(t, recovered.DB(), "idempotency_keys") != 1 {
		t.Fatal("restored receipt accepted twice")
	}
	recoveredTokens := tokens.NewSQLManager(recovered.DB(), secret, time.Hour, 24*time.Hour)
	if claims, err := recoveredTokens.Verify(ctx, active.AccessToken); err != nil || claims.AccountID != account {
		t.Fatalf("active session not recovered: %v", err)
	}
	if _, err = recoveredTokens.Verify(ctx, revoked.AccessToken); err == nil {
		t.Fatal("restore resurrected revoked account access")
	}
	if _, err = recoveredTokens.Rotate(ctx, revoked.RefreshToken, "restore-revoked-refresh"); err == nil {
		t.Fatal("restore resurrected revoked refresh token")
	}
	// A lost/corrupt external runtime secret must not silently accept old tokens.
	wrongSecret := make([]byte, 32)
	if _, err = tokens.NewSQLManager(recovered.DB(), wrongSecret, time.Hour, 24*time.Hour).Verify(ctx, active.AccessToken); err == nil {
		t.Fatal("incorrect restored secret accepted token")
	}
	evidence := map[string]any{"scope": "local PostgreSQL logical backup, small synthetic fixture; not PITR or production RPO/RTO", "backup_bytes": len(backup), "backup_sha256": hex.EncodeToString(fingerprint[:]), "dump_ms": dumpDuration.Milliseconds(), "restore_ms": restoreDuration.Milliseconds(), "verification_ms": time.Since(verifyStart).Milliseconds(), "audit_rows": len(afterAudit), "receipt_replay_preserved": true, "revocation_preserved": true}
	encoded, err := json.Marshal(evidence)
	if err != nil {
		t.Fatal(err)
	}
	t.Log(fmt.Sprintf("RESTORE_EVIDENCE %s", encoded))
}
