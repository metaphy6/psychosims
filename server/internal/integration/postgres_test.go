//go:build postgres

package integration

import (
	"context"
	"crypto/ed25519"
	"database/sql"
	"encoding/json"
	"fmt"
	"net/http"
	"net/http/httptest"
	"os"
	"strings"
	"sync"
	"testing"
	"time"

	"psychosims.dev/server/internal/audit"
	"psychosims.dev/server/internal/canonicaljson"
	"psychosims.dev/server/internal/config"
	"psychosims.dev/server/internal/crypto"
	"psychosims.dev/server/internal/ctxutil"
	"psychosims.dev/server/internal/devicekeys"
	"psychosims.dev/server/internal/idempotency"
	"psychosims.dev/server/internal/offline"
	"psychosims.dev/server/internal/ownership"
	"psychosims.dev/server/internal/presence"
	"psychosims.dev/server/internal/profile"
	"psychosims.dev/server/internal/receipts"
	"psychosims.dev/server/internal/ruleset"
	"psychosims.dev/server/internal/schemas"
	"psychosims.dev/server/internal/server"
	"psychosims.dev/server/internal/store"
	"psychosims.dev/server/internal/timeutil"
)

func postgresStore(t *testing.T) *store.Store {
	t.Helper()
	dsn := os.Getenv("PSY_TEST_DATABASE_DSN")
	if dsn == "" {
		t.Fatal("PSY_TEST_DATABASE_DSN is required for the postgres integration gate")
	}
	cfg := config.Default()
	cfg.DatabaseDSN = dsn
	cfg.DatabasePoolMax = 20
	st, err := store.New(context.Background(), cfg)
	if err != nil {
		t.Fatal(err)
	}
	t.Cleanup(func() { st.Close() })
	_, err = st.DB().Exec(`TRUNCATE accounts, audit_log, idempotency_keys, oauth_states, oauth_start_requests, revoked_device_keys RESTART IDENTITY CASCADE`)
	if err != nil {
		t.Fatal(err)
	}
	return st
}

func sqlAccount(t *testing.T, db *sql.DB, account string) {
	t.Helper()
	_, err := db.Exec(`INSERT INTO accounts(id) VALUES($1);`, account)
	if err != nil {
		t.Fatal(err)
	}
	_, err = db.Exec(`INSERT INTO profiles(account_id, payload) VALUES($1, '{"xp":5,"owned_card_ids":["open_question"],"version":1}')`, account)
	if err != nil {
		t.Fatal(err)
	}
}

func sqlReceipt(t *testing.T, st *store.Store, account, patient, receiptID string, auditor audit.Appender) (*receipts.Service, schemas.SignedEnvelope, context.Context, ed25519.PrivateKey) {
	t.Helper()
	keys := devicekeys.NewService(devicekeys.NewInMemoryRepository())
	pub, priv, err := ed25519.GenerateKey(nil)
	if err != nil {
		t.Fatal(err)
	}
	keyID, err := keys.Register(context.Background(), account, pub, string(crypto.SuiteEd25519V1))
	if err != nil {
		t.Fatal(err)
	}
	idem := idempotency.NewService(idempotency.NewSQLRepository(st.DB()), time.Hour)
	limits := receipts.DefaultLimits()
	validator := receipts.NewVerifier(receipts.NewVerifierFromDeviceKeys(keys), profile.NewSQLRepository(st.DB()), profile.NewLedger(st.DB()), idem, keys, &limits)
	validator.WithRuleset(ruleset.NewRegistry(ruleset.Config{KnownVersions: []string{"0.1.0"}, SunsetWindow: 24 * time.Hour}))
	service := receipts.NewService(validator, st.DB(), idem, auditor, nil)
	if err := ownership.NewService(ownership.NewSQLRepository(st.DB()), timeutil.RealClock{}).Claim(context.Background(), patient, account, 0, ownership.MemoryClassPersistent); err != nil {
		t.Fatal(err)
	}
	r := schemas.SessionReceipt{ID: receiptID, PatientID: patient, SchemaVersion: schemas.CurrentReceiptSchemaVersion, RulesetVersion: "0.1.0", IdempotencyKey: "shared-key", CorrelationID: "test-corr", TurnCount: 1,
		StartState: schemas.SessionStartState{Loadout: schemas.Loadout{CardIds: []string{"open_question"}, SlotCap: 6}, Library: schemas.CardLibrary{OwnedCardIds: []string{"open_question"}}}, Actions: []schemas.InteractionPattern{schemas.OpenQuestion},
		LedgerEvents: []schemas.LedgerEvent{}}
	auth, err := service.Authorize(context.Background(), account, patient, r.RulesetVersion, r.StartState)
	if err != nil {
		t.Fatal(err)
	}
	r.ID = auth.ID
	body, err := canonicaljson.Marshal(r)
	if err != nil {
		t.Fatal(err)
	}
	env := schemas.SignedEnvelope{CanonicalReceiptBytes: body, Signature: ed25519.Sign(priv, body), SuiteID: string(crypto.SuiteEd25519V1), SigningKeyID: keyID}
	ctx := ctxutil.WithIdempotencyKey(ctxutil.WithAccountID(context.Background(), account), r.IdempotencyKey)
	return service, env, ctx, priv
}

func countRows(t *testing.T, db *sql.DB, table string) int {
	t.Helper()
	var n int
	if err := db.QueryRow("SELECT COUNT(*) FROM " + table).Scan(&n); err != nil {
		t.Fatal(err)
	}
	return n
}

func TestPostgresSubmitExactlyOnce(t *testing.T) {
	st := postgresStore(t)
	sqlAccount(t, st.DB(), "a")
	service, env, ctx, _ := sqlReceipt(t, st, "a", "p", "r", audit.NewAppender(st.DB()))
	if _, err := service.Submit(ctx, "a", env); err != nil {
		t.Fatal(err)
	}
	if _, err := service.Submit(ctx, "a", env); err != nil {
		t.Fatal(err)
	}
	prof, err := profile.NewSQLRepository(st.DB()).Get(ctx, "a")
	if err != nil {
		t.Fatal(err)
	}
	if prof.XP != 5 {
		t.Errorf("unsigned/unfunded reward changed XP to %d; want 5", prof.XP)
	}
	if n := countRows(t, st.DB(), "idempotency_keys"); n != 1 {
		t.Errorf("idempotency rows=%d; want 1", n)
	}
	if n := countRows(t, st.DB(), "audit_log"); n != 1 {
		t.Errorf("acceptance rows=%d; want 1", n)
	}
}

type failingAudit struct{ audit.Appender }

func (f failingAudit) Append(context.Context, *sql.Tx, audit.Record) error {
	return fmt.Errorf("injected audit failure")
}
func TestPostgresSubmitRollback(t *testing.T) {
	st := postgresStore(t)
	sqlAccount(t, st.DB(), "a")
	service, env, ctx, _ := sqlReceipt(t, st, "a", "p", "r", failingAudit{audit.NewAppender(st.DB())})
	if _, err := service.Submit(ctx, "a", env); err == nil {
		t.Error("audit failure accepted")
	}
	prof, err := profile.NewSQLRepository(st.DB()).Get(ctx, "a")
	if err != nil {
		t.Fatal(err)
	}
	if prof.XP != 5 || prof.Version != 1 {
		t.Errorf("profile escaped rollback: %+v", prof)
	}
	if n := countRows(t, st.DB(), "ledger_events"); n != 0 {
		t.Errorf("ledger escaped rollback: %d", n)
	}
	if n := countRows(t, st.DB(), "idempotency_keys"); n != 0 {
		t.Errorf("idempotency escaped rollback: %d", n)
	}
}

func TestPostgresPresenceRoundTrip(t *testing.T) {
	st := postgresStore(t)
	sqlAccount(t, st.DB(), "a")
	pub, priv, _ := ed25519.GenerateKey(nil)
	repo := presence.NewSQLRepository(st.DB())
	svc := presence.NewService(repo, priv)
	if _, err := svc.Set(context.Background(), "a", "online", string(crypto.SuiteEd25519V1)); err != nil {
		t.Fatal(err)
	}
	rec, err := repo.Get(context.Background(), "a")
	if err != nil {
		t.Fatal(err)
	}
	if !svc.Verify(pub, rec) {
		t.Fatal("stored signature does not verify")
	}
	list, err := repo.ListByStatus(context.Background(), "online")
	if err != nil {
		t.Fatal(err)
	}
	if len(list) != 1 || !svc.Verify(pub, &list[0]) {
		t.Fatal("listed signature does not verify")
	}
}

func TestPostgresOwnershipMemoryClass(t *testing.T) {
	st := postgresStore(t)
	sqlAccount(t, st.DB(), "a")
	repo := ownership.NewSQLRepository(st.DB())
	svc := ownership.NewService(repo, timeutil.RealClock{})
	if err := svc.Claim(context.Background(), "p", "a", 0, ownership.MemoryClassStateless); err != nil {
		t.Fatal(err)
	}
	rec, err := repo.Get(context.Background(), "p")
	if err != nil {
		t.Fatal(err)
	}
	if rec.MemoryClass != ownership.MemoryClassStateless {
		t.Errorf("memory class=%q", rec.MemoryClass)
	}
	if err := svc.Transition(context.Background(), "p", "a", ownership.StateOwned, ownership.StateHospitalized, rec.Version); err == nil {
		t.Error("stateless hospitalization accepted")
	}
}

func TestPostgresConcurrentAudit(t *testing.T) {
	st := postgresStore(t)
	a := audit.NewAppender(st.DB())
	var wg sync.WaitGroup
	errs := make(chan error, 16)
	for i := 0; i < 16; i++ {
		wg.Go(func() { errs <- a.AppendDirect(context.Background(), audit.Record{AccountID: "a", Action: "test"}) })
	}
	wg.Wait()
	close(errs)
	for err := range errs {
		if err != nil {
			t.Fatal(err)
		}
	}
	rows, err := a.ValidateChain(context.Background())
	if err != nil {
		t.Fatal(err)
	}
	if len(rows) != 16 {
		t.Fatal(len(rows))
	}
}

func TestPostgresFirstBootCreatesProfile(t *testing.T) {
	st := postgresStore(t)
	srv := server.New(timeutil.RealClock{}, server.WithProfileRepo(profile.NewSQLRepository(st.DB())))
	req := httptest.NewRequest(http.MethodGet, "/v1/boot", nil)
	req = req.WithContext(ctxutil.WithAccountID(req.Context(), "first-account"))
	w := httptest.NewRecorder()
	srv.Handler().ServeHTTP(w, req)
	if w.Code != http.StatusOK {
		t.Fatalf("boot=%d %s", w.Code, w.Body.String())
	}
	var body server.BootResponse
	if err := json.Unmarshal(w.Body.Bytes(), &body); err != nil {
		t.Fatal(err)
	}
	if body.Profile.Version != 1 || body.Profile.AccountID != "first-account" {
		t.Fatalf("invalid first profile: %+v", body.Profile)
	}
	if n := countRows(t, st.DB(), "accounts"); n != 1 {
		t.Fatal(n)
	}
}

func TestPostgresConcurrentRetriesAndAccountScopedKeys(t *testing.T) {
	st := postgresStore(t)
	sqlAccount(t, st.DB(), "a")
	sqlAccount(t, st.DB(), "b")
	a, ae, ac, _ := sqlReceipt(t, st, "a", "pa", "ra", audit.NewAppender(st.DB()))
	b, be, bc, _ := sqlReceipt(t, st, "b", "pb", "rb", audit.NewAppender(st.DB()))
	var wg sync.WaitGroup
	errs := make(chan error, 24)
	for i := 0; i < 12; i++ {
		wg.Go(func() { _, err := a.Submit(ac, "a", ae); errs <- err })
		wg.Go(func() { _, err := b.Submit(bc, "b", be); errs <- err })
	}
	wg.Wait()
	close(errs)
	for err := range errs {
		if err != nil {
			t.Fatal(err)
		}
	}
	for _, account := range []string{"a", "b"} {
		p, err := profile.NewSQLRepository(st.DB()).Get(context.Background(), account)
		if err != nil {
			t.Fatal(err)
		}
		if p.XP != 5 || p.Version != 2 {
			t.Fatalf("profile %+v", p)
		}
	}
	if n := countRows(t, st.DB(), "idempotency_keys"); n != 2 {
		t.Fatal(n)
	}
	rows, err := audit.NewAppender(st.DB()).ValidateChain(context.Background())
	if err != nil {
		t.Fatal(err)
	}
	if len(rows) != 2 {
		t.Fatal(len(rows))
	}
	// Retrying after cache GC uses the permanent consumed grant and cannot mutate twice.
	if _, err := st.DB().Exec(`DELETE FROM idempotency_keys`); err != nil {
		t.Fatal(err)
	}
	if _, err := a.Submit(ac, "a", ae); err != nil {
		t.Fatal(err)
	}
	p, _ := profile.NewSQLRepository(st.DB()).Get(ac, "a")
	if p.Version != 2 {
		t.Fatal(p.Version)
	}
}

func TestPostgresAuthoritativeReceiptRejections(t *testing.T) {
	for _, test := range []string{"unowned_card", "foreign_patient", "expired_lease", "changed_start", "client_reward", "key_reuse", "missing_permit"} {
		t.Run(test, func(t *testing.T) {
			st := postgresStore(t)
			sqlAccount(t, st.DB(), "a")
			svc, env, ctx, priv := sqlReceipt(t, st, "a", "p", "r", audit.NewAppender(st.DB()))
			var r schemas.SessionReceipt
			if err := json.Unmarshal(env.CanonicalReceiptBytes, &r); err != nil {
				t.Fatal(err)
			}
			switch test {
			case "unowned_card":
				_, err := st.DB().Exec(`UPDATE profiles SET payload=jsonb_set(payload,'{owned_card_ids}','[]')`)
				if err != nil {
					t.Fatal(err)
				}
			case "foreign_patient":
				sqlAccount(t, st.DB(), "b")
				_, err := st.DB().Exec(`UPDATE ownership_records SET account_id='b' WHERE patient_id='p'`)
				if err != nil {
					t.Fatal(err)
				}
			case "expired_lease":
				_, err := st.DB().Exec(`UPDATE ownership_records SET lease_expires_at=NOW()-INTERVAL '1 second'`)
				if err != nil {
					t.Fatal(err)
				}
			case "changed_start":
				r.StartState.RootSeed++
			case "client_reward":
				r.LedgerEvents = []schemas.LedgerEvent{{Currency: schemas.CurrencyCash, AmountMicros: 100, IdempotencyKey: "mint"}, {Currency: schemas.CurrencyCash, AmountMicros: -100, IdempotencyKey: "fake_sink"}}
			case "missing_permit":
				r.ID = "unknown"
			case "key_reuse":
				if _, err := svc.Submit(ctx, "a", env); err != nil {
					t.Fatal(err)
				}
				r.CorrelationID = "different"
			}
			body, err := canonicaljson.Marshal(r)
			if err != nil {
				t.Fatal(err)
			}
			env.CanonicalReceiptBytes = body
			env.Signature = ed25519.Sign(priv, body)
			if _, err := svc.Submit(ctx, "a", env); err == nil {
				t.Fatal("unauthorized receipt accepted")
			}
			p, _ := profile.NewSQLRepository(st.DB()).Get(ctx, "a")
			wantVersion := 1
			if test == "key_reuse" {
				wantVersion = 2
			}
			if p.Version != wantVersion || p.XP != 5 {
				t.Fatalf("rejection changed profile: %+v", p)
			}
		})
	}
}

func TestPostgresConcurrentMigrationsAndAtomicFailure(t *testing.T) {
	st := postgresStore(t)
	ctx := context.Background()
	if err := st.MigrateDown(ctx, 0); err != nil {
		t.Fatal(err)
	}
	cfg := config.Default()
	cfg.DatabaseDSN = os.Getenv("PSY_TEST_DATABASE_DSN")
	var wg sync.WaitGroup
	errs := make(chan error, 8)
	for i := 0; i < 8; i++ {
		wg.Go(func() {
			other, err := store.New(ctx, cfg)
			if err == nil {
				other.Close()
			}
			errs <- err
		})
	}
	wg.Wait()
	close(errs)
	for err := range errs {
		if err != nil {
			t.Fatal(err)
		}
	}
	if err := st.MigrateDown(ctx, 5); err != nil {
		t.Fatal(err)
	}
	_, err := st.DB().Exec(`CREATE FUNCTION reject_migration() RETURNS TRIGGER LANGUAGE plpgsql AS $$ BEGIN RAISE EXCEPTION 'forced migration bookkeeping failure'; END $$;
 CREATE TRIGGER reject_migration BEFORE INSERT ON schema_migrations FOR EACH ROW EXECUTE FUNCTION reject_migration();`)
	if err != nil {
		t.Fatal(err)
	}
	if err := st.MigrateUp(ctx); err == nil {
		t.Fatal("injected migration failure accepted")
	}
	var n int
	if err := st.DB().QueryRow(`SELECT count(*) FROM information_schema.columns WHERE table_schema='public' AND table_name='presence' AND column_name='suite_id'`).Scan(&n); err != nil {
		t.Fatal(err)
	}
	if n != 0 {
		t.Fatal("migration DDL escaped rollback")
	}
	if _, err := st.DB().Exec(`DROP TRIGGER reject_migration ON schema_migrations;DROP FUNCTION reject_migration();`); err != nil {
		t.Fatal(err)
	}
	if err := st.MigrateUp(ctx); err != nil {
		t.Fatal(err)
	}
}

func TestPostgresCommitFailureRollsBackAndRetries(t *testing.T) {
	st := postgresStore(t)
	sqlAccount(t, st.DB(), "a")
	svc, env, ctx, _ := sqlReceipt(t, st, "a", "p", "r", audit.NewAppender(st.DB()))
	_, err := st.DB().Exec(`CREATE FUNCTION reject_accept_commit() RETURNS TRIGGER LANGUAGE plpgsql AS $$ BEGIN RAISE EXCEPTION 'forced deferred failure'; END $$;
 CREATE CONSTRAINT TRIGGER reject_accept_commit AFTER INSERT ON audit_log DEFERRABLE INITIALLY DEFERRED FOR EACH ROW EXECUTE FUNCTION reject_accept_commit();`)
	if err != nil {
		t.Fatal(err)
	}
	if _, err := svc.Submit(ctx, "a", env); err == nil {
		t.Fatal("failed commit accepted")
	}
	p, err := profile.NewSQLRepository(st.DB()).Get(ctx, "a")
	if err != nil {
		t.Fatal(err)
	}
	if p.Version != 1 || p.XP != 5 {
		t.Fatalf("profile escaped failed commit: %+v", p)
	}
	if n := countRows(t, st.DB(), "idempotency_keys"); n != 0 {
		t.Fatalf("reservation escaped failed commit: %d", n)
	}
	var consumed int
	if err := st.DB().QueryRow(`SELECT count(*) FROM session_authorizations WHERE consumed_at IS NOT NULL`).Scan(&consumed); err != nil {
		t.Fatal(err)
	}
	if consumed != 0 {
		t.Fatal("authorization consumed despite failed commit")
	}
	if _, err := st.DB().Exec(`DROP TRIGGER reject_accept_commit ON audit_log;DROP FUNCTION reject_accept_commit();`); err != nil {
		t.Fatal(err)
	}
	if _, err := svc.Submit(ctx, "a", env); err != nil {
		t.Fatal(err)
	}
	p, err = profile.NewSQLRepository(st.DB()).Get(ctx, "a")
	if err != nil {
		t.Fatal(err)
	}
	if p.Version != 2 || p.XP != 5 {
		t.Fatalf("retry: %+v", p)
	}
}

func TestPostgresBatchUsesAtomicLeaseValidation(t *testing.T) {
	st := postgresStore(t)
	sqlAccount(t, st.DB(), "a")
	svc, env, ctx, _ := sqlReceipt(t, st, "a", "p", "r", audit.NewAppender(st.DB()))
	batch := offline.NewService(svc.Submit, ownership.NewSQLRepository(st.DB()), timeutil.RealClock{}, time.Hour)
	if _, err := st.DB().Exec(`UPDATE ownership_records SET lease_expires_at=NOW()-INTERVAL '1 second' WHERE patient_id='p'`); err != nil {
		t.Fatal(err)
	}
	response, err := batch.SubmitBatch(ctx, "a", offline.BatchRequest{Envelopes: []schemas.SignedEnvelope{env}})
	if err != nil {
		t.Fatal(err)
	}
	if len(response.Results) != 1 || response.Results[0].Status != "rejected" || response.Results[0].Code != "lease_expired" {
		t.Fatalf("batch %+v", response)
	}
	if n := countRows(t, st.DB(), "idempotency_keys"); n != 0 {
		t.Fatal(n)
	}
	if _, err := st.DB().Exec(`UPDATE ownership_records SET lease_expires_at=NOW()+INTERVAL '1 hour' WHERE patient_id='p'`); err != nil {
		t.Fatal(err)
	}
	response, err = batch.SubmitBatch(ctx, "a", offline.BatchRequest{Envelopes: []schemas.SignedEnvelope{env}})
	if err != nil {
		t.Fatal(err)
	}
	if response.Results[0].Status != "accepted" {
		t.Fatalf("batch retry %+v", response)
	}
}

func TestPostgresDoesNotPersistUnknownTranscriptFields(t *testing.T) {
	st := postgresStore(t)
	sqlAccount(t, st.DB(), "a")
	svc, env, ctx, priv := sqlReceipt(t, st, "a", "p", "r", audit.NewAppender(st.DB()))
	var wire map[string]any
	if err := json.Unmarshal(env.CanonicalReceiptBytes, &wire); err != nil {
		t.Fatal(err)
	}
	wire["raw_transcript"] = "private generated dialogue"
	body, err := canonicaljson.Marshal(wire)
	if err != nil {
		t.Fatal(err)
	}
	env.CanonicalReceiptBytes = body
	env.Signature = ed25519.Sign(priv, body)
	if _, err := svc.Submit(ctx, "a", env); err != nil {
		t.Fatal(err)
	}
	var persisted []byte
	if err := st.DB().QueryRow(`SELECT receipt_bytes FROM session_authorizations WHERE account_id='a'`).Scan(&persisted); err != nil {
		t.Fatal(err)
	}
	if strings.Contains(string(persisted), "private generated dialogue") {
		t.Fatal("raw transcript persisted outside the structured receipt contract")
	}
}

func TestPostgresUpgradeBackfillsLegacyInventory(t *testing.T) {
	st := postgresStore(t)
	ctx := context.Background()
	if err := st.MigrateDown(ctx, 5); err != nil {
		t.Fatal(err)
	}
	_, err := st.DB().Exec(`INSERT INTO accounts(id) VALUES('legacy'),('explicit');
 INSERT INTO profiles(account_id,version,payload) VALUES
 ('legacy',7,'{"xp":77,"cash_micros":1234}'),('explicit',4,'{"owned_card_ids":[],"xp":11}');`)
	if err != nil {
		t.Fatal(err)
	}
	if err := st.MigrateUp(ctx); err != nil {
		t.Fatal(err)
	}
	p, err := profile.NewSQLRepository(st.DB()).Get(ctx, "legacy")
	if err != nil {
		t.Fatal(err)
	}
	if len(p.OwnedCardIDs) != 1 || p.OwnedCardIDs[0] != "open_question" || p.XP != 77 || p.CashMicros != 1234 || p.Version != 8 {
		t.Fatalf("legacy upgrade: %+v", p)
	}
	explicit, err := profile.NewSQLRepository(st.DB()).Get(ctx, "explicit")
	if err != nil {
		t.Fatal(err)
	}
	if len(explicit.OwnedCardIDs) != 0 || explicit.XP != 11 || explicit.Version != 4 {
		t.Fatalf("explicit inventory overwritten: %+v", explicit)
	}
	svc, env, sessionCtx, _ := sqlReceipt(t, st, "legacy", "legacy-patient", "r", audit.NewAppender(st.DB()))
	if _, err := svc.Submit(sessionCtx, "legacy", env); err != nil {
		t.Fatal(err)
	}
}

func TestPostgresAuthorizationReplacesStaleOwnershipGrant(t *testing.T) {
	for _, change := range []string{"same_owner_version", "new_owner"} {
		t.Run(change, func(t *testing.T) {
			st := postgresStore(t)
			sqlAccount(t, st.DB(), "a")
			sqlAccount(t, st.DB(), "b")
			svc, oldEnv, ctx, priv := sqlReceipt(t, st, "a", "p", "r", audit.NewAppender(st.DB()))
			var r schemas.SessionReceipt
			if err := json.Unmarshal(oldEnv.CanonicalReceiptBytes, &r); err != nil {
				t.Fatal(err)
			}
			unchanged, err := svc.Authorize(ctx, "a", "p", r.RulesetVersion, r.StartState)
			if err != nil {
				t.Fatal(err)
			}
			if unchanged.ID != r.ID {
				t.Fatal("unchanged ownership did not reuse grant")
			}
			owner := "a"
			if change == "same_owner_version" {
				owns := ownership.NewService(ownership.NewSQLRepository(st.DB()), timeutil.RealClock{})
				if err := owns.Transition(ctx, "p", "a", ownership.StateOwned, ownership.StateHospitalized, 1); err != nil {
					t.Fatal(err)
				}
				if err := owns.Transition(ctx, "p", "a", ownership.StateHospitalized, ownership.StateOwned, 2); err != nil {
					t.Fatal(err)
				}
			} else {
				owner = "b"
				if _, err := st.DB().Exec(`UPDATE ownership_records SET account_id='b',version=version+1 WHERE patient_id='p'`); err != nil {
					t.Fatal(err)
				}
			}
			fresh, err := svc.Authorize(context.Background(), owner, "p", r.RulesetVersion, r.StartState)
			if err != nil {
				t.Fatal(err)
			}
			if fresh.ID == r.ID {
				t.Fatal("stale ownership grant reused")
			}
			if _, err := svc.Submit(ctx, "a", oldEnv); err == nil {
				t.Fatal("old grant remained usable")
			}
			var pending int
			if err := st.DB().QueryRow(`SELECT COUNT(*) FROM session_authorizations WHERE patient_id='p' AND consumed_at IS NULL`).Scan(&pending); err != nil {
				t.Fatal(err)
			}
			if pending != 1 {
				t.Fatalf("pending grants=%d", pending)
			}
			if change == "same_owner_version" {
				r.ID = fresh.ID
				body, err := canonicaljson.Marshal(r)
				if err != nil {
					t.Fatal(err)
				}
				oldEnv.CanonicalReceiptBytes = body
				oldEnv.Signature = ed25519.Sign(priv, body)
				if _, err := svc.Submit(ctx, "a", oldEnv); err != nil {
					t.Fatal(err)
				}
			}
		})
	}
}

func TestPostgresOwnershipLockCannotExtendExpiredLease(t *testing.T) {
	for _, operation := range []string{"submit", "authorize"} {
		t.Run(operation, func(t *testing.T) {
			st := postgresStore(t)
			sqlAccount(t, st.DB(), "a")
			svc, env, ctx, _ := sqlReceipt(t, st, "a", "p", "r", audit.NewAppender(st.DB()))
			var r schemas.SessionReceipt
			if err := json.Unmarshal(env.CanonicalReceiptBytes, &r); err != nil {
				t.Fatal(err)
			}
			var expires time.Time
			if err := st.DB().QueryRow(`UPDATE ownership_records SET lease_expires_at=clock_timestamp()+INTERVAL '1 second' WHERE patient_id='p' RETURNING lease_expires_at`).Scan(&expires); err != nil {
				t.Fatal(err)
			}
			if _, err := st.DB().Exec(`UPDATE session_authorizations SET expires_at=$1 WHERE patient_id='p'`, expires); err != nil {
				t.Fatal(err)
			}
			lock, err := st.DB().BeginTx(ctx, nil)
			if err != nil {
				t.Fatal(err)
			}
			defer lock.Rollback()
			if _, err := lock.Exec(`SELECT patient_id FROM ownership_records WHERE patient_id='p' FOR UPDATE`); err != nil {
				t.Fatal(err)
			}
			requestCtx, cancel := context.WithTimeout(ctx, 5*time.Second)
			defer cancel()
			result := make(chan error, 1)
			go func() {
				if operation == "submit" {
					_, err := svc.Submit(requestCtx, "a", env)
					result <- err
				} else {
					_, err := svc.Authorize(requestCtx, "a", "p", r.RulesetVersion, r.StartState)
					result <- err
				}
			}()
			deadline := time.Now().Add(750 * time.Millisecond)
			waiting := false
			for time.Now().Before(deadline) {
				if err := st.DB().QueryRow(`SELECT EXISTS(SELECT 1 FROM pg_stat_activity WHERE datname=current_database() AND wait_event_type='Lock' AND query LIKE '%FROM ownership_records WHERE patient_id=%FOR UPDATE%')`).Scan(&waiting); err != nil {
					t.Fatal(err)
				}
				if waiting {
					break
				}
				time.Sleep(5 * time.Millisecond)
			}
			if !waiting {
				t.Fatal("request never waited for ownership lock before expiry")
			}
			time.Sleep(time.Until(expires) + 30*time.Millisecond)
			if err := lock.Commit(); err != nil {
				t.Fatal(err)
			}
			if err := <-result; err == nil {
				t.Fatal("request accepted after lease expired while waiting for lock")
			}
			p, err := profile.NewSQLRepository(st.DB()).Get(ctx, "a")
			if err != nil {
				t.Fatal(err)
			}
			if p.Version != 1 {
				t.Fatal("expired request changed profile")
			}
		})
	}
}

func TestPostgresAuthorityRejectionsAreAudited(t *testing.T) {
	for _, reason := range []string{"authorization", "reward", "altered_replay"} {
		t.Run(reason, func(t *testing.T) {
			st := postgresStore(t)
			sqlAccount(t, st.DB(), "a")
			auditor := audit.NewAppender(st.DB())
			svc, env, ctx, priv := sqlReceipt(t, st, "a", "p", "r", auditor)
			var r schemas.SessionReceipt
			if err := json.Unmarshal(env.CanonicalReceiptBytes, &r); err != nil {
				t.Fatal(err)
			}
			switch reason {
			case "authorization":
				r.ID = "unknown-permit"
			case "reward":
				r.LedgerEvents = []schemas.LedgerEvent{{Currency: schemas.CurrencyCash, AmountMicros: 10, IdempotencyKey: "gain"}, {Currency: schemas.CurrencyCash, AmountMicros: -10, IdempotencyKey: "fake-sink"}}
			case "altered_replay":
				if _, err := svc.Submit(ctx, "a", env); err != nil {
					t.Fatal(err)
				}
			}
			r.CorrelationID = "changed-correlation"
			body, err := canonicaljson.Marshal(r)
			if err != nil {
				t.Fatal(err)
			}
			env.CanonicalReceiptBytes = body
			env.Signature = ed25519.Sign(priv, body)
			if _, err := svc.Submit(ctx, "a", env); err == nil {
				t.Fatal("expected rejection")
			}
			rows, err := auditor.ValidateChain(ctx)
			if err != nil {
				t.Fatal(err)
			}
			rejected := 0
			for _, row := range rows {
				if row.Action == "receipt_reject" {
					rejected++
					if row.Outcome == "" {
						t.Fatal("missing rejection code")
					}
				}
			}
			if rejected != 1 {
				t.Fatalf("rejection audit rows=%d; want 1", rejected)
			}
			serialized, err := json.Marshal(rows)
			if err != nil {
				t.Fatal(err)
			}
			if strings.Contains(string(serialized), "private raw dialogue") {
				t.Fatal("raw receipt data reached audit")
			}
		})
	}
}

func TestPostgresAuditLockCannotExtendExpiredLease(t *testing.T) {
	st := postgresStore(t)
	sqlAccount(t, st.DB(), "a")
	svc, env, ctx, _ := sqlReceipt(t, st, "a", "p", "r", audit.NewAppender(st.DB()))
	var expires time.Time
	if err := st.DB().QueryRow(`UPDATE ownership_records SET lease_expires_at=clock_timestamp()+INTERVAL '1 second' WHERE patient_id='p' RETURNING lease_expires_at`).Scan(&expires); err != nil {
		t.Fatal(err)
	}
	lock, err := st.DB().BeginTx(ctx, nil)
	if err != nil {
		t.Fatal(err)
	}
	defer lock.Rollback()
	// Hold the same serialized audit writer lock that acceptance will acquire.
	if _, err := lock.Exec(`SELECT pg_advisory_xact_lock(736002)`); err != nil {
		t.Fatal(err)
	}
	requestCtx, cancel := context.WithTimeout(ctx, 5*time.Second)
	defer cancel()
	result := make(chan error, 1)
	go func() { _, err := svc.Submit(requestCtx, "a", env); result <- err }()
	deadline := time.Now().Add(750 * time.Millisecond)
	waiting := false
	for time.Now().Before(deadline) {
		if err := st.DB().QueryRow(`SELECT EXISTS(SELECT 1 FROM pg_stat_activity WHERE datname=current_database() AND wait_event_type='Lock' AND query='SELECT pg_advisory_xact_lock(736002)')`).Scan(&waiting); err != nil {
			t.Fatal(err)
		}
		if waiting {
			break
		}
		time.Sleep(5 * time.Millisecond)
	}
	if !waiting {
		t.Fatal("receipt never waited for audit lock")
	}
	time.Sleep(time.Until(expires) + 30*time.Millisecond)
	if err := lock.Commit(); err != nil {
		t.Fatal(err)
	}
	if err := <-result; err == nil {
		t.Fatal("receipt accepted after expiry while waiting on audit lock")
	}
	p, err := profile.NewSQLRepository(st.DB()).Get(ctx, "a")
	if err != nil {
		t.Fatal(err)
	}
	if p.Version != 1 {
		t.Fatal("profile escaped expiry rollback")
	}
	rows, err := audit.NewAppender(st.DB()).ValidateChain(ctx)
	if err != nil {
		t.Fatal(err)
	}
	if len(rows) != 1 || rows[0].Action != "receipt_reject" {
		t.Fatalf("audit after rollback: %+v", rows)
	}
}

func TestPostgresRejectsDialogueInTypedReceiptFields(t *testing.T) {
	st := postgresStore(t)
	sqlAccount(t, st.DB(), "a")
	svc, env, ctx, priv := sqlReceipt(t, st, "a", "p", "r", audit.NewAppender(st.DB()))
	var r schemas.SessionReceipt
	if err := json.Unmarshal(env.CanonicalReceiptBytes, &r); err != nil {
		t.Fatal(err)
	}
	r.CorrelationID = "synthetic private dialogue sentinel"
	wire, err := canonicaljson.Marshal(r)
	if err != nil {
		t.Fatal(err)
	}
	env.CanonicalReceiptBytes = wire
	env.Signature = ed25519.Sign(priv, wire)
	for i := 0; i < 2; i++ {
		if _, err := svc.Submit(ctx, "a", env); err == nil {
			t.Error("dialogue receipt accepted")
		}
	}
	var stored int
	if err := st.DB().QueryRow(`SELECT count(*) FROM session_authorizations WHERE receipt_bytes IS NOT NULL`).Scan(&stored); err != nil {
		t.Fatal(err)
	}
	if stored != 0 {
		t.Fatal("dialogue receipt persisted")
	}
	rows, err := audit.NewAppender(st.DB()).ValidateChain(ctx)
	if err != nil {
		t.Fatal(err)
	}
	b, err := json.Marshal(rows)
	if err != nil {
		t.Fatal(err)
	}
	if strings.Contains(string(b), r.CorrelationID) {
		t.Fatal("dialogue reached audit")
	}
}

func TestPostgresSigningKeyLookupHonorsCancelledRequest(t *testing.T) {
	st := postgresStore(t)
	sqlAccount(t, st.DB(), "a")
	keys := devicekeys.NewService(devicekeys.NewSQLRepository(st.DB()))
	pub, priv, _ := ed25519.GenerateKey(nil)
	keyID, err := keys.Register(context.Background(), "a", pub, "ed25519-v1")
	if err != nil {
		t.Fatal(err)
	}
	st.DB().SetMaxOpenConns(1)
	conn, err := st.DB().Conn(context.Background())
	if err != nil {
		t.Fatal(err)
	}
	var closeOnce sync.Once
	release := func() { closeOnce.Do(func() { conn.Close() }) }
	defer release()
	timer := time.AfterFunc(500*time.Millisecond, release)
	defer timer.Stop()
	limits := receipts.DefaultLimits()
	v := receipts.NewVerifier(receipts.NewVerifierFromDeviceKeys(keys), nil, nil, nil, keys, &limits)
	wire := []byte(`{}`)
	env := schemas.SignedEnvelope{CanonicalReceiptBytes: wire, Signature: ed25519.Sign(priv, wire), SigningKeyID: keyID, SuiteID: "ed25519-v1"}
	ctx, cancel := context.WithCancel(context.Background())
	cancel()
	started := time.Now()
	if _, err := v.Validate(ctx, "a", env); err == nil {
		t.Fatal("cancelled request accepted")
	}
	if time.Since(started) > 200*time.Millisecond {
		t.Fatal("first key lookup ignored request cancellation and waited for pool")
	}
}
