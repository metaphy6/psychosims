package health

import (
	"context"
	"testing"
)

func TestChecker(t *testing.T) {
	c := NewChecker(
		func(ctx context.Context) (string, bool) { return "db", true },
		func(ctx context.Context) (string, bool) { return "cache", false },
	)

	got := c.Check(context.Background())
	if got["db"] != "ok" {
		t.Errorf("db = %q, want ok", got["db"])
	}
	if got["cache"] != "error" {
		t.Errorf("cache = %q, want error", got["cache"])
	}
}
