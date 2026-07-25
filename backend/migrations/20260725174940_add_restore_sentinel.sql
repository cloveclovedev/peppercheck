-- Create "restore_sentinel" table
CREATE TABLE "restore_sentinel" (
  "id" bigserial NOT NULL,
  "tag" text NULL,
  "created_at" timestamptz NOT NULL DEFAULT now(),
  PRIMARY KEY ("id")
);
