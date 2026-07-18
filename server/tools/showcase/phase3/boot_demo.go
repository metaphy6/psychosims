package main

import (
	"context"
	"fmt"
	"net/http"
	"net/http/httptest"

	"psychosims.dev/server/internal/authz"
	"psychosims.dev/server/internal/health"
	"psychosims.dev/server/internal/profile"
	"psychosims.dev/server/internal/server"
	"psychosims.dev/server/internal/timeutil"
)

type bootVerifier struct{}

func (bootVerifier) Verify(token string) (string, authz.Role, error) { return "player-1", authz.RolePlayer, nil }

func bootDemo(path string) error {
	r := newReport("Boot handshake")
	r.line("This demo runs `/v1/boot` for a fresh account and returns an ETag.")
	r.line("")

	repo := profile.NewInMemoryProfileRepository()
	hc := health.NewChecker(func(ctx context.Context) (string, bool) { return "db", true })
	srv := server.New(
		timeutil.RealClock{},
		server.WithProfileRepo(repo),
		server.WithAuthVerifier(bootVerifier{}),
		server.WithHealthChecker(hc),
	)

	req := httptest.NewRequest(http.MethodGet, "/v1/boot", nil)
	req.Header.Set("Authorization", "Bearer demo")
	rec := httptest.NewRecorder()
	srv.Handler().ServeHTTP(rec, req)

	r.h2("Response")
	r.code(fmt.Sprintf("status = %d\netag = %s\nbody = %s", rec.Code, rec.Header().Get("ETag"), rec.Body.String()))
	return r.write(path)
}
