-- Table: task_evidences
CREATE TABLE IF NOT EXISTS "public"."task_evidences" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "task_id" "uuid" NOT NULL,
    "description" "text" NOT NULL,
    "status" "text" DEFAULT 'pending_upload'::"text" NOT NULL,
    "created_at" timestamp with time zone DEFAULT "now"(),
    "updated_at" timestamp with time zone DEFAULT "now"(),
    CONSTRAINT "task_evidences_status_check" CHECK (("status" = ANY (ARRAY['pending_upload'::"text", 'ready'::"text"])))
);

ALTER TABLE "public"."task_evidences" OWNER TO "postgres";

