-- Create "webhook_inbox" table
CREATE TABLE "webhook_inbox" (
  "id" uuid NOT NULL DEFAULT gen_random_uuid(),
  "source" text NOT NULL,
  "event_id" text NOT NULL,
  "payload" jsonb NOT NULL,
  "received_at" timestamptz NOT NULL DEFAULT now(),
  "processed_at" timestamptz NULL,
  PRIMARY KEY ("id"),
  CONSTRAINT "webhook_inbox_source_event_key" UNIQUE ("source", "event_id")
);
