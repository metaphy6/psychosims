// Command psy-server runs the Psychosims authoritative control plane.
package main

import (
	"net/http"

	"psychosims.dev/server/internal/psylog"
	"psychosims.dev/server/internal/server"
)

const addr = "0.0.0.0:8080"

func main() {
	log := psylog.Default()
	srv := &http.Server{Addr: addr, Handler: server.NewMux()}
	log.Info("server", "listen", psylog.KV{"addr": addr, "version": server.Version})
	if err := srv.ListenAndServe(); err != nil {
		log.Fatal("server", "listen_failed", psylog.KV{"error": err.Error()})
	}
}
