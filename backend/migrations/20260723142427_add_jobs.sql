-- Create "jobs" table
CREATE TABLE "jobs" (
  "id" uuid NOT NULL DEFAULT gen_random_uuid(),
  "kind" text NOT NULL,
  "payload" jsonb NOT NULL DEFAULT '{}',
  "idempotency_key" text NULL,
  "status" text NOT NULL DEFAULT 'pending',
  "run_at" timestamptz NOT NULL DEFAULT now(),
  "attempts" integer NOT NULL DEFAULT 0,
  "max_attempts" integer NOT NULL DEFAULT 20,
  "last_error" text NULL,
  "locked_at" timestamptz NULL,
  "locked_by" text NULL,
  "lease_until" timestamptz NULL,
  "created_at" timestamptz NOT NULL DEFAULT now(),
  "updated_at" timestamptz NOT NULL DEFAULT now(),
  PRIMARY KEY ("id"),
  CONSTRAINT "jobs_idempotency_key_key" UNIQUE ("idempotency_key"),
  CONSTRAINT "jobs_status_check" CHECK (status = ANY (ARRAY['pending'::text, 'running'::text, 'succeeded'::text, 'failed'::text]))
);
-- Create index "jobs_pending_run_at_idx" to table: "jobs"
CREATE INDEX "jobs_pending_run_at_idx" ON "jobs" ("run_at") WHERE (status = 'pending'::text);
-- Create index "jobs_running_lease_idx" to table: "jobs"
CREATE INDEX "jobs_running_lease_idx" ON "jobs" ("lease_until") WHERE (status = 'running'::text);
