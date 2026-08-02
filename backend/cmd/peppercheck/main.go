// Command peppercheck is the single backend binary. It dispatches to the api or
// worker command; both share one image and set of application services.
package main

import (
	"context"
	"fmt"
	"net/http"
	"os"
	"os/signal"
	"syscall"
	"time"

	"github.com/cloveclovedev/peppercheck/backend/internal/api"
	"github.com/cloveclovedev/peppercheck/backend/internal/core/config"
	"github.com/cloveclovedev/peppercheck/backend/internal/core/database"
	"github.com/cloveclovedev/peppercheck/backend/internal/core/logging"
	"github.com/cloveclovedev/peppercheck/backend/internal/identity"
	"github.com/cloveclovedev/peppercheck/backend/internal/platform/auth"
	"github.com/cloveclovedev/peppercheck/backend/internal/worker"
)

func main() {
	if len(os.Args) < 2 {
		fmt.Fprintln(os.Stderr, "usage: peppercheck <api|worker|healthcheck>")
		os.Exit(2)
	}
	cfg, err := config.Load()
	if err != nil {
		fmt.Fprintln(os.Stderr, "config:", err)
		os.Exit(1)
	}

	if os.Args[1] == "healthcheck" {
		os.Exit(runHealthcheck(cfg))
	}

	logger := logging.New(cfg.LogLevel)
	ctx, stop := signal.NotifyContext(context.Background(), syscall.SIGINT, syscall.SIGTERM)
	defer stop()

	switch os.Args[1] {
	case "api":
		db, err := database.Connect(ctx, cfg.DatabaseURL)
		if err != nil {
			logger.Error("database connect failed", "error", err)
			os.Exit(1)
		}
		defer db.Close()

		verifier, err := auth.NewFirebaseVerifier(ctx, cfg.FirebaseProjectID)
		if err != nil {
			logger.Error("firebase verifier init failed", "error", err)
			os.Exit(1)
		}
		idSvc := identity.NewService(identity.NewStore(db), nil)
		idHandler := identity.NewHandler(idSvc, logger)

		if err := api.Run(ctx, cfg, logger, api.Deps{
			Ready:       db.PingContext,
			Verifier:    verifier,
			Identity:    idHandler,
			ResolveUser: identity.NewMiddleware(idSvc, logger),
		}); err != nil {
			logger.Error("api exited with error", "error", err)
			os.Exit(1)
		}
	case "worker":
		db, err := database.Connect(ctx, cfg.DatabaseURL)
		if err != nil {
			logger.Error("database connect failed", "error", err)
			os.Exit(1)
		}
		defer db.Close()
		if err := worker.Run(ctx, cfg, logger, db); err != nil {
			logger.Error("worker exited with error", "error", err)
			os.Exit(1)
		}
	default:
		fmt.Fprintf(os.Stderr, "unknown command: %s\n", os.Args[1])
		os.Exit(2)
	}
}

// runHealthcheck is used by the container HEALTHCHECK; it returns 0 when the
// local api answers /livez with 200.
func runHealthcheck(cfg config.Config) int {
	client := &http.Client{Timeout: 3 * time.Second}
	resp, err := client.Get(fmt.Sprintf("http://127.0.0.1:%d/livez", cfg.Port))
	if err != nil {
		return 1
	}
	defer resp.Body.Close()
	if resp.StatusCode != http.StatusOK {
		return 1
	}
	return 0
}
