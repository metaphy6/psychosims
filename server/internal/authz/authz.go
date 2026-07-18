// Package authz implements the authorization model for Phase 3.1: every request
// is scoped to an authenticated account, and an admin role exists as a separate
// privilege boundary.
package authz

import (
	"context"
	"net/http"

	"psychosims.dev/server/internal/api"
	"psychosims.dev/server/internal/ctxutil"
)

// Role is the authorization role carried on the request context.
type Role string

const (
	RolePlayer Role = "player"
	RoleAdmin  Role = "admin"
)

// Context values.
type roleKey struct{}

// WithRole attaches a role to the context.
func WithRole(ctx context.Context, role Role) context.Context {
	return context.WithValue(ctx, roleKey{}, role)
}

// RoleFrom returns the role on the context, defaulting to player.
func RoleFrom(ctx context.Context) Role {
	if r, ok := ctx.Value(roleKey{}).(Role); ok {
		return r
	}
	return RolePlayer
}

// Middleware enforces bearer-token authentication and attaches account id + role
// to the request context.
func Middleware(verify func(string) (string, Role, error)) func(http.Handler) http.Handler {
	return func(next http.Handler) http.Handler {
		return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
			token := extractBearer(r)
			if token == "" {
				api.NewUnauthorized("missing bearer token").Write(w, ctxutil.RequestID(r.Context()))
				return
			}
			accountID, role, err := verify(token)
			if err != nil {
				api.NewUnauthorized("invalid bearer token").Write(w, ctxutil.RequestID(r.Context()))
				return
			}
			ctx := ctxutil.WithAccountID(r.Context(), accountID)
			ctx = WithRole(ctx, role)
			next.ServeHTTP(w, r.WithContext(ctx))
		})
	}
}

// RequireAccount rejects requests without an account id in context.
func RequireAccount(ctx context.Context) error {
	if ctxutil.AccountID(ctx) == "" {
		return api.NewUnauthorized("account id required")
	}
	return nil
}

// RequireAdmin rejects requests whose role is not admin.
func RequireAdmin(ctx context.Context) error {
	if err := RequireAccount(ctx); err != nil {
		return err
	}
	if RoleFrom(ctx) != RoleAdmin {
		return api.NewForbidden("admin role required")
	}
	return nil
}

// Owns returns true if the account id in context matches resourceAccountID.
func Owns(ctx context.Context, resourceAccountID string) bool {
	return ctxutil.AccountID(ctx) == resourceAccountID
}

func extractBearer(r *http.Request) string {
	h := r.Header.Get("Authorization")
	const prefix = "Bearer "
	if len(h) > len(prefix) && h[:len(prefix)] == prefix {
		return h[len(prefix):]
	}
	return ""
}
