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

	_ "time/tzdata" // embed the IANA tz database so time.LoadLocation works in the container

	"github.com/cloveclovedev/peppercheck/backend/internal/api"
	"github.com/cloveclovedev/peppercheck/backend/internal/core/config"
	"github.com/cloveclovedev/peppercheck/backend/internal/core/database"
	"github.com/cloveclovedev/peppercheck/backend/internal/core/logging"
	"github.com/cloveclovedev/peppercheck/backend/internal/core/ratelimit"
	"github.com/cloveclovedev/peppercheck/backend/internal/identity"
	"github.com/cloveclovedev/peppercheck/backend/internal/notification"
	"github.com/cloveclovedev/peppercheck/backend/internal/platform/auth"
	"github.com/cloveclovedev/peppercheck/backend/internal/platform/r2"
	"github.com/cloveclovedev/peppercheck/backend/internal/profile"
	"github.com/cloveclovedev/peppercheck/backend/internal/web"
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
		profileStore := profile.NewStore(db)
		notifStore := notification.NewStore(db)

		// First-sighting provisioning fans out to profile + notification within
		// the identity transaction.
		idSvc := identity.NewService(identity.NewStore(db), api.NewProvisioner(profileStore, notifStore))
		idHandler := identity.NewHandler(idSvc, logger)

		// R2 backs avatar upload/finalize only. When it is not configured (per-env
		// credentials are operator-provisioned at deploy), the api still runs with
		// avatars failing closed at the feature (503) rather than crashing the
		// whole process — profile/notification/identity do not need R2.
		var avatarUploader r2.Uploader
		if r2Client, err := r2.New(r2.Config{
			AccountID:       cfg.R2AccountID,
			AccessKeyID:     cfg.R2AccessKeyID,
			SecretAccessKey: cfg.R2SecretAccessKey,
			Bucket:          cfg.R2Bucket,
			PublicDomain:    cfg.R2PublicDomain,
		}); err != nil {
			logger.Warn("R2 not configured; avatar upload/finalize disabled (503)", "error", err)
		} else {
			avatarUploader = r2Client
		}

		// Per-user avatar-upload rate limit: burst 10, ~10/hour, evict idle after 1h.
		avatarLimiter := ratelimit.NewTokenBucket(10, 10, time.Hour, nil)
		profileSvc := profile.NewService(profileStore, avatarUploader, cfg.R2PublicDomain, avatarLimiter, logger)
		notifSvc := notification.NewService(notifStore)

		if err := api.Run(ctx, cfg, logger, api.Deps{
			Ready:        db.PingContext,
			Verifier:     verifier,
			Identity:     idHandler,
			Profile:      profile.NewHandler(profileSvc),
			Notification: notification.NewHandler(notifSvc),
			ResolveUser:  identity.NewMiddleware(idSvc, logger),
			Web:          web.NewHandler(web.Deps{Logger: logger}),
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
