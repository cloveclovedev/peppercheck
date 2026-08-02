// Package notification owns notification settings provisioning and FCM
// registration-token binding behind the Go API. Phase 3a has no settings or
// token read model — settings are created at provisioning with column defaults,
// and tokens are write-only (upsert on registration, delete on sign-out); the
// settings-editing UI and the notification-send path arrive in later phases.
package notification
