// psy-maintenance is an explicit local operator command, never a background job
// or HTTP endpoint. All operations default to dry-run and never migrate schema.
package main

import (
	"context"
	"database/sql"
	"encoding/json"
	"errors"
	"flag"
	"fmt"
	"io"
	"net"
	"net/url"
	"os"
	"time"

	_ "github.com/lib/pq"
	"psychosims.dev/server/internal/audit"
	"psychosims.dev/server/internal/maintenance"
	"psychosims.dev/server/internal/privacy"
	"psychosims.dev/server/internal/schemas"
)

func main() { os.Exit(run(os.Args[1:], os.Getenv, os.Stdout, os.Stderr)) }

func localDSN(dsn string) bool {
	u, err := url.Parse(dsn)
	if err != nil || (u.Scheme != "postgres" && u.Scheme != "postgresql") || u.Path == "" {
		return false
	}
	host := u.Hostname()
	ip := net.ParseIP(host)
	if host != "localhost" && (ip == nil || !ip.IsLoopback()) {
		return false
	}
	for _, key := range []string{"host", "hostaddr", "service", "servicefile", "passfile"} {
		if u.Query().Has(key) {
			return false
		}
	}
	return true
}
func run(args []string, env func(string) string, out, diagnostic io.Writer) int {
	fail := func(kind string) int { fmt.Fprintln(diagnostic, "maintenance failed:", kind); return 1 }
	if len(args) == 0 {
		return fail("command_required")
	}
	action := args[0]
	if action != "gc" && action != "erase-account" && action != "reapply-erasures" {
		return fail("unknown_command")
	}
	f := flag.NewFlagSet("psy-maintenance", flag.ContinueOnError)
	f.SetOutput(io.Discard)
	apply := f.Bool("apply", false, "execute explicitly; default is dry-run")
	account := f.String("account", "", "pseudonymous account identifier")
	journal := f.String("journal-dir", "", "private erasure journal outside database backups")
	limit := f.Int("limit", 1000, "maximum journal records per invocation")
	timeout := f.Duration("timeout", 30*time.Second, "whole command deadline")
	policy := maintenance.DefaultPolicy()
	f.IntVar(&policy.BatchSize, "batch-size", policy.BatchSize, "GC rows per data class")
	f.DurationVar(&policy.RetryGrace, "retry-grace", policy.RetryGrace, "grace after actual protocol expiry")
	f.DurationVar(&policy.ReceiptRetention, "receipt-retention", policy.ReceiptRetention, "accepted structured projection retention")
	if err := f.Parse(args[1:]); err != nil || f.NArg() != 0 {
		return fail("invalid_arguments")
	}
	if err := policy.Validate(); err != nil {
		return fail("invalid_retention_policy")
	}
	if *limit < 1 || *limit > 1000 {
		return fail("invalid_journal_limit")
	}
	if action == "erase-account" && (!schemas.ValidIdentifier(*account) || (*apply && *journal == "")) {
		return fail("account_and_apply_journal_required")
	}
	if action == "reapply-erasures" && *journal == "" {
		return fail("journal_required")
	}
	ctx, cancel, err := privacy.Deadline(context.Background(), *timeout)
	if err != nil {
		return fail("invalid_timeout")
	}
	defer cancel()
	dsn := env("PSY_MAINTENANCE_DATABASE_DSN")
	if !localDSN(dsn) {
		return fail("explicit_loopback_database_required")
	}
	db, err := sql.Open("postgres", dsn)
	if err != nil {
		return fail("database_unavailable")
	}
	defer db.Close()
	db.SetMaxOpenConns(2)
	db.SetMaxIdleConns(1)
	if err = db.PingContext(ctx); err != nil {
		return fail("database_unavailable")
	}
	var version int
	if err = db.QueryRowContext(ctx, `SELECT COALESCE(MAX(version),0) FROM schema_migrations`).Scan(&version); err != nil || version < 8 {
		return fail("maintenance_schema_required")
	}
	auditor := audit.NewAppender(db)
	eraser := privacy.NewService(db, auditor)
	var report any
	switch action {
	case "gc":
		report, err = maintenance.NewService(db, auditor).Collect(ctx, policy, *apply)
	case "erase-account":
		report, err = eraser.Erase(ctx, *account, false)
		if err == nil && *apply {
			var intent privacy.Intent
			intent, err = privacy.WriteIntent(*journal, *account)
			if err == nil {
				report, err = eraser.ApplyIntent(ctx, intent, true)
			}
		}
	case "reapply-erasures":
		var intents []privacy.Intent
		intents, err = privacy.ReadIntents(*journal, *limit)
		completed := 0
		if err == nil {
			for _, intent := range intents {
				if _, err = eraser.ApplyIntent(ctx, intent, *apply); err != nil {
					break
				}
				completed++
			}
		}
		report = struct {
			Applied   bool `json:"applied"`
			Completed int  `json:"completed"`
			Total     int  `json:"total"`
			Complete  bool `json:"complete"`
		}{*apply && completed > 0, completed, len(intents), err == nil}
	}
	if report != nil {
		if encodeErr := json.NewEncoder(out).Encode(report); encodeErr != nil {
			return fail("report_write_failed")
		}
	}
	if err != nil {
		if errors.Is(err, privacy.ErrLegalHold) {
			return fail("legal_hold")
		}
		if errors.Is(err, privacy.ErrAccountNotFound) {
			return fail("account_not_found")
		}
		return fail("operation_failed")
	}
	return 0
}
