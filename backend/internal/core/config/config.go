// Package config loads runtime configuration from environment variables with
// sane defaults. Precedence is defaults then environment. Secrets may also
// arrive via Docker file-based secrets: for a given KEY, setting KEY_FILE to
// a path takes precedence and is resolved fail-closed — if KEY_FILE is set
// but the file cannot be read, Load returns an error rather than silently
// falling back to the KEY environment variable.
package config

import (
	"errors"
	"fmt"
	"os"
	"strconv"
	"strings"
)

// Config is the fully-resolved runtime configuration for every command.
type Config struct {
	Env                string // local | staging | production
	Port               int    // HTTP listen port for the api command
	DatabaseURL        string // libpq/pgx connection string
	LogLevel           string // debug | info | warn | error
	ShutdownTimeout    int    // graceful-shutdown budget in seconds
	FirebaseProjectID  string // Firebase project ID for ID-token verification
	HeartbeatURLWorker string // optional Better Stack heartbeat URL, POSTed after each successful worker RunDue cycle

	// R2 (Cloudflare) object storage for avatar uploads (platform/r2). Account
	// ID / bucket / public domain are non-secret; the access key id and secret
	// are credentials and follow the fail-closed *_FILE convention.
	R2AccountID       string
	R2AccessKeyID     string
	R2SecretAccessKey string
	R2Bucket          string
	R2PublicDomain    string // e.g. "cdn.peppercheck.dev" — the host avatar URLs are served from

	// WebFormSigningKey is the HMAC key for internal/web's anti-abuse form
	// token (Phase 3b account-deletion request form). Unlike every other
	// secret here, this one is validated non-empty in Load(): an empty HMAC
	// key would let anyone forge a valid form token, so this fails closed at
	// startup rather than silently accepting forgeable tokens.
	WebFormSigningKey string
}

// Load reads configuration from the environment and validates it.
func Load() (Config, error) {
	databaseURL, _, err := lookupEnvOrFile("DATABASE_URL")
	if err != nil {
		return Config{}, fmt.Errorf("resolving DATABASE_URL: %w", err)
	}

	// HEARTBEAT_URL_WORKER is optional -- not every environment (e.g. local
	// dev) monitors the worker this way -- but it carries a Better Stack
	// auth token in the URL, so it still gets the same fail-closed *_FILE
	// convention as every other config value that can hold a secret.
	heartbeatURLWorker, _, err := lookupEnvOrFile("HEARTBEAT_URL_WORKER")
	if err != nil {
		return Config{}, fmt.Errorf("resolving HEARTBEAT_URL_WORKER: %w", err)
	}

	r2AccessKeyID, _, err := lookupEnvOrFile("R2_ACCESS_KEY_ID")
	if err != nil {
		return Config{}, fmt.Errorf("resolving R2_ACCESS_KEY_ID: %w", err)
	}
	r2SecretAccessKey, _, err := lookupEnvOrFile("R2_SECRET_ACCESS_KEY")
	if err != nil {
		return Config{}, fmt.Errorf("resolving R2_SECRET_ACCESS_KEY: %w", err)
	}

	webFormSigningKey, _, err := lookupEnvOrFile("WEB_FORM_SIGNING_KEY")
	if err != nil {
		return Config{}, fmt.Errorf("resolving WEB_FORM_SIGNING_KEY: %w", err)
	}
	if webFormSigningKey == "" {
		return Config{}, errors.New("config: WEB_FORM_SIGNING_KEY (or _FILE) is required")
	}

	c := Config{
		Env:                getenv("APP_ENV", "local"),
		Port:               getenvInt("PORT", 8765),
		DatabaseURL:        databaseURL,
		LogLevel:           getenv("LOG_LEVEL", "info"),
		ShutdownTimeout:    getenvInt("SHUTDOWN_TIMEOUT_SECONDS", 15),
		FirebaseProjectID:  os.Getenv("FIREBASE_PROJECT_ID"),
		HeartbeatURLWorker: heartbeatURLWorker,
		R2AccountID:        os.Getenv("R2_ACCOUNT_ID"),
		R2AccessKeyID:      r2AccessKeyID,
		R2SecretAccessKey:  r2SecretAccessKey,
		R2Bucket:           os.Getenv("R2_BUCKET"),
		R2PublicDomain:     os.Getenv("R2_PUBLIC_DOMAIN"),
		WebFormSigningKey:  webFormSigningKey,
	}
	if c.Port < 1 || c.Port > 65535 {
		return Config{}, fmt.Errorf("invalid PORT: %d", c.Port)
	}
	return c, nil
}

// lookupEnvOrFile resolves a configuration value that may be supplied either
// directly via the KEY environment variable or, for Docker file-based
// secrets, via a KEY_FILE environment variable pointing at a file containing
// the value.
//
// If KEY_FILE is set, its contents (trimmed) are always used and the file
// MUST be readable — this is fail-closed: a set-but-unreadable KEY_FILE
// returns an error rather than silently falling back to KEY, so a
// misconfigured secret mount aborts startup instead of running with a wrong
// or empty value. If KEY_FILE is unset, KEY is read from the environment
// (the local-development fallback), returning ok=false if it is also unset.
func lookupEnvOrFile(key string) (string, bool, error) {
	if path, ok := os.LookupEnv(key + "_FILE"); ok && strings.TrimSpace(path) != "" {
		b, err := os.ReadFile(path)
		if err != nil {
			return "", false, fmt.Errorf("reading %s_FILE at %q: %w", key, path, err)
		}
		return strings.TrimSpace(string(b)), true, nil
	}
	v, ok := os.LookupEnv(key)
	return v, ok, nil
}

func getenv(key, def string) string {
	if v, ok := os.LookupEnv(key); ok && strings.TrimSpace(v) != "" {
		return v
	}
	return def
}

func getenvInt(key string, def int) int {
	if v, ok := os.LookupEnv(key); ok {
		if n, err := strconv.Atoi(strings.TrimSpace(v)); err == nil {
			return n
		}
	}
	return def
}
