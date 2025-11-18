-- Table: judgement_thread_assets
CREATE TABLE IF NOT EXISTS "public"."judgement_thread_assets" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "thread_id" "uuid" NOT NULL,
    "type" "text" NOT NULL,
    "file_url" "text" NOT NULL,
    "created_at" timestamp with time zone DEFAULT "now"()
);

ALTER TABLE "public"."judgement_thread_assets" OWNER TO "postgres";

-- Indexes
CREATE INDEX "idx_judgement_thread_assets_thread_id" ON "public"."judgement_thread_assets" USING "btree" ("thread_id");

