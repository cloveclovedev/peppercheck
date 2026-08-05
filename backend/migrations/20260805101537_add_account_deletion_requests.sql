-- Create "account_deletion_requests" table
CREATE TABLE "account_deletion_requests" (
  "id" uuid NOT NULL DEFAULT gen_random_uuid(),
  "user_id" uuid NOT NULL,
  "claimed_email" text NOT NULL,
  "status" text NOT NULL DEFAULT 'unverified',
  "source" text NOT NULL DEFAULT 'web',
  "requested_at" timestamptz NOT NULL DEFAULT now(),
  "updated_at" timestamptz NOT NULL DEFAULT now(),
  PRIMARY KEY ("id"),
  CONSTRAINT "account_deletion_requests_user_id_key" UNIQUE ("user_id"),
  CONSTRAINT "account_deletion_requests_user_id_fkey" FOREIGN KEY ("user_id") REFERENCES "users" ("id") ON UPDATE NO ACTION ON DELETE CASCADE
);
