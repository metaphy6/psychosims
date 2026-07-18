package authz

import (
	"context"
	"errors"
	"net/http"
	"net/http/httptest"
	"testing"

	"psychosims.dev/server/internal/ctxutil"
)

func TestMiddlewareAuthenticates(t *testing.T) {
	verify := func(token string) (string, Role, error) {
		if token == "valid" {
			return "acc-1", RolePlayer, nil
		}
		return "", "", errors.New("bad token")
	}

	handler := Middleware(verify)(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		if ctxutil.AccountID(r.Context()) != "acc-1" {
			t.Error("expected account id")
		}
		if RoleFrom(r.Context()) != RolePlayer {
			t.Error("expected player role")
		}
		w.WriteHeader(http.StatusOK)
	}))

	req := httptest.NewRequest(http.MethodGet, "/", nil)
	req.Header.Set("Authorization", "Bearer valid")
	rec := httptest.NewRecorder()
	handler.ServeHTTP(rec, req)

	if rec.Code != http.StatusOK {
		t.Errorf("status = %d, want %d", rec.Code, http.StatusOK)
	}
}

func TestMiddlewareRejectsMissingToken(t *testing.T) {
	handler := Middleware(func(string) (string, Role, error) { return "", "", errors.New("no") })(
		http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) { w.WriteHeader(http.StatusOK) }),
	)

	req := httptest.NewRequest(http.MethodGet, "/", nil)
	rec := httptest.NewRecorder()
	handler.ServeHTTP(rec, req)

	if rec.Code != http.StatusUnauthorized {
		t.Errorf("status = %d, want %d", rec.Code, http.StatusUnauthorized)
	}
}

func TestRequireAdmin(t *testing.T) {
	ctx := context.Background()
	ctx = ctxutil.WithAccountID(ctx, "acc-1")
	ctx = WithRole(ctx, RolePlayer)
	if err := RequireAdmin(ctx); err == nil {
		t.Error("expected admin required")
	}

	ctx = WithRole(ctx, RoleAdmin)
	if err := RequireAdmin(ctx); err != nil {
		t.Errorf("unexpected error: %v", err)
	}
}

func TestOwns(t *testing.T) {
	ctx := ctxutil.WithAccountID(context.Background(), "acc-1")
	if !Owns(ctx, "acc-1") {
		t.Error("expected owns")
	}
	if Owns(ctx, "acc-2") {
		t.Error("expected not owns")
	}
}
