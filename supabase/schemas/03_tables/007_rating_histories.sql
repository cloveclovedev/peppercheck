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

