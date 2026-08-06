-- Per-user notification settings (created at provisioning). Reminder arrays are
-- NOT NULL with defaults (deliberate hardening vs the old nullable columns).
-- updated_at is Go-maintained (updated_at = now() on each UPDATE).
CREATE TABLE public.notification_settings (
    user_id                             uuid PRIMARY KEY REFERENCES public.users (id) ON DELETE CASCADE,
    evidence_reminder_minutes           int[] NOT NULL DEFAULT '{10}',
    judgement_reminder_minutes          int[] NOT NULL DEFAULT '{10}',
    auto_confirm_reminder_minutes       int[],
    evidence_reminder_even_if_submitted boolean NOT NULL DEFAULT false,
    created_at                          timestamptz NOT NULL DEFAULT now(),
    updated_at                          timestamptz NOT NULL DEFAULT now()
);
