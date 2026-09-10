//go:build postgres && load

package integration

import (
	"bufio"
	"bytes"
	"compress/gzip"
	"context"
	"crypto/ed25519"
	"crypto/rand"
	"encoding/hex"
	"encoding/json"
	"fmt"
	"io"
	"net/http"
	"net/http/httptest"
	"os"
	"os/exec"
	"path/filepath"
	"runtime"
	"sort"
	"sync"
	"testing"
	"time"

	"psychosims.dev/server/internal/api"
	"psychosims.dev/server/internal/audit"
	"psychosims.dev/server/internal/canonicaljson"
	"psychosims.dev/server/internal/config"
	"psychosims.dev/server/internal/devicekeys"
	"psychosims.dev/server/internal/identity"
	"psychosims.dev/server/internal/observability"
	"psychosims.dev/server/internal/ownership"
	"psychosims.dev/server/internal/profile"
	"psychosims.dev/server/internal/receipts"
	"psychosims.dev/server/internal/schemas"
	"psychosims.dev/server/internal/server"
	"psychosims.dev/server/internal/tokens"
)

// Thresholds were declared before measurement in the dated local-load report.
const bootReplayP95 = 500 * time.Millisecond
const freshReceiptP95 = time.Second
const localWorkers = 8

func workload(t *testing.T, name string, samples int, threshold time.Duration, operation func(int) error) {
	t.Helper()
	jobs := make(chan int)
	latencies := make(chan time.Duration, samples)
	var workers sync.WaitGroup
	batchStart := time.Now()
	for i := 0; i < localWorkers; i++ {
		workers.Add(1)
		go func() {
			defer workers.Done()
			for job := range jobs {
				started := time.Now()
				if err := operation(job); err != nil {
					t.Errorf("%s request %d: %v", name, job, err)
				}
				latencies <- time.Since(started)
			}
		}()
	}
	for i := 0; i < samples; i++ {
		jobs <- i
	}
	close(jobs)
	workers.Wait()
	close(latencies)
	values := make([]time.Duration, 0, samples)
	for d := range latencies {
		values = append(values, d)
	}
	sort.Slice(values, func(i, j int) bool { return values[i] < values[j] })
	p95 := values[(samples*95+99)/100-1]
	t.Logf("LOCAL_LOAD workload=%s samples=%d workers=%d p50_ms=%.3f p95_ms=%.3f max_ms=%.3f batch_ms=%.3f threshold_p95_ms=%.0f", name, samples, localWorkers, float64(values[len(values)/2])/float64(time.Millisecond), float64(p95)/float64(time.Millisecond), float64(values[len(values)-1])/float64(time.Millisecond), float64(time.Since(batchStart))/float64(time.Millisecond), float64(threshold)/float64(time.Millisecond))
	if p95 > threshold {
		t.Errorf("%s p95 %s exceeds declared %s", name, p95, threshold)
	}
}

func TestPostgresLocalHTTPWorkloads(t *testing.T) {
	t.Setenv("PSY_LOG_LEVEL", "error")
	st := postgresStore(t)
	st.DB().SetMaxOpenConns(10)
	const account = "local-load-account"
	sqlAccount(t, st.DB(), account)
	cfg := config.Default()
	cfg.HTTPMaxInFlight = 64
	cfg.RateLimitPreAuthPerIP = 10000
	cfg.RateLimitAuthPerAccount = 10000
	secret := []byte("local-only-load-gate-secret-32-bytes")
	manager := tokens.NewSQLManager(st.DB(), secret, time.Minute, time.Hour)
	pair, err := manager.IssuePair(context.Background(), account, "load-login")
	if err != nil {
		t.Fatal(err)
	}
	keyService := devicekeys.NewService(devicekeys.NewSQLRepository(st.DB()))
	pub, priv, err := ed25519.GenerateKey(rand.Reader)
	if err != nil {
		t.Fatal(err)
	}
	keyID, err := keyService.Register(context.Background(), account, pub, "ed25519-v1")
	if err != nil {
		t.Fatal(err)
	}
	cases := make([]server.CatalogCase, 64)
	for i := range cases {
		cases[i] = server.CatalogCase{ID: fmt.Sprintf("load-case-%02d", i), RulesetVersion: "0.1.0", MemoryClass: ownership.MemoryClassPersistent, InitialAxes: map[string]int{"trust": 20}, Controllers: schemas.TherapyControllerSettings{Focus: schemas.FocusBalanced, EmotionalDelivery: schemas.DeliveryBalanced}}
	}
	catalog, err := server.NewCatalog(cases)
	if err != nil {
		t.Fatal(err)
	}
	metrics := observability.NewMetrics()
	srv := server.NewOnline(cfg, st.DB(), identity.NewService(identity.NewSQLRepository(st.DB())), manager, catalog, secret, server.WithMetrics(metrics))
	httpServer := httptest.NewServer(srv.Handler())
	defer httpServer.Close()
	client := &http.Client{Timeout: 5 * time.Second}
	defer client.CloseIdleConnections()
	call := func(method, path, key string, body []byte) ([]byte, error) {
		req, err := http.NewRequest(method, httpServer.URL+path, bytes.NewReader(body))
		if err != nil {
			return nil, err
		}
		req.Header.Set("Content-Type", "application/json")
		req.Header.Set(api.VersionHeader, "v1")
		req.Header.Set(api.CorrelationIDHeader, "local-load")
		req.Header.Set("Authorization", "Bearer "+pair.AccessToken)
		if key != "" {
			req.Header.Set(api.IdempotencyKeyHeader, key)
		}
		resp, err := client.Do(req)
		if err != nil {
			return nil, err
		}
		defer resp.Body.Close()
		out, err := io.ReadAll(resp.Body)
		if err != nil {
			return nil, err
		}
		if resp.StatusCode != 200 {
			return nil, fmt.Errorf("unexpected HTTP status %d", resp.StatusCode)
		}
		return out, nil
	}
	envelopes := make([][]byte, len(cases))
	keys := make([]string, len(cases))
	for i, item := range cases {
		body, err := json.Marshal(map[string]any{"case_id": item.ID, "card_ids": []string{"open_question"}})
		if err != nil {
			t.Fatal(err)
		}
		response, err := call("POST", "/v1/sessions", fmt.Sprintf("load-start-%d", i), body)
		if err != nil {
			t.Fatal(err)
		}
		var permit receipts.Authorization
		if err := json.Unmarshal(response, &permit); err != nil {
			t.Fatal(err)
		}
		keys[i] = "load-receipt-" + permit.ID
		receipt := schemas.SessionReceipt{ID: permit.ID, SchemaVersion: schemas.CurrentReceiptSchemaVersion, RulesetVersion: permit.RulesetVersion, PatientID: permit.PatientID, IdempotencyKey: keys[i], CorrelationID: "local-load", TurnCount: 1, StartState: permit.StartState, Actions: []schemas.InteractionPattern{schemas.OpenQuestion}, Deltas: []schemas.StructuredDelta{}, LedgerEvents: []schemas.LedgerEvent{}}
		wire, err := canonicaljson.Marshal(receipt)
		if err != nil {
			t.Fatal(err)
		}
		envelopes[i], err = json.Marshal(schemas.SignedEnvelope{CanonicalReceiptBytes: wire, Signature: ed25519.Sign(priv, wire), SuiteID: "ed25519-v1", SigningKeyID: keyID})
		if err != nil {
			t.Fatal(err)
		}
	}
	load, err := os.ReadFile("/proc/loadavg")
	if err != nil {
		t.Fatal(err)
	}
	t.Logf("LOCAL_HOST os=%s arch=%s go=%s cpus=%d gomaxprocs=%d loadavg=%s", runtime.GOOS, runtime.GOARCH, runtime.Version(), runtime.NumCPU(), runtime.GOMAXPROCS(0), bytes.TrimSpace(load))
	baseline := metrics.Counter("http_requests_total")
	workload(t, "boot", 200, bootReplayP95, func(int) error { _, err := call("GET", "/v1/boot", "", nil); return err })
	workload(t, "fresh_accept", 64, freshReceiptP95, func(i int) error {
		out, err := call("POST", "/v1/receipts", keys[i], envelopes[i])
		if err != nil {
			return err
		}
		var verdict struct {
			Status string `json:"status"`
			Reward string `json:"reward_status"`
		}
		if err = json.Unmarshal(out, &verdict); err != nil {
			return err
		}
		if verdict.Status != "accepted" || verdict.Reward != "held_unproven" {
			return fmt.Errorf("fresh receipt verdict mismatch")
		}
		return nil
	})
	workload(t, "receipt_replay", 200, bootReplayP95, func(int) error { _, err := call("POST", "/v1/receipts", keys[0], envelopes[0]); return err })
	var accepted int
	if err = st.DB().QueryRow(`SELECT count(*) FROM session_authorizations WHERE consumed_at IS NOT NULL`).Scan(&accepted); err != nil {
		t.Fatal(err)
	}
	if accepted != 64 {
		t.Fatalf("fresh durable acceptance count=%d", accepted)
	}
	chain, err := audit.NewAppender(st.DB()).ValidateChain(context.Background())
	if err != nil {
		t.Fatal(err)
	}
	if len(chain) != 64 {
		t.Fatalf("audit accept rows=%d; replay mutated state", len(chain))
	}
	prof, err := profile.NewSQLRepository(st.DB()).Get(context.Background(), account)
	if err != nil {
		t.Fatal(err)
	}
	if prof.Version != 65 || prof.XP != 5 || countRows(t, st.DB(), "ledger_events") != 0 {
		t.Fatal("unexpected profile version or unproven payout")
	}
	if metrics.Counter("http_requests_total")-baseline != 464 || metrics.Dropped() != 0 || metrics.Counter("http_4xx_total") != 0 || metrics.Counter("http_5xx_total") != 0 {
		t.Fatal("HTTP observations lost or unexpected response recorded")
	}
	summary := metrics.TimerSnapshot("http_request_duration")
	var bucketCount uint64
	for _, n := range summary.Buckets {
		bucketCount += n
	}
	if bucketCount != summary.Count || int64(summary.Count) != metrics.Counter("http_requests_total") {
		t.Fatal("bounded aggregate lost observations")
	}
	stats := st.DB().Stats()
	t.Logf("LOCAL_STATE accepted=%d audit=%d profile_version=%d xp=%d http_observations=%d histogram_buckets=%d sql_max_open=%d sql_wait_count=%d sql_wait_ms=%.3f", accepted, len(chain), prof.Version, prof.XP, summary.Count, len(summary.Buckets), stats.MaxOpenConnections, stats.WaitCount, float64(stats.WaitDuration)/float64(time.Millisecond))
}

func TestPostgresLocalSaturationRecovery(t *testing.T) {
	t.Setenv("PSY_LOG_LEVEL", "error")
	st := postgresStore(t)
	sqlAccount(t, st.DB(), "saturation")
	cfg := config.Default()
	cfg.HTTPMaxInFlight = 1
	secret := []byte("local-only-load-gate-secret-32-bytes")
	manager := tokens.NewSQLManager(st.DB(), secret, time.Minute, time.Hour)
	pair, err := manager.IssuePair(context.Background(), "saturation", "login")
	if err != nil {
		t.Fatal(err)
	}
	catalog, err := server.NewCatalog(nil)
	if err != nil {
		t.Fatal(err)
	}
	srv := server.NewOnline(cfg, st.DB(), identity.NewService(identity.NewSQLRepository(st.DB())), manager, catalog, secret)
	httpServer := httptest.NewServer(srv.Handler())
	defer httpServer.Close()
	client := &http.Client{Timeout: 2 * time.Second}
	defer client.CloseIdleConnections()
	request := func(ctx context.Context, path string) (*http.Response, error) {
		r, err := http.NewRequestWithContext(ctx, "GET", httpServer.URL+path, nil)
		if err != nil {
			return nil, err
		}
		r.Header.Set("Authorization", "Bearer "+pair.AccessToken)
		return client.Do(r)
	}
	st.DB().SetMaxOpenConns(1)
	conn, err := st.DB().Conn(context.Background())
	if err != nil {
		t.Fatal(err)
	}
	var once sync.Once
	release := func() { once.Do(func() { conn.Close() }) }
	defer release()
	ctx, cancel := context.WithCancel(context.Background())
	defer cancel()
	done := make(chan struct{})
	go func() {
		defer close(done)
		resp, _ := request(ctx, "/v1/boot")
		if resp != nil {
			resp.Body.Close()
		}
	}()
	defer func() { cancel(); release(); <-done }()
	until := time.Now().Add(time.Second)
	for st.DB().Stats().WaitCount == 0 && time.Now().Before(until) {
		time.Sleep(time.Millisecond)
	}
	if st.DB().Stats().WaitCount == 0 {
		t.Fatal("fixture request never reached saturated SQL pool")
	}
	started := time.Now()
	resp, err := request(context.Background(), "/v1/boot")
	duration := time.Since(started)
	if err != nil {
		t.Fatal(err)
	}
	resp.Body.Close()
	if resp.StatusCode != 503 || resp.Header.Get("Retry-After") == "" || duration > 250*time.Millisecond {
		t.Fatalf("saturation did not fail fast: status=%d elapsed=%s", resp.StatusCode, duration)
	}
	health, err := request(context.Background(), "/health")
	if err != nil {
		t.Fatal(err)
	}
	health.Body.Close()
	if health.StatusCode != 200 {
		t.Fatal("liveness unavailable during SQL saturation")
	}
	cancel()
	<-done
	// Keep SQL unavailable while proving cancellation releases admission. A
	// database-free, admission-controlled route cannot be rescued by releasing
	// the held connection if the cancelled SQL lookup ignores its context.
	until = time.Now().Add(time.Second)
	recovered := false
	for time.Now().Before(until) {
		out, err := request(context.Background(), "/time")
		if err != nil {
			t.Fatal(err)
		}
		out.Body.Close()
		if out.StatusCode == 200 {
			recovered = true
			break
		}
		if out.StatusCode != 503 {
			t.Fatalf("unexpected recovery status %d", out.StatusCode)
		}
		time.Sleep(time.Millisecond)
	}
	if !recovered {
		t.Fatal("cancelled request retained admission")
	}
	release()
	boot, err := request(context.Background(), "/v1/boot")
	if err != nil {
		t.Fatal(err)
	}
	boot.Body.Close()
	if boot.StatusCode != http.StatusOK {
		t.Fatalf("boot did not recover after releasing SQL: %d", boot.StatusCode)
	}
	t.Logf("LOCAL_SATURATION max_in_flight=1 excess_status=503 reject_ms=%.3f liveness=200 cancellation_releases_before_sql=true recovered=true", float64(duration)/float64(time.Millisecond))
}

func TestPostgresLocalColdStart(t *testing.T) {
	t.Setenv("PSY_LOG_LEVEL", "info")
	st := postgresStore(t)
	if err := st.Ping(context.Background()); err != nil {
		t.Fatal(err)
	}
	dir := t.TempDir()
	binary := filepath.Join(dir, "psy-server")
	serverDir, err := filepath.Abs("../..")
	if err != nil {
		t.Fatal(err)
	}
	build := exec.Command("go", "build", "-o", binary, "./cmd/psy-server")
	build.Dir = serverDir
	if output, err := build.CombinedOutput(); err != nil {
		t.Fatalf("build executable: %v\n%s", err, output)
	}
	artifact, err := os.Open(binary)
	if err != nil {
		t.Fatal(err)
	}
	var compressed bytes.Buffer
	compressor := gzip.NewWriter(&compressed)
	if _, err = io.Copy(compressor, artifact); err != nil {
		t.Fatal(err)
	}
	artifact.Close()
	if err = compressor.Close(); err != nil {
		t.Fatal(err)
	}
	if compressed.Len() > 50<<20 {
		t.Fatal("compressed executable exceeds declared 50 MiB")
	}
	t.Logf("LOCAL_BINARY gzip_bytes=%d", compressed.Len())
	secret := make([]byte, 32)
	if _, err = rand.Read(secret); err != nil {
		t.Fatal(err)
	}
	secretPath := filepath.Join(dir, "token-secret")
	if err = os.WriteFile(secretPath, []byte(hex.EncodeToString(secret)), 0600); err != nil {
		t.Fatal(err)
	}
	for i := 0; i < 3; i++ {
		t.Run(fmt.Sprintf("launch_%d", i+1), func(t *testing.T) {
			cmd := exec.Command(binary)
			cmd.Dir = serverDir
			cmd.Env = append(os.Environ(), "PSY_TOKEN_SECRET_FILE="+secretPath, "PSY_GOOGLE_CLIENT_ID=local-cold-start-fixture", "PSY_APPLE_CLIENT_ID=", "PSY_DATABASE_DSN="+os.Getenv("PSY_TEST_DATABASE_DSN"), "PSY_LISTEN_ADDR=127.0.0.1:0", "PSY_LOG_MODE=json")
			stderr, err := cmd.StderrPipe()
			if err != nil {
				t.Fatal(err)
			}
			started := time.Now()
			if err = cmd.Start(); err != nil {
				t.Fatal(err)
			}
			done := make(chan error, 1)
			go func() { done <- cmd.Wait() }()
			stopped := false
			defer func() {
				if !stopped {
					cmd.Process.Kill()
					<-done
				}
			}()
			address := make(chan string, 1)
			go func() {
				scanner := bufio.NewScanner(stderr)
				for scanner.Scan() {
					var entry struct {
						Event string `json:"event"`
						KV    struct {
							Addr string `json:"addr"`
						} `json:"kv"`
					}
					if json.Unmarshal(scanner.Bytes(), &entry) == nil && entry.Event == "listen" {
						address <- entry.KV.Addr
					}
				}
			}()
			var addr string
			select {
			case addr = <-address:
			case err := <-done:
				stopped = true
				t.Fatalf("early executable exit: %v", err)
			case <-time.After(2 * time.Second):
				t.Fatal("cold start exceeded declared 2 seconds")
			}
			client := &http.Client{Timeout: 2 * time.Second}
			defer client.CloseIdleConnections()
			resp, err := client.Get("http://" + addr + "/ready")
			if err != nil {
				t.Fatal(err)
			}
			resp.Body.Close()
			elapsed := time.Since(started)
			if resp.StatusCode != 200 || elapsed > 2*time.Second {
				t.Fatalf("cold readiness status=%d elapsed=%s", resp.StatusCode, elapsed)
			}
			if err = cmd.Process.Signal(os.Interrupt); err != nil {
				t.Fatal(err)
			}
			select {
			case err = <-done:
				stopped = true
				if err != nil {
					t.Fatal(err)
				}
			case <-time.After(5 * time.Second):
				t.Fatal("shutdown deadline exceeded")
			}
			t.Logf("LOCAL_COLD_START sample=%d ready_ms=%.3f", i+1, float64(elapsed)/float64(time.Millisecond))
		})
	}
}
