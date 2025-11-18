-- Table: profiles
CREATE TABLE IF NOT EXISTS "public"."profiles" (
    "id" "uuid" NOT NULL,
    "username" "text",
    "avatar_url" "text",
    "created_at" timestamp with time zone DEFAULT "now"(),
    "stripe_connect_account_id" "text",
    "updated_at" timestamp with time zone DEFAULT "now"(),
    "timezone" "text" DEFAULT 'UTC'::"text"
);

ALTER TABLE "public"."profiles" OWNER TO "postgres";

-- Indexes
CREATE INDEX "idx_profiles_timezone" ON "public"."profiles" USING "btree" ("timezone");

