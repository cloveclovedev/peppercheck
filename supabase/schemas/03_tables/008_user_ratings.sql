-- Table: user_ratings
CREATE TABLE IF NOT EXISTS "public"."user_ratings" (
    "user_id" "uuid" NOT NULL,
    "tasker_rating" numeric DEFAULT 0,
    "tasker_rating_count" integer DEFAULT 0,
    "referee_rating" numeric DEFAULT 0,
    "referee_rating_count" integer DEFAULT 0,
    "created_at" timestamp with time zone DEFAULT "now"(),
    "updated_at" timestamp with time zone DEFAULT "now"()
);

ALTER TABLE "public"."user_ratings" OWNER TO "postgres";

