package config

import "testing"

func TestLoadDefaults(t *testing.T) {
	t.Setenv("PORT", "")
	t.Setenv("DATABASE_URL", "")
	t.Setenv("LOG_LEVEL", "")
	t.Setenv("APP_ENV", "")
	t.Setenv("FIREBASE_PROJECT_ID", "")
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
