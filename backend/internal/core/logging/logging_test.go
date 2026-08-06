package logging

import (
	"context"
	"log/slog"
	"testing"
)

func TestNewLevel(t *testing.T) {
	l := New("warn")
	if l.Enabled(context.Background(), slog.LevelInfo) {
		t.Errorf("info should be disabled at warn level")
	}
	if !l.Enabled(context.Background(), slog.LevelWarn) {
		t.Errorf("warn should be enabled at warn level")
	}
}

func TestNewDefaultsToInfo(t *testing.T) {
	l := New("nonsense")
	if !l.Enabled(context.Background(), slog.LevelInfo) {
		t.Errorf("unknown level must default to info")
	}
}
