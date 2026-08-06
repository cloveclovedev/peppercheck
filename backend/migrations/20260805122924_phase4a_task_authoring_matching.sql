-- Create enum type "task_status"
CREATE TYPE "task_status" AS ENUM ('draft', 'open', 'closed');
-- Create enum type "matching_strategy"
CREATE TYPE "matching_strategy" AS ENUM ('standard');
-- Create enum type "referee_request_status"
CREATE TYPE "referee_request_status" AS ENUM ('pending', 'accepted', 'expired', 'cancelled', 'closed', 'payment_processing');
-- Create enum type "point_source_type"
CREATE TYPE "point_source_type" AS ENUM ('regular', 'trial');
-- Create enum type "judgement_status"
CREATE TYPE "judgement_status" AS ENUM ('awaiting_evidence', 'in_review', 'approved', 'rejected', 'review_timeout', 'evidence_timeout');
-- Create "matching_config" table
CREATE TABLE "matching_config" (
  "id" boolean NOT NULL DEFAULT true,
  "open_deadline_hours" integer NOT NULL,
  "cancel_deadline_hours" integer NOT NULL,
  "rematch_cutoff_hours" integer NOT NULL,
  "max_referees_per_task" integer NOT NULL DEFAULT 2,
  "point_cost_per_request" integer NOT NULL DEFAULT 1,
  "updated_at" timestamptz NOT NULL DEFAULT now(),
  PRIMARY KEY ("id"),
  CONSTRAINT "matching_config_cancel_deadline_hours_check" CHECK (cancel_deadline_hours > 0),
  CONSTRAINT "matching_config_id_check" CHECK (id = true),
  CONSTRAINT "matching_config_max_referees_per_task_check" CHECK (max_referees_per_task >= 1),
  CONSTRAINT "matching_config_point_cost_per_request_check" CHECK (point_cost_per_request >= 0),
  CONSTRAINT "ordering_invariant" CHECK ((open_deadline_hours > rematch_cutoff_hours) AND (rematch_cutoff_hours > cancel_deadline_hours))
);
-- Create "tasks" table
CREATE TABLE "tasks" (
  "id" uuid NOT NULL DEFAULT gen_random_uuid(),
  "tasker_id" uuid NULL,
  "title" text NOT NULL,
  "description" text NULL,
  "criteria" text NULL,
  "due_date" timestamptz NULL,
  "status" "task_status" NOT NULL DEFAULT 'draft',
  "created_at" timestamptz NOT NULL DEFAULT now(),
  "updated_at" timestamptz NOT NULL DEFAULT now(),
  PRIMARY KEY ("id"),
  CONSTRAINT "tasks_tasker_id_fkey" FOREIGN KEY ("tasker_id") REFERENCES "users" ("id") ON UPDATE NO ACTION ON DELETE SET NULL
);
-- Create index "idx_tasks_tasker_status" to table: "tasks"
CREATE INDEX "idx_tasks_tasker_status" ON "tasks" ("tasker_id", "status");
-- Create "referee_requests" table
CREATE TABLE "referee_requests" (
  "id" uuid NOT NULL DEFAULT gen_random_uuid(),
  "task_id" uuid NOT NULL,
  "matching_strategy" "matching_strategy" NOT NULL DEFAULT 'standard',
  "status" "referee_request_status" NOT NULL DEFAULT 'pending',
  "matched_referee_id" uuid NULL,
  "responded_at" timestamptz NULL,
  "point_source" "point_source_type" NOT NULL DEFAULT 'regular',
  "is_obligation" boolean NOT NULL DEFAULT false,
  "created_at" timestamptz NOT NULL DEFAULT now(),
  "updated_at" timestamptz NOT NULL DEFAULT now(),
  PRIMARY KEY ("id"),
  CONSTRAINT "referee_requests_matched_referee_id_fkey" FOREIGN KEY ("matched_referee_id") REFERENCES "users" ("id") ON UPDATE NO ACTION ON DELETE SET NULL,
  CONSTRAINT "referee_requests_task_id_fkey" FOREIGN KEY ("task_id") REFERENCES "tasks" ("id") ON UPDATE NO ACTION ON DELETE CASCADE
);
-- Create index "idx_referee_requests_matched" to table: "referee_requests"
CREATE INDEX "idx_referee_requests_matched" ON "referee_requests" ("matched_referee_id");
-- Create index "idx_referee_requests_status" to table: "referee_requests"
CREATE INDEX "idx_referee_requests_status" ON "referee_requests" ("status");
-- Create index "idx_referee_requests_task" to table: "referee_requests"
CREATE INDEX "idx_referee_requests_task" ON "referee_requests" ("task_id");
-- Create index "uq_referee_requests_task_accepted_referee" to table: "referee_requests"
CREATE UNIQUE INDEX "uq_referee_requests_task_accepted_referee" ON "referee_requests" ("task_id", "matched_referee_id") WHERE ((status = 'accepted'::referee_request_status) AND (matched_referee_id IS NOT NULL));
-- Create "judgements" table
CREATE TABLE "judgements" (
  "id" uuid NOT NULL,
  "status" "judgement_status" NOT NULL DEFAULT 'awaiting_evidence',
  "comment" text NULL,
  "is_confirmed" boolean NOT NULL DEFAULT false,
  "is_auto_confirmed" boolean NOT NULL DEFAULT false,
  "reopen_count" smallint NOT NULL DEFAULT 0,
  "created_at" timestamptz NOT NULL DEFAULT now(),
  "updated_at" timestamptz NOT NULL DEFAULT now(),
  PRIMARY KEY ("id"),
  CONSTRAINT "judgements_id_fkey" FOREIGN KEY ("id") REFERENCES "referee_requests" ("id") ON UPDATE NO ACTION ON DELETE CASCADE
);
-- Create "referee_availability" table
CREATE TABLE "referee_availability" (
  "user_id" uuid NOT NULL,
  "is_accepting" boolean NOT NULL DEFAULT true,
  "max_concurrent_assignments" integer NULL,
  "created_at" timestamptz NOT NULL DEFAULT now(),
  "updated_at" timestamptz NOT NULL DEFAULT now(),
  PRIMARY KEY ("user_id"),
  CONSTRAINT "referee_availability_user_id_fkey" FOREIGN KEY ("user_id") REFERENCES "users" ("id") ON UPDATE NO ACTION ON DELETE CASCADE
);
-- Create "referee_available_time_slots" table
CREATE TABLE "referee_available_time_slots" (
  "id" uuid NOT NULL DEFAULT gen_random_uuid(),
  "user_id" uuid NOT NULL,
  "dow" smallint NOT NULL,
  "start_min" smallint NOT NULL,
  "end_min" smallint NOT NULL,
  "is_active" boolean NOT NULL DEFAULT true,
  "created_at" timestamptz NOT NULL DEFAULT now(),
  "updated_at" timestamptz NOT NULL DEFAULT now(),
  PRIMARY KEY ("id"),
  CONSTRAINT "referee_available_time_slots_user_id_dow_start_min_key" UNIQUE ("user_id", "dow", "start_min"),
  CONSTRAINT "referee_available_time_slots_user_id_fkey" FOREIGN KEY ("user_id") REFERENCES "users" ("id") ON UPDATE NO ACTION ON DELETE CASCADE,
  CONSTRAINT "referee_available_time_slots_dow_check" CHECK ((dow >= 0) AND (dow <= 6)),
  CONSTRAINT "referee_available_time_slots_end_min_check" CHECK ((end_min >= 1) AND (end_min <= 1440)),
  CONSTRAINT "referee_available_time_slots_start_min_check" CHECK ((start_min >= 0) AND (start_min <= 1439)),
  CONSTRAINT "valid_time_range" CHECK (start_min < end_min)
);
-- Create index "idx_ravts_dow_time" to table: "referee_available_time_slots"
CREATE INDEX "idx_ravts_dow_time" ON "referee_available_time_slots" ("dow", "start_min", "end_min") WHERE is_active;
-- Create index "idx_ravts_user" to table: "referee_available_time_slots"
CREATE INDEX "idx_ravts_user" ON "referee_available_time_slots" ("user_id");
-- Create "referee_blocked_dates" table
CREATE TABLE "referee_blocked_dates" (
  "id" uuid NOT NULL DEFAULT gen_random_uuid(),
  "user_id" uuid NOT NULL,
  "start_date" date NOT NULL,
  "end_date" date NOT NULL,
  "reason" text NULL,
  "created_at" timestamptz NOT NULL DEFAULT now(),
  "updated_at" timestamptz NOT NULL DEFAULT now(),
  PRIMARY KEY ("id"),
  CONSTRAINT "referee_blocked_dates_user_id_fkey" FOREIGN KEY ("user_id") REFERENCES "users" ("id") ON UPDATE NO ACTION ON DELETE CASCADE,
  CONSTRAINT "valid_date_range" CHECK (end_date >= start_date)
);
-- Create index "idx_rbd_user" to table: "referee_blocked_dates"
CREATE INDEX "idx_rbd_user" ON "referee_blocked_dates" ("user_id");
-- Seed the matching_config singleton. DML, not detected by schema diff. Values
-- are the current production matching_time_config: open=24 > rematch=14 >
-- cancel=12 (satisfies ordering_invariant).
INSERT INTO "matching_config" ("id", "open_deadline_hours", "cancel_deadline_hours", "rematch_cutoff_hours")
VALUES (true, 24, 12, 14)
ON CONFLICT ("id") DO NOTHING;
