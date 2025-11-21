-- Table: rating_histories
CREATE TABLE IF NOT EXISTS "public"."rating_histories" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "ratee_id" "uuid",
    "task_id" "uuid",
    "rating_type" "text" NOT NULL,
    "rating" numeric NOT NULL,
    "comment" "text",
    "created_at" timestamp with time zone DEFAULT "now"(),
    "rater_id" "uuid",
    "judgement_id" "uuid",
    CONSTRAINT "rating_histories_rating_check" CHECK ((("rating" >= (0)::numeric) AND ("rating" <= (5)::numeric))),
    CONSTRAINT "rating_histories_rating_type_check" CHECK (("rating_type" = ANY (ARRAY['tasker'::"text", 'referee'::"text"])))
);

ALTER TABLE "public"."rating_histories" OWNER TO "postgres";

ALTER TABLE ONLY "public"."rating_histories"
    ADD CONSTRAINT "rating_history_pkey" PRIMARY KEY ("id");

ALTER TABLE ONLY "public"."rating_histories"
    ADD CONSTRAINT "unique_rating_per_judgement" UNIQUE ("rater_id", "ratee_id", "judgement_id");

-- Indexes
CREATE INDEX "idx_rating_histories_task_id" ON "public"."rating_histories" USING "btree" ("task_id");
CREATE INDEX "idx_rating_histories_user_id" ON "public"."rating_histories" USING "btree" ("ratee_id");
CREATE INDEX "idx_rating_histories_user_type" ON "public"."rating_histories" USING "btree" ("ratee_id", "rating_type");
