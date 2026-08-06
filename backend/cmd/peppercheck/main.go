// Command peppercheck is the single backend binary. It dispatches to the api or
// worker command; both share one image and set of application services.
package main

import (
	"context"
	"fmt"
	"log/slog"
	"net/http"
	"os"
	"os/signal"
	"syscall"
	"time"

	_ "time/tzdata" // embed the IANA tz database so time.LoadLocation works in the container

	"github.com/cloveclovedev/peppercheck/backend/internal/accountdeletion"
	"github.com/cloveclovedev/peppercheck/backend/internal/api"
	"github.com/cloveclovedev/peppercheck/backend/internal/core/config"
	"github.com/cloveclovedev/peppercheck/backend/internal/core/database"
	"github.com/cloveclovedev/peppercheck/backend/internal/core/jobs"
	"github.com/cloveclovedev/peppercheck/backend/internal/core/logging"
	"github.com/cloveclovedev/peppercheck/backend/internal/core/ratelimit"
	"github.com/cloveclovedev/peppercheck/backend/internal/identity"
	"github.com/cloveclovedev/peppercheck/backend/internal/judgement"
	"github.com/cloveclovedev/peppercheck/backend/internal/matching"
	"github.com/cloveclovedev/peppercheck/backend/internal/notification"
	"github.com/cloveclovedev/peppercheck/backend/internal/platform/auth"
	"github.com/cloveclovedev/peppercheck/backend/internal/platform/fcm"
	"github.com/cloveclovedev/peppercheck/backend/internal/platform/r2"
	"github.com/cloveclovedev/peppercheck/backend/internal/profile"
	"github.com/cloveclovedev/peppercheck/backend/internal/task"
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

		// Task authoring + referee matching. The api never sends FCM (that is the
		// worker's job), so its matching service takes a no-op-FCM notifier: the
		// referee/task HTTP paths only enqueue match jobs, never push. Points and
		// obligations are the Phase 5 seams (no-ops in 4a).
		matchingStore := matching.NewStore(db)
		matchingSvc := matching.NewService(
			db, matchingStore,
			matching.NewNoopPointLocker(), matching.NewNoObligations(),
			judgement.NewProvisioner(),
			notification.NewSender(notifStore, fcm.NewNoop(logger)),
			jobs.NewStore(db),
		)
		taskSvc := task.NewService(db, task.NewStore(db), matchingSvc)

		// identity.Store's FindUserByEmail satisfies accountdeletion's
		// userLookup; a separate identity.NewStore(db) here is cheap (no
		// state beyond the *sql.DB handle already shared elsewhere).
		delSvc := accountdeletion.NewService(identity.NewStore(db), accountdeletion.NewStore(db))
		deletionLimiter := ratelimit.NewTokenBucket(
			web.AccountDeletionRateLimitBurst, web.AccountDeletionRateLimitPerHour,
			web.AccountDeletionRateLimitIdleEvict, nil)

		if err := api.Run(ctx, cfg, logger, api.Deps{
			Ready:        db.PingContext,
			Verifier:     verifier,
			Identity:     idHandler,
			Profile:      profile.NewHandler(profileSvc),
			Notification: notification.NewHandler(notifSvc),
			Task:         task.NewHandler(taskSvc),
			Referee:      matching.NewHandler(matchingSvc, matchingStore),
			ResolveUser:  identity.NewMiddleware(idSvc, logger),
			Web: web.NewHandler(web.Deps{
				Logger:    logger,
				Deletion:  delSvc,
				FormToken: web.NewFormToken([]byte(cfg.WebFormSigningKey)),
				RateLim:   deletionLimiter,
			}),
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

		fcmClient, err := buildFCMClient(ctx, cfg, logger)
		if err != nil {
			logger.Error("fcm init failed", "error", err)
			os.Exit(1)
		}
		sender := notification.NewSender(notification.NewStore(db), fcmClient)
		matchingSvc := matching.NewService(
			db, matching.NewStore(db),
			matching.NewNoopPointLocker(), matching.NewNoObligations(),
			judgement.NewProvisioner(), sender, jobs.NewStore(db),
		)

		if err := worker.Run(ctx, cfg, logger, db, func(ctx context.Context, w *worker.Worker) error {
			w.Register(matching.JobKindMatch, matchingSvc.HandleMatch)
			w.Register(matching.JobKindSweep, matchingSvc.HandleSweep)
			w.Register(notification.JobKindSendNotification, sender.HandleSend)
			// Seed the recurring sweep for the current interval; it self-reschedules
			// thereafter. Idempotent across restarts and workers (bucketed key).
			return matchingSvc.BootstrapSweep(ctx)
		}); err != nil {
			logger.Error("worker exited with error", "error", err)
			os.Exit(1)
		}
	default:
		fmt.Fprintf(os.Stderr, "unknown command: %s\n", os.Args[1])
		os.Exit(2)
	}
}

// buildFCMClient builds the worker's FCM sender. Production requires real
// Firebase credentials (a missing/broken client is fatal); other environments
// fall back to a no-op client that drops sends with a warning, so a local worker
// runs end-to-end without Firebase.
func buildFCMClient(ctx context.Context, cfg config.Config, logger *slog.Logger) (fcm.Client, error) {
	if cfg.FirebaseProjectID == "" {
		if cfg.Env == "production" {
			return nil, fmt.Errorf("FIREBASE_PROJECT_ID is required in production")
		}
		logger.Warn("FIREBASE_PROJECT_ID unset; worker uses no-op FCM (notifications dropped)")
		return fcm.NewNoop(logger), nil
	}
	client, err := fcm.New(ctx, cfg.FirebaseProjectID)
	if err != nil {
		if cfg.Env == "production" {
			return nil, fmt.Errorf("fcm init (required in production): %w", err)
		}
		logger.Warn("FCM init failed; worker uses no-op FCM (notifications dropped)", "error", err)
		return fcm.NewNoop(logger), nil
	}
	return client, nil
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
