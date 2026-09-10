package main

import (
	"bytes"
	"strings"
	"testing"
)

func TestCommandRefusesRemoteDSNAndNeverEchoesIt(t *testing.T) {
	for _, dsn := range []string{"postgres://user:secret-sentinel@remote.example/db", "postgres://127.0.0.1/db?host=remote.example", "host=remote.example password=secret-sentinel"} {
		var out, diagnostic bytes.Buffer
		code := run([]string{"gc"}, func(string) string { return dsn }, &out, &diagnostic)
		if code == 0 || strings.Contains(out.String()+diagnostic.String(), "secret-sentinel") {
			t.Fatal("unsafe connection or error output")
		}
	}
}
func TestCommandRequiresExplicitErasureJournalAndValidArguments(t *testing.T) {
	for _, args := range [][]string{{}, {"erase-account", "--account=a", "--apply"}, {"gc", "--batch-size=0"}, {"gc", "--unknown=secret-sentinel"}, {"erase-account", "--account=raw dialogue"}, {"reapply-erasures"}} {
		var out, diagnostic bytes.Buffer
		code := run(args, func(string) string { return "postgres://127.0.0.1:1/db" }, &out, &diagnostic)
		if code == 0 || strings.Contains(out.String()+diagnostic.String(), "secret-sentinel") {
			t.Fatal("invalid arguments accepted or echoed")
		}
	}
}
