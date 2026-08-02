-- Create "device_push_tokens" table
CREATE TABLE "device_push_tokens" (
  "id" uuid NOT NULL DEFAULT gen_random_uuid(),
  "user_id" uuid NOT NULL,
  "token" text NOT NULL,
  "device_type" text NULL,
  "created_at" timestamptz NOT NULL DEFAULT now(),
  "updated_at" timestamptz NOT NULL DEFAULT now(),
  "last_active_at" timestamptz NOT NULL DEFAULT now(),
  PRIMARY KEY ("id"),
  CONSTRAINT "device_push_tokens_token_key" UNIQUE ("token"),
  CONSTRAINT "device_push_tokens_user_id_fkey" FOREIGN KEY ("user_id") REFERENCES "users" ("id") ON UPDATE NO ACTION ON DELETE CASCADE
);
-- Create index "idx_device_push_tokens_last_active_at" to table: "device_push_tokens"
CREATE INDEX "idx_device_push_tokens_last_active_at" ON "device_push_tokens" ("last_active_at");
-- Create index "idx_device_push_tokens_user_id" to table: "device_push_tokens"
CREATE INDEX "idx_device_push_tokens_user_id" ON "device_push_tokens" ("user_id");
-- Create "notification_settings" table
CREATE TABLE "notification_settings" (
  "user_id" uuid NOT NULL,
  "evidence_reminder_minutes" integer[] NOT NULL DEFAULT '{10}',
  "judgement_reminder_minutes" integer[] NOT NULL DEFAULT '{10}',
  "auto_confirm_reminder_minutes" integer[] NULL,
  "evidence_reminder_even_if_submitted" boolean NOT NULL DEFAULT false,
  "created_at" timestamptz NOT NULL DEFAULT now(),
  "updated_at" timestamptz NOT NULL DEFAULT now(),
  PRIMARY KEY ("user_id"),
  CONSTRAINT "notification_settings_user_id_fkey" FOREIGN KEY ("user_id") REFERENCES "users" ("id") ON UPDATE NO ACTION ON DELETE CASCADE
);
-- Create "profiles" table
CREATE TABLE "profiles" (
  "id" uuid NOT NULL,
  "username" text NOT NULL,
  "avatar_url" text NULL,
  "timezone" text NOT NULL DEFAULT 'UTC',
  "created_at" timestamptz NOT NULL DEFAULT now(),
  "updated_at" timestamptz NOT NULL DEFAULT now(),
  PRIMARY KEY ("id"),
  CONSTRAINT "profiles_username_key" UNIQUE ("username"),
  CONSTRAINT "profiles_id_fkey" FOREIGN KEY ("id") REFERENCES "users" ("id") ON UPDATE NO ACTION ON DELETE CASCADE,
  CONSTRAINT "profiles_username_length" CHECK ((char_length(username) >= 2) AND (char_length(username) <= 20))
);
