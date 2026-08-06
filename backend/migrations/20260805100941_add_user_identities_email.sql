-- Modify "user_identities" table
ALTER TABLE "user_identities" ADD COLUMN "email" text NULL, ADD COLUMN "email_verified" boolean NOT NULL DEFAULT false;
-- Create index "user_identities_email_lower_idx" to table: "user_identities"
CREATE INDEX "user_identities_email_lower_idx" ON "user_identities" ((lower(email)));
