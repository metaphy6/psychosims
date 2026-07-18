// Command psy-server runs the Psychosims authoritative control plane.
package main

import (
	"context"
	"net/http"
	"os"
	"os/signal"
	"syscall"
	"time"

	"psychosims.dev/server/internal/config"
	"psychosims.dev/server/internal/psylog"
	"psychosims.dev/server/internal/server"
	"psychosims.dev/server/internal/timeutil"
)

func main() {
	log := psylog.Default()
	cfg := config.Default()
	if err := cfg.Validate(); err != nil {
		log.Fatal("server", "config_invalid", psylog.KV{"error": err.Error()})
	}

	s := server.New(timeutil.RealClock{})
	httpSrv := &http.Server{
		Addr:         cfg.ListenAddr,
		Handler:      s.Handler(),
		ReadTimeout:  5 * time.Second,
		WriteTimeout: 10 * time.Second,
		IdleTimeout:  120 * time.Second,
	}

	log.Info("server", "listen", psylog.KV{"addr": cfg.ListenAddr, "version": server.Version})

	go func() {
		if err := httpSrv.ListenAndServe(); err != nil && err != http.ErrServerClosed {
			log.Fatal("server", "listen_failed", psylog.KV{"error": err.Error()})
		}
	}()

	quit := make(chan os.Signal, 1)
	signal.Notify(quit, syscall.SIGTERM, syscall.SIGINT)
	<-quit

	log.Info("server", "shutdown", psylog.KV{"addr": cfg.ListenAddr})
	ctx, cancel := context.WithTimeout(context.Background(), 15*time.Second)
	defer cancel()
	if err := httpSrv.Shutdown(ctx); err != nil {
		log.Error("server", "shutdown_failed", psylog.KV{"error": err.Error()})
	}
}
