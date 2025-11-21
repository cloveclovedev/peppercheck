-- Table: task_referee_requests
CREATE TABLE IF NOT EXISTS "public"."task_referee_requests" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "task_id" "uuid" NOT NULL,
    "matching_strategy" "text" NOT NULL,
    "preferred_referee_id" "uuid",
    "status" "text" DEFAULT 'pending'::"text",
    "matched_referee_id" "uuid",
    "responded_at" timestamp with time zone,
    "created_at" timestamp with time zone DEFAULT "now"(),
    "updated_at" timestamp with time zone DEFAULT "now"(),
    CONSTRAINT "task_referee_requests_matching_strategy_check" CHECK (("matching_strategy" = ANY (ARRAY['standard'::"text", 'premium'::"text", 'direct'::"text"]))),
    CONSTRAINT "task_referee_requests_status_check" CHECK (("status" = ANY (ARRAY['pending'::"text", 'matched'::"text", 'accepted'::"text", 'declined'::"text", 'expired'::"text", 'closed'::"text"])))
);

ALTER TABLE "public"."task_referee_requests" OWNER TO "postgres";

ALTER TABLE ONLY "public"."task_referee_requests"
    ADD CONSTRAINT "task_referee_requests_pkey" PRIMARY KEY ("id");

-- Indexes
CREATE INDEX "idx_task_referee_requests_matched_referee_id" ON "public"."task_referee_requests" USING "btree" ("matched_referee_id");
CREATE INDEX "idx_task_referee_requests_matching_strategy" ON "public"."task_referee_requests" USING "btree" ("matching_strategy");
CREATE INDEX "idx_task_referee_requests_status" ON "public"."task_referee_requests" USING "btree" ("status");
CREATE INDEX "idx_task_referee_requests_task_id" ON "public"."task_referee_requests" USING "btree" ("task_id");
