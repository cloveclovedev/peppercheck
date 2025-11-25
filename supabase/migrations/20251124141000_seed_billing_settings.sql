-- Seed initial billing_settings singleton row
BEGIN;

INSERT INTO public.billing_settings (id, max_retry_attempts)
VALUES (1, 3)
ON CONFLICT (id) DO NOTHING;

COMMIT;
