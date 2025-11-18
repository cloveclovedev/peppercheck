-- Table: judgement_threads
CREATE TABLE IF NOT EXISTS "public"."judgement_threads" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "judgement_id" "uuid" NOT NULL,
    "sender_id" "uuid" NOT NULL,
    "message" "text" NOT NULL,
    "created_at" timestamp with time zone DEFAULT "now"(),
    "updated_at" timestamp with time zone DEFAULT "now"()
);

ALTER TABLE "public"."judgement_threads" OWNER TO "postgres";

-- Indexes
CREATE INDEX "idx_judgement_threads_judgement_id" ON "public"."judgement_threads" USING "btree" ("judgement_id");
CREATE INDEX "idx_judgement_threads_sender_id" ON "public"."judgement_threads" USING "btree" ("sender_id");

