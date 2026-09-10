//go:build postgres

package integration

import (
	"bytes"
	"context"
	"crypto/ed25519"
	"crypto/sha256"
	"encoding/hex"
	"encoding/json"
	"io"
	"net/http"
	"net/http/httptest"
	"os"
	"sync"
	"testing"
	"time"

	"psychosims.dev/server/internal/api"
	"psychosims.dev/server/internal/audit"
	"psychosims.dev/server/internal/canonicaljson"
	"psychosims.dev/server/internal/config"
	"psychosims.dev/server/internal/ctxutil"
	"psychosims.dev/server/internal/devicekeys"
	"psychosims.dev/server/internal/idempotency"
	"psychosims.dev/server/internal/outcomes"
	"psychosims.dev/server/internal/ownership"
	"psychosims.dev/server/internal/profile"
	"psychosims.dev/server/internal/receipts"
	"psychosims.dev/server/internal/ruleset"
	"psychosims.dev/server/internal/schemas"
	"psychosims.dev/server/internal/server"
	"psychosims.dev/server/internal/store"
	"psychosims.dev/server/internal/timeutil"
	"psychosims.dev/server/internal/tokens"
)

func trustedFixture(t *testing.T) (*outcomes.Catalog, string, schemas.SessionReceipt) {
	return trustedFixtureForRules(t, "0.1.0")
}
func trustedFixtureForRules(t *testing.T, rules string) (*outcomes.Catalog, string, schemas.SessionReceipt) {
	t.Helper()
	body, err := os.ReadFile("../../../test_fixtures/outcomes/trusted_catalog_v1.json")
	if err != nil {
		t.Fatal(err)
	}
	h := sha256.Sum256(body)
	c, err := outcomes.Load(bytes.NewReader(body), hex.EncodeToString(h[:]), nil)
	if err != nil {
		t.Fatal(err)
	}
	var artifact struct {
		Proofs []struct {
			SHA   string `json:"proof_sha256"`
			Proof struct {
				Start    schemas.SessionStartState    `json:"start_state"`
				Actions  []schemas.InteractionPattern `json:"actions"`
				Deltas   []schemas.StructuredDelta    `json:"deltas"`
				Turns    int                          `json:"turn_count"`
				Manifest struct {
					Rules string `json:"ruleset_version"`
				} `json:"manifest"`
			} `json:"proof"`
		} `json:"proofs"`
	}
	if err = json.Unmarshal(body, &artifact); err != nil {
		t.Fatal(err)
	}
	for _, p := range artifact.Proofs {
		// These mutation tests need another owned action to distinguish an
		// unproven path from the earlier unowned-card rejection boundary.
		// The real Flutter flow separately exercises the fresh one-card starter.
		if p.Proof.Manifest.Rules == rules && len(p.Proof.Start.Library.OwnedCardIds) == 4 {
			return c, p.SHA, schemas.SessionReceipt{SchemaVersion: schemas.CurrentReceiptSchemaVersion, RulesetVersion: p.Proof.Manifest.Rules, StartState: p.Proof.Start, Actions: p.Proof.Actions, Deltas: p.Proof.Deltas, TurnCount: p.Proof.Turns, IdempotencyKey: "certified-test", CorrelationID: "certified-test"}
		}
	}
	t.Fatal("missing shipped proof")
	return nil, "", schemas.SessionReceipt{}
}
func certifiedService(t *testing.T, st *store.Store, c *outcomes.Catalog, auditor audit.Appender, policy config.CureRewardPolicy) *receipts.Service {
	t.Helper()
	keys := devicekeys.NewService(devicekeys.NewSQLRepository(st.DB()))
	idem := idempotency.NewService(idempotency.NewSQLRepository(st.DB()), time.Hour)
	limits := receipts.DefaultLimits()
	v := receipts.NewVerifier(receipts.NewVerifierFromDeviceKeys(keys), profile.NewSQLRepository(st.DB()), profile.NewLedger(st.DB()), idem, keys, &limits).WithRuleset(ruleset.NewRegistry(ruleset.Config{KnownVersions: []string{"0.1.0", "poc-1.0.0"}, SunsetWindow: 24 * time.Hour}))
	s := receipts.NewService(v, st.DB(), idem, auditor, nil)
	if err := s.ConfigureCertifiedOutcomes(c, policy, true); err != nil {
		t.Fatal(err)
	}
	return s
}
func certifiedSubmission(t *testing.T, st *store.Store, c *outcomes.Catalog, id string, r schemas.SessionReceipt, service *receipts.Service) (schemas.SignedEnvelope, context.Context) {
	t.Helper()
	ctx := ctxutil.WithIdempotencyKey(ctxutil.WithAccountID(context.Background(), "certified-account"), r.IdempotencyKey)
	sqlAccount(t, st.DB(), "certified-account")
	prof, err := profile.NewSQLRepository(st.DB()).Get(ctx, "certified-account")
	if err != nil {
		t.Fatal(err)
	}
	prof.OwnedCardIDs = r.StartState.Library.OwnedCardIds
	if err = profile.NewSQLRepository(st.DB()).Update(ctx, prof); err != nil {
		t.Fatal(err)
	}
	r.PatientID = "certified-patient"
	return certifiedExistingAccountSubmission(t, st, c, id, r, service)
}
func certifiedExistingAccountSubmission(t *testing.T, st *store.Store, c *outcomes.Catalog, id string, r schemas.SessionReceipt, service *receipts.Service) (schemas.SignedEnvelope, context.Context) {
	t.Helper()
	ctx := ctxutil.WithIdempotencyKey(ctxutil.WithAccountID(context.Background(), "certified-account"), r.IdempotencyKey)
	pub, priv, err := ed25519.GenerateKey(nil)
	if err != nil {
		t.Fatal(err)
	}
	key, err := devicekeys.NewService(devicekeys.NewSQLRepository(st.DB())).Register(ctx, "certified-account", pub, "ed25519-v1")
	if err != nil {
		t.Fatal(err)
	}
	if err = ownership.NewService(ownership.NewSQLRepository(st.DB()), timeutil.RealClock{}).Claim(ctx, r.PatientID, "certified-account", 0, ownership.MemoryClassPersistent); err != nil {
		t.Fatal(err)
	}
	h := sha256.Sum256([]byte("bounded-start-request:" + r.PatientID))
	permit, err := service.AuthorizeCertifiedRequest(ctx, "certified-account", r.PatientID, r.RulesetVersion, r.StartState, h[:], id)
	if err != nil {
		t.Fatal(err)
	}
	if permit.CertificateID != id || permit.CatalogSHA256 != c.ArtifactSHA256() {
		t.Fatal("durable permit lacks exact certificate pin")
	}
	r.ID = permit.ID
	body, err := canonicaljson.Marshal(r)
	if err != nil {
		t.Fatal(err)
	}
	return schemas.SignedEnvelope{CanonicalReceiptBytes: body, Signature: ed25519.Sign(priv, body), SuiteID: "ed25519-v1", SigningKeyID: key}, ctx
}

func TestPostgresCertifiedRewardAllWritesRollback(t *testing.T) {
	for _, target := range []string{"source_ledger", "receipt_write", "deferred_commit"} {
		t.Run(target, func(t *testing.T) {
			st := postgresStore(t)
			c, id, r := trustedFixture(t)
			s := certifiedService(t, st, c, audit.NewAppender(st.DB()), config.Default().CureRewards)
			env, ctx := certifiedSubmission(t, st, c, id, r, s)
			function := `CREATE FUNCTION reject_certified_write() RETURNS trigger LANGUAGE plpgsql AS $$ BEGIN RAISE EXCEPTION 'injected certified write failure'; END $$;`
			trigger := ""
			table := ""
			switch target {
			case "source_ledger":
				table = "ledger_events"
				trigger = `CREATE TRIGGER reject_certified BEFORE INSERT ON ledger_events FOR EACH ROW WHEN (NEW.account_id='system:certified-rewards') EXECUTE FUNCTION reject_certified_write();`
			case "receipt_write":
				table = "session_authorizations"
				trigger = `CREATE TRIGGER reject_certified BEFORE UPDATE ON session_authorizations FOR EACH ROW WHEN (NEW.consumed_at IS NOT NULL) EXECUTE FUNCTION reject_certified_write();`
			case "deferred_commit":
				table = "certified_cures"
				trigger = `CREATE CONSTRAINT TRIGGER reject_certified AFTER INSERT ON certified_cures DEFERRABLE INITIALLY DEFERRED FOR EACH ROW EXECUTE FUNCTION reject_certified_write();`
			}
			if _, err := st.DB().Exec(function + trigger); err != nil {
				t.Fatal(err)
			}
			t.Cleanup(func() {
				if _, err := st.DB().Exec(`DROP TRIGGER reject_certified ON ` + table + `;DROP FUNCTION reject_certified_write();`); err != nil {
					t.Error(err)
				}
			})
			if _, err := s.Submit(ctx, "certified-account", env); err == nil {
				t.Fatal("injected write failure accepted")
			}
			prof, err := profile.NewSQLRepository(st.DB()).Get(ctx, "certified-account")
			if err != nil {
				t.Fatal(err)
			}
			if prof.XP != 5 || prof.Version != 2 || countRows(t, st.DB(), "certified_cures") != 0 || countRows(t, st.DB(), "ledger_events") != 0 {
				t.Fatal("partial reward escaped rollback")
			}
			var consumed bool
			var state string
			if err = st.DB().QueryRow(`SELECT consumed_at IS NOT NULL FROM session_authorizations WHERE patient_id='certified-patient'`).Scan(&consumed); err != nil || consumed {
				t.Fatal("receipt escaped rollback")
			}
			if err = st.DB().QueryRow(`SELECT state FROM ownership_records WHERE patient_id='certified-patient'`).Scan(&state); err != nil || state != "owned" {
				t.Fatal("ownership escaped rollback")
			}
		})
	}
}

func TestPostgresCertifiedCooldownWindowAndOncePerCase(t *testing.T) {
	for _, scenario := range []string{"cooldown", "window_count", "already_cured"} {
		t.Run(scenario, func(t *testing.T) {
			st := postgresStore(t)
			c, id, r := trustedFixture(t)
			policy := config.Default().CureRewards
			if scenario == "window_count" {
				policy.MaxCuresPerWindow = 1
				policy.MinimumInterval = time.Second
			}
			s := certifiedService(t, st, c, audit.NewAppender(st.DB()), policy)
			env, ctx := certifiedSubmission(t, st, c, id, r, s)
			if _, err := s.Submit(ctx, "certified-account", env); err != nil {
				t.Fatal(err)
			}
			if scenario == "window_count" {
				if _, err := st.DB().Exec(`UPDATE certified_cures SET accepted_at=clock_timestamp()-interval '2 seconds'`); err != nil {
					t.Fatal(err)
				}
			}
			if scenario != "already_cured" {
				_, id, r = trustedFixtureForRules(t, "poc-1.0.0")
			}
			prof, err := profile.NewSQLRepository(st.DB()).Get(ctx, "certified-account")
			if err != nil {
				t.Fatal(err)
			}
			prof.OwnedCardIDs = []string{"open_question", "validate", "reflect", "reframe", "set_boundary", "disclose_parallel"}
			if err = profile.NewSQLRepository(st.DB()).Update(ctx, prof); err != nil {
				t.Fatal(err)
			}
			r.IdempotencyKey = "second-certified"
			r.PatientID = "second-patient"
			env, ctx = certifiedExistingAccountSubmission(t, st, c, id, r, s)
			accepted, err := s.Submit(ctx, "certified-account", env)
			if err != nil {
				t.Fatal(err)
			}
			verdict, err := s.AcceptanceVerdict(ctx, "certified-account", accepted.ID)
			if err != nil {
				t.Fatal(err)
			}
			reason := scenario
			if scenario == "window_count" {
				reason = "window_budget"
			}
			if verdict.RewardStatus != "certified_unrewarded" || verdict.Reason != reason || verdict.XP != 0 || countRows(t, st.DB(), "ledger_events") != 4 {
				t.Fatalf("eligibility bypass: %#v", verdict)
			}
			prof, err = profile.NewSQLRepository(st.DB()).Get(ctx, "certified-account")
			if err != nil || prof.XP != 5+policy.XP {
				t.Fatal("second cure paid beyond policy")
			}
		})
	}
}

func TestPostgresCertifiedCureExactlyOnceAndDurableVerdict(t *testing.T) {
	st := postgresStore(t)
	c, id, r := trustedFixture(t)
	policy := config.Default().CureRewards
	policy.CashMicros = 2_500_000
	policy.CashPerWindow = 25_000_000
	s := certifiedService(t, st, c, audit.NewAppender(st.DB()), policy)
	env, ctx := certifiedSubmission(t, st, c, id, r, s)
	var wg sync.WaitGroup
	failures := make(chan error, 8)
	for i := 0; i < 8; i++ {
		wg.Add(1)
		go func() { defer wg.Done(); _, err := s.Submit(ctx, "certified-account", env); failures <- err }()
	}
	wg.Wait()
	close(failures)
	for err := range failures {
		if err != nil {
			t.Fatal(err)
		}
	}
	var receipt schemas.SessionReceipt
	if err := json.Unmarshal(env.CanonicalReceiptBytes, &receipt); err != nil {
		t.Fatal(err)
	}
	verdict, err := s.AcceptanceVerdict(ctx, "certified-account", receipt.ID)
	if err != nil {
		t.Fatal(err)
	}
	if verdict.RewardStatus != "certified" || verdict.CertificateID != id || verdict.XP != policy.XP || verdict.StudyPoints != policy.Study || verdict.ProfileVersion != 3 || verdict.CashMicros != policy.CashMicros {
		t.Fatalf("wrong durable verdict: %#v", verdict)
	}
	prof, err := profile.NewSQLRepository(st.DB()).Get(ctx, "certified-account")
	if err != nil {
		t.Fatal(err)
	}
	if prof.XP != 5+policy.XP || prof.StudyPoints != policy.Study || prof.Version != 3 || prof.CashMicros != policy.CashMicros {
		t.Fatalf("reward mismatch %#v", prof)
	}
	if countRows(t, st.DB(), "certified_cures") != 1 || countRows(t, st.DB(), "ledger_events") != 6 {
		t.Fatal("duplicate or missing conserved reward")
	}
	var state string
	if err := st.DB().QueryRow(`SELECT state FROM ownership_records WHERE patient_id='certified-patient'`).Scan(&state); err != nil || state != "cured" {
		t.Fatalf("ownership cure=%s, %v", state, err)
	}
	var unbalanced int
	if err := st.DB().QueryRow(`SELECT COUNT(*) FROM (SELECT currency FROM ledger_events GROUP BY currency HAVING SUM(amount_micros)<>0) x`).Scan(&unbalanced); err != nil || unbalanced != 0 {
		t.Fatal("reward source and recipient do not conserve")
	}
	if _, err := st.DB().Exec(`DELETE FROM idempotency_keys`); err != nil {
		t.Fatal(err)
	}
	// Recreate composition with no currently enabled catalog; original acceptance
	// remains immutable after restart, catalog withdrawal and short-cache GC.
	restarted := certifiedService(t, st, nil, audit.NewAppender(st.DB()), policy)
	if _, err := restarted.Submit(ctx, "certified-account", env); err != nil {
		t.Fatal(err)
	}
	again, err := restarted.AcceptanceVerdict(ctx, "certified-account", receipt.ID)
	if err != nil || again != verdict {
		t.Fatalf("replay changed original verdict: %#v %v", again, err)
	}
	if countRows(t, st.DB(), "ledger_events") != 6 {
		t.Fatal("replay paid twice")
	}
}

func TestPostgresCertifiedRewardRollsBackWithAudit(t *testing.T) {
	st := postgresStore(t)
	c, id, r := trustedFixture(t)
	s := certifiedService(t, st, c, failingAudit{audit.NewAppender(st.DB())}, config.Default().CureRewards)
	env, ctx := certifiedSubmission(t, st, c, id, r, s)
	if _, err := s.Submit(ctx, "certified-account", env); err == nil {
		t.Fatal("injected audit failure accepted")
	}
	prof, err := profile.NewSQLRepository(st.DB()).Get(ctx, "certified-account")
	if err != nil {
		t.Fatal(err)
	}
	if prof.XP != 5 || prof.Version != 2 || countRows(t, st.DB(), "certified_cures") != 0 || countRows(t, st.DB(), "ledger_events") != 0 {
		t.Fatal("partial reward escaped rollback")
	}
	var state string
	if err := st.DB().QueryRow(`SELECT state FROM ownership_records WHERE patient_id='certified-patient'`).Scan(&state); err != nil || state != "owned" {
		t.Fatal("ownership escaped rollback")
	}
}

func TestPostgresHTTPCertifiedSessionAndReplayFeedback(t *testing.T) {
	st := postgresStore(t)
	proofs, proofID, r := trustedFixture(t)
	ctx := context.Background()
	cfg := config.Default()
	sqlAccount(t, st.DB(), "certified-account")
	repo := profile.NewSQLRepository(st.DB())
	prof, err := repo.Get(ctx, "certified-account")
	if err != nil {
		t.Fatal(err)
	}
	prof.OwnedCardIDs = r.StartState.Library.OwnedCardIds
	if err = repo.Update(ctx, prof); err != nil {
		t.Fatal(err)
	}
	pub, priv, err := ed25519.GenerateKey(nil)
	if err != nil {
		t.Fatal(err)
	}
	keyID, err := devicekeys.NewService(devicekeys.NewSQLRepository(st.DB())).Register(ctx, "certified-account", pub, "ed25519-v1")
	if err != nil {
		t.Fatal(err)
	}
	catalog, err := server.LoadCatalog([]string{"../../../content/manifests/siege_brumosis.json"})
	if err != nil {
		t.Fatal(err)
	}
	catalog = catalog.WithOutcomes(proofs)
	secret := []byte("local-certified-http-secret-32-bytes")
	tm := tokens.NewSQLManager(st.DB(), secret, time.Minute, time.Hour)
	pair, err := tm.IssuePair(ctx, "certified-account", "login")
	if err != nil {
		t.Fatal(err)
	}
	srv := server.NewOnline(cfg, st.DB(), nil, tm, catalog, secret)
	hs := httptest.NewServer(srv.Handler())
	defer hs.Close()
	call := func(endpoint, key string, in any) []byte {
		t.Helper()
		b, err := json.Marshal(in)
		if err != nil {
			t.Fatal(err)
		}
		req, err := http.NewRequest("POST", hs.URL+endpoint, bytes.NewReader(b))
		if err != nil {
			t.Fatal(err)
		}
		req.Header.Set("Content-Type", "application/json")
		req.Header.Set(api.VersionHeader, "v1")
		req.Header.Set(api.IdempotencyKeyHeader, key)
		req.Header.Set("Authorization", "Bearer "+pair.AccessToken)
		response, err := http.DefaultClient.Do(req)
		if err != nil {
			t.Fatal(err)
		}
		defer response.Body.Close()
		body, err := io.ReadAll(response.Body)
		if err != nil {
			t.Fatal(err)
		}
		if response.StatusCode != 200 {
			t.Fatalf("%s status%d: %s", endpoint, response.StatusCode, body)
		}
		return body
	}
	body := call("/v1/sessions", "start-certified", map[string]any{"case_id": r.StartState.CaseID, "card_ids": r.StartState.Loadout.CardIds})
	var permit struct {
		receipts.Authorization
		RewardStatus string `json:"reward_status"`
	}
	if err = json.Unmarshal(body, &permit); err != nil {
		t.Fatal(err)
	}
	if permit.CertificateID != proofID || permit.RewardStatus != "conditional_certified" || permit.StartState.RootSeed != 1729 || permit.StartState.Loadout.SlotCap != 5 {
		t.Fatalf("wrong HTTP certificate permit: %s", body)
	}
	r.ID = permit.ID
	r.PatientID = permit.PatientID
	r.StartState = permit.StartState
	canonical, err := canonicaljson.Marshal(r)
	if err != nil {
		t.Fatal(err)
	}
	env := schemas.SignedEnvelope{CanonicalReceiptBytes: canonical, Signature: ed25519.Sign(priv, canonical), SuiteID: "ed25519-v1", SigningKeyID: keyID}
	body = call("/v1/receipts", r.IdempotencyKey, env)
	var verdict receipts.Verdict
	if err = json.Unmarshal(body, &verdict); err != nil {
		t.Fatal(err)
	}
	if verdict.RewardStatus != "certified" || verdict.XP != cfg.CureRewards.XP {
		t.Fatalf("HTTP did not return certified payout: %s", body)
	}
	// Advance unrelated profile state after acceptance; retry feedback must keep
	// the original version, not whichever snapshot happens to be current now.
	prof, err = repo.Get(ctx, "certified-account")
	if err != nil {
		t.Fatal(err)
	}
	prof.Reputation++
	if err = repo.Update(ctx, prof); err != nil {
		t.Fatal(err)
	}
	body = call("/v1/receipts", r.IdempotencyKey, env)
	var replay receipts.Verdict
	if err = json.Unmarshal(body, &replay); err != nil || replay != verdict {
		t.Fatalf("single retry verdict drifted: %s %v", body, err)
	}
	body = call("/v1/receipts/batch", "batch-replay", map[string]any{"envelopes": []schemas.SignedEnvelope{env}})
	var batch struct {
		Results []receipts.Verdict `json:"results"`
	}
	if err = json.Unmarshal(body, &batch); err != nil || len(batch.Results) != 1 || batch.Results[0] != verdict {
		t.Fatalf("batch retry verdict drifted: %s %v", body, err)
	}
	body = call("/v1/sessions", "start-certified", map[string]any{"case_id": r.StartState.CaseID, "card_ids": r.StartState.Loadout.CardIds})
	var startReplay receipts.Authorization
	if err = json.Unmarshal(body, &startReplay); err != nil || startReplay.ID != permit.ID || startReplay.CertificateID != permit.CertificateID {
		t.Fatalf("consumed session request no longer replays: %s %v", body, err)
	}
}

func TestPostgresCertificationWithholdsUnprovenOrIneligibleRewards(t *testing.T) {
	for _, scenario := range []string{"changed_action", "changed_delta", "withdrawn_catalog", "revoked_proof", "window_budget", "economy_disabled"} {
		t.Run(scenario, func(t *testing.T) {
			st := postgresStore(t)
			c, id, r := trustedFixture(t)
			policy := config.Default().CureRewards
			if scenario == "window_budget" {
				policy.XPPerWindow = 0
			}
			s := certifiedService(t, st, c, audit.NewAppender(st.DB()), policy)
			env, ctx := certifiedSubmission(t, st, c, id, r, s)
			if scenario == "withdrawn_catalog" {
				if err := s.ConfigureCertifiedOutcomes(nil, policy, true); err != nil {
					t.Fatal(err)
				}
			}
			if scenario == "economy_disabled" {
				if err := s.ConfigureCertifiedOutcomes(c, policy, false); err != nil {
					t.Fatal(err)
				}
			}
			if scenario == "revoked_proof" {
				body, err := os.ReadFile("../../../test_fixtures/outcomes/trusted_catalog_v1.json")
				if err != nil {
					t.Fatal(err)
				}
				hash := sha256.Sum256(body)
				revoked, err := outcomes.Load(bytes.NewReader(body), hex.EncodeToString(hash[:]), []string{id})
				if err != nil {
					t.Fatal(err)
				}
				if err = s.ConfigureCertifiedOutcomes(revoked, policy, true); err != nil {
					t.Fatal(err)
				}
			}
			var receipt schemas.SessionReceipt
			if err := json.Unmarshal(env.CanonicalReceiptBytes, &receipt); err != nil {
				t.Fatal(err)
			}
			if scenario == "changed_action" || scenario == "changed_delta" {
				if scenario == "changed_action" {
					receipt.Actions[0] = schemas.Reflect
				} else {
					receipt.Deltas[0].DeltaMillis++
				}
				pub, priv, err := ed25519.GenerateKey(nil)
				if err != nil {
					t.Fatal(err)
				}
				key, err := devicekeys.NewService(devicekeys.NewSQLRepository(st.DB())).Register(ctxutil.WithIdempotencyKey(ctx, "altered-device"), "certified-account", pub, "ed25519-v1")
				if err != nil {
					t.Fatal(err)
				}
				body, err := canonicaljson.Marshal(receipt)
				if err != nil {
					t.Fatal(err)
				}
				env = schemas.SignedEnvelope{CanonicalReceiptBytes: body, Signature: ed25519.Sign(priv, body), SuiteID: "ed25519-v1", SigningKeyID: key}
			}
			if _, err := s.Submit(ctx, "certified-account", env); err != nil {
				t.Fatal(err)
			}
			verdict, err := s.AcceptanceVerdict(ctx, "certified-account", receipt.ID)
			if err != nil {
				t.Fatal(err)
			}
			expected := "held_unproven"
			if scenario == "window_budget" || scenario == "economy_disabled" {
				expected = "certified_unrewarded"
			}
			if verdict.RewardStatus != expected || verdict.XP != 0 || verdict.StudyPoints != 0 || verdict.CashMicros != 0 {
				t.Fatalf("unexpected ineligible reward: %#v", verdict)
			}
			prof, err := profile.NewSQLRepository(st.DB()).Get(ctx, "certified-account")
			if err != nil {
				t.Fatal(err)
			}
			if prof.XP != 5 || prof.StudyPoints != 0 || countRows(t, st.DB(), "ledger_events") != 0 {
				t.Fatal("unproven/ineligible receipt paid")
			}
		})
	}
}
