// Package config loads runtime configuration from environment variables with
// sane defaults. Precedence is defaults then environment; secrets arrive only
// via environment variables, never from files committed to the repo.
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
	c := Config{
		Env:               getenv("APP_ENV", "local"),
		Port:              getenvInt("PORT", 8765),
		DatabaseURL:       os.Getenv("DATABASE_URL"),
		LogLevel:          getenv("LOG_LEVEL", "info"),
		ShutdownTimeout:   getenvInt("SHUTDOWN_TIMEOUT_SECONDS", 15),
		FirebaseProjectID: os.Getenv("FIREBASE_PROJECT_ID"),
	}
	if c.Port < 1 || c.Port > 65535 {
		return Config{}, fmt.Errorf("invalid PORT: %d", c.Port)
	}
	return c, nil
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
