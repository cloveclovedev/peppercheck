-- Idempotency ledger for inbound webhooks. The api records each event once;
-- duplicate deliveries collide on (source, event_id) and are ignored. The
-- worker later processes unprocessed rows.
CREATE TABLE public.webhook_inbox (
    id           uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    source       text NOT NULL,
    event_id     text NOT NULL,
    payload      jsonb NOT NULL,
    received_at  timestamptz NOT NULL DEFAULT now(),
    processed_at timestamptz,
    CONSTRAINT webhook_inbox_source_event_key UNIQUE (source, event_id)
);
