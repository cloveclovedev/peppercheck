// Package notification owns notification settings provisioning and device
// push-token binding behind the Go API (the token value is an FCM registration
// token — the provider name stops at this boundary). Phase 3a has no settings or
// token read model — settings are created at provisioning with column defaults,
// and tokens are write-only (upsert on registration, delete on sign-out); the
// settings-editing UI and the notification-send path arrive in later phases.
package notification
