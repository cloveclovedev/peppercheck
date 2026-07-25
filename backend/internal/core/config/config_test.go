package config

import (
	"os"
	"path/filepath"
	"testing"
)

func TestLoadDefaults(t *testing.T) {
	t.Setenv("PORT", "")
	t.Setenv("DATABASE_URL", "")
	t.Setenv("LOG_LEVEL", "")
	t.Setenv("APP_ENV", "")
	t.Setenv("FIREBASE_PROJECT_ID", "")
	t.Setenv("HEARTBEAT_URL_WORKER", "")
	t.Setenv("HEARTBEAT_URL_WORKER_FILE", "")
	c, err := Load()
	if err != nil {
		t.Fatalf("Load: %v", err)
	}
	if c.Port != 8765 {
		t.Errorf("Port = %d, want 8765", c.Port)
	}
	if c.Env != "local" {
		t.Errorf("Env = %q, want local", c.Env)
	}
	if c.LogLevel != "info" {
		t.Errorf("LogLevel = %q, want info", c.LogLevel)
	}
	if c.ShutdownTimeout != 15 {
		t.Errorf("ShutdownTimeout = %d, want 15", c.ShutdownTimeout)
	}
	if c.FirebaseProjectID != "" {
		t.Errorf("FirebaseProjectID = %q, want empty by default", c.FirebaseProjectID)
	}
	if c.HeartbeatURLWorker != "" {
		t.Errorf("HeartbeatURLWorker = %q, want empty by default (heartbeat is optional)", c.HeartbeatURLWorker)
	}
}

func TestLoadReadsHeartbeatURLWorker(t *testing.T) {
	t.Setenv("HEARTBEAT_URL_WORKER", "https://uptime.betterstack.com/api/v1/heartbeat/token")
	c, err := Load()
	if err != nil {
		t.Fatalf("Load: %v", err)
	}
	if c.HeartbeatURLWorker != "https://uptime.betterstack.com/api/v1/heartbeat/token" {
		t.Fatalf("HeartbeatURLWorker = %q, want the configured heartbeat URL", c.HeartbeatURLWorker)
	}
}

func TestLoadReadsFirebaseProjectID(t *testing.T) {
	t.Setenv("FIREBASE_PROJECT_ID", "peppercheck-dev")
	c, err := Load()
	if err != nil {
		t.Fatalf("Load: %v", err)
	}
	if c.FirebaseProjectID != "peppercheck-dev" {
		t.Fatalf("FirebaseProjectID = %q, want peppercheck-dev", c.FirebaseProjectID)
	}
}

func TestLoadOverridesAndValidation(t *testing.T) {
	t.Setenv("PORT", "9090")
	t.Setenv("DATABASE_URL", "postgres://x")
	c, err := Load()
	if err != nil {
		t.Fatalf("Load: %v", err)
	}
	if c.Port != 9090 {
		t.Errorf("Port = %d, want 9090", c.Port)
	}
	if c.DatabaseURL != "postgres://x" {
		t.Errorf("DatabaseURL = %q", c.DatabaseURL)
	}

	t.Setenv("PORT", "70000")
	if _, err := Load(); err == nil {
		t.Errorf("expected error for out-of-range PORT")
	}
}

func TestLookupEnvOrFile(t *testing.T) {
	t.Run("file wins over env and is trimmed", func(t *testing.T) {
		dir := t.TempDir()
		path := filepath.Join(dir, "secret")
		if err := os.WriteFile(path, []byte("from-file\n"), 0o600); err != nil {
			t.Fatalf("WriteFile: %v", err)
		}
		t.Setenv("TEST_SECRET", "from-env")
		t.Setenv("TEST_SECRET_FILE", path)

		v, ok, err := lookupEnvOrFile("TEST_SECRET")
		if err != nil {
			t.Fatalf("lookupEnvOrFile: %v", err)
		}
		if !ok {
			t.Fatalf("ok = false, want true")
		}
		if v != "from-file" {
			t.Errorf("v = %q, want %q", v, "from-file")
		}
	})

	t.Run("file set but unreadable returns error, no silent fallback", func(t *testing.T) {
		dir := t.TempDir()
		path := filepath.Join(dir, "does-not-exist")
		t.Setenv("TEST_SECRET", "from-env")
		t.Setenv("TEST_SECRET_FILE", path)

		v, _, err := lookupEnvOrFile("TEST_SECRET")
		if err == nil {
			t.Fatalf("expected error for unreadable file, got v = %q", v)
		}
	})

	t.Run("no file falls back to env", func(t *testing.T) {
		t.Setenv("TEST_SECRET", "from-env")
		t.Setenv("TEST_SECRET_FILE", "")

		v, ok, err := lookupEnvOrFile("TEST_SECRET")
		if err != nil {
			t.Fatalf("lookupEnvOrFile: %v", err)
		}
		if !ok {
			t.Fatalf("ok = false, want true")
		}
		if v != "from-env" {
			t.Errorf("v = %q, want %q", v, "from-env")
		}
	})
}
