-- Table: judgements
CREATE TABLE IF NOT EXISTS "public"."judgements" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "task_id" "uuid" NOT NULL,
    "referee_id" "uuid" NOT NULL,
    "comment" "text",
    "status" "text" DEFAULT 'open'::"text" NOT NULL,
    "created_at" timestamp with time zone DEFAULT "now"(),
    "updated_at" timestamp with time zone DEFAULT "now"(),
    "is_confirmed" boolean DEFAULT false,
    "reopen_count" smallint DEFAULT 0 NOT NULL,
    "is_evidence_timeout_confirmed" boolean DEFAULT false NOT NULL
);

ALTER TABLE "public"."judgements" OWNER TO "postgres";

ALTER TABLE ONLY "public"."judgements"
    ADD CONSTRAINT "judgements_pkey" PRIMARY KEY ("id");

