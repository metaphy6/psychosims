// Command phase3 is a headless Go showcase for Phase 3. It emits human-readable
// Markdown reports under docs/reports/showcase/phase3/.
package main

import (
	"fmt"
	"os"
	"path/filepath"
	"strings"
	"time"

	"psychosims.dev/server/internal/psylog"
)

const outDir = "docs/reports/showcase/phase3"

func main() {
	root, err := findRepoRoot()
	if err != nil {
		fmt.Fprintf(os.Stderr, "repo root: %v\n", err)
		os.Exit(1)
	}
	out := filepath.Join(root, outDir)
	if err := os.MkdirAll(out, 0755); err != nil {
		fmt.Fprintf(os.Stderr, "mkdir: %v\n", err)
		os.Exit(1)
	}

	demos := []struct {
		name string
		fn   func(string) error
	}{
		{"00-identity.md", identityDemo},
		{"01-boot.md", bootDemo},
		{"02-receipt.md", receiptDemo},
		{"03-offline.md", offlineDemo},
		{"04-devicekeys.md", devicekeysDemo},
		{"05-ownership.md", ownershipDemo},
	}

	for _, d := range demos {
		(&psylog.Logger{MinLevel: psylog.Info}).Info("showcase", "generate", psylog.KV{"report": d.name})
		if err := d.fn(filepath.Join(out, d.name)); err != nil {
			fmt.Fprintf(os.Stderr, "%s: %v\n", d.name, err)
			os.Exit(1)
		}
	}
}

func findRepoRoot() (string, error) {
	cwd, err := os.Getwd()
	if err != nil {
		return "", err
	}
	for dir := cwd; dir != "/"; dir = filepath.Dir(dir) {
		if fi, err := os.Stat(filepath.Join(dir, "docs")); err == nil && fi.IsDir() {
			return dir, nil
		}
	}
	return "", fmt.Errorf("could not locate repo root from %s", cwd)
}

type report struct {
	sb strings.Builder
}

func newReport(title string) *report {
	r := &report{}
	r.h1(title)
	r.line("_Generated %s by `server/scripts/showcase.sh`._", time.Now().UTC().Format(time.RFC3339))
	r.line("")
	return r
}

func (r *report) h1(s string)                { r.sb.WriteString("# " + s + "\n\n") }
func (r *report) h2(s string)                { r.sb.WriteString("## " + s + "\n\n") }
func (r *report) line(s string, args ...any) { r.sb.WriteString(fmt.Sprintf(s+"\n", args...)) }
func (r *report) code(s string) {
	r.sb.WriteString("```\n" + s + "\n```\n\n")
}

func (r *report) write(path string) error {
	return os.WriteFile(path, []byte(r.sb.String()), 0644)
}
