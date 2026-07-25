// Package config loads runtime configuration from environment variables with
// sane defaults. Precedence is defaults then environment. Secrets may also
// arrive via Docker file-based secrets: for a given KEY, setting KEY_FILE to
// a path takes precedence and is resolved fail-closed — if KEY_FILE is set
// but the file cannot be read, Load returns an error rather than silently
// falling back to the KEY environment variable.
package config

import (
	"fmt"
	"os"
	"strconv"
	"strings"
)

// Config is the fully-resolved runtime configuration for every command.
type Config struct {
	Env               string // local | staging | production
	Port              int    // HTTP listen port for the api command
	DatabaseURL       string // libpq/pgx connection string
	LogLevel          string // debug | info | warn | error
	ShutdownTimeout   int    // graceful-shutdown budget in seconds
	FirebaseProjectID string // Firebase project ID for ID-token verification
}

// Load reads configuration from the environment and validates it.
func Load() (Config, error) {
	databaseURL, _, err := lookupEnvOrFile("DATABASE_URL")
	if err != nil {
		return Config{}, fmt.Errorf("resolving DATABASE_URL: %w", err)
	}

	c := Config{
		Env:               getenv("APP_ENV", "local"),
		Port:              getenvInt("PORT", 8765),
		DatabaseURL:       databaseURL,
		LogLevel:          getenv("LOG_LEVEL", "info"),
		ShutdownTimeout:   getenvInt("SHUTDOWN_TIMEOUT_SECONDS", 15),
		FirebaseProjectID: os.Getenv("FIREBASE_PROJECT_ID"),
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
