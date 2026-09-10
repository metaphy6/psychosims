//go:build postgres

package integration

import (
	"bufio"
	"context"
	"crypto/rand"
	"encoding/hex"
	"encoding/json"
	"net/http"
	"os"
	"os/exec"
	"path/filepath"
	"testing"
	"time"
)

func TestPostgresExecutableStartsRealStoreAndStops(t *testing.T) {
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
		t.Fatalf("build actual executable: %v\n%s", err, output)
	}
	secret := make([]byte, 32)
	if _, err := rand.Read(secret); err != nil {
		t.Fatal(err)
	}
	secretPath := filepath.Join(dir, "token-secret")
	if err := os.WriteFile(secretPath, []byte(hex.EncodeToString(secret)), 0600); err != nil {
		t.Fatal(err)
	}
	cmd := exec.Command(binary)
	cmd.Dir = serverDir
	cmd.Env = append(os.Environ(), "PSY_TOKEN_SECRET_FILE="+secretPath, "PSY_GOOGLE_CLIENT_ID=local-binary-fixture", "PSY_APPLE_CLIENT_ID=", "PSY_DATABASE_DSN="+os.Getenv("PSY_TEST_DATABASE_DSN"), "PSY_LISTEN_ADDR=127.0.0.1:0", "PSY_LOG_MODE=json")
	stderr, err := cmd.StderrPipe()
	if err != nil {
		t.Fatal(err)
	}
	if err := cmd.Start(); err != nil {
		t.Fatal(err)
	}
	done := make(chan error, 1)
	go func() { done <- cmd.Wait() }()
	address := make(chan string, 1)
	go func() {
		scanner := bufio.NewScanner(stderr)
		for scanner.Scan() {
			var line struct {
				Event string `json:"event"`
				KV    struct {
					Addr string `json:"addr"`
				} `json:"kv"`
			}
			if json.Unmarshal(scanner.Bytes(), &line) == nil && line.Event == "listen" {
				address <- line.KV.Addr
				return
			}
		}
	}()
	stopped := false
	t.Cleanup(func() {
		if !stopped {
			cmd.Process.Kill()
			<-done
		}
	})
	var addr string
	select {
	case addr = <-address:
	case err := <-done:
		stopped = true
		t.Fatalf("executable exited before readiness: %v", err)
	case <-time.After(10 * time.Second):
		t.Fatal("executable did not listen")
	}
	client := &http.Client{Timeout: time.Second}
	for _, path := range []string{"/health", "/ready", "/time"} {
		resp, err := client.Get("http://" + addr + path)
		if err != nil {
			t.Fatal(err)
		}
		resp.Body.Close()
		if resp.StatusCode != 200 {
			t.Fatalf("actual executable %s: %d", path, resp.StatusCode)
		}
	}
	if err := cmd.Process.Signal(os.Interrupt); err != nil {
		t.Fatal(err)
	}
	select {
	case err := <-done:
		stopped = true
		if err != nil {
			t.Fatalf("graceful shutdown: %v", err)
		}
	case <-time.After(5 * time.Second):
		t.Fatal("executable did not shut down")
	}
}
