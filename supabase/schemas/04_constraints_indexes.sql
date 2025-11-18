-- Constraints
ALTER TABLE ONLY "public"."rating_histories"
    ADD CONSTRAINT "fk_rating_histories_judgement_id" FOREIGN KEY ("judgement_id") REFERENCES "public"."judgements"("id");

ALTER TABLE ONLY "public"."rating_histories"
    ADD CONSTRAINT "fk_rating_histories_rater_id" FOREIGN KEY ("rater_id") REFERENCES "public"."profiles"("id");

ALTER TABLE ONLY "public"."judgement_thread_assets"
    ADD CONSTRAINT "judgement_thread_assets_thread_id_fkey" FOREIGN KEY ("thread_id") REFERENCES "public"."judgement_threads"("id") ON DELETE CASCADE;

ALTER TABLE ONLY "public"."judgement_threads"
    ADD CONSTRAINT "judgement_threads_judgement_id_fkey" FOREIGN KEY ("judgement_id") REFERENCES "public"."judgements"("id") ON DELETE CASCADE;

ALTER TABLE ONLY "public"."judgement_threads"
    ADD CONSTRAINT "judgement_threads_sender_id_fkey" FOREIGN KEY ("sender_id") REFERENCES "public"."profiles"("id") ON DELETE SET NULL;

ALTER TABLE ONLY "public"."judgements"
    ADD CONSTRAINT "judgements_referee_id_fkey" FOREIGN KEY ("referee_id") REFERENCES "public"."profiles"("id") ON DELETE SET NULL;

ALTER TABLE ONLY "public"."judgements"
    ADD CONSTRAINT "judgements_task_id_fkey" FOREIGN KEY ("task_id") REFERENCES "public"."tasks"("id") ON DELETE CASCADE;

ALTER TABLE ONLY "public"."profiles"
    ADD CONSTRAINT "profiles_id_fkey" FOREIGN KEY ("id") REFERENCES "auth"."users"("id");

ALTER TABLE ONLY "public"."rating_histories"
    ADD CONSTRAINT "rating_histories_task_id_fkey" FOREIGN KEY ("task_id") REFERENCES "public"."tasks"("id") ON DELETE SET NULL;

ALTER TABLE ONLY "public"."rating_histories"
    ADD CONSTRAINT "rating_histories_user_id_fkey" FOREIGN KEY ("ratee_id") REFERENCES "public"."profiles"("id") ON DELETE SET NULL;

ALTER TABLE ONLY "public"."referee_available_time_slots"
    ADD CONSTRAINT "referee_available_time_slots_user_id_fkey" FOREIGN KEY ("user_id") REFERENCES "public"."profiles"("id") ON DELETE CASCADE;

ALTER TABLE ONLY "public"."task_evidence_assets"
    ADD CONSTRAINT "task_evidence_assets_evidence_id_fkey" FOREIGN KEY ("evidence_id") REFERENCES "public"."task_evidences"("id") ON DELETE CASCADE;

ALTER TABLE ONLY "public"."task_evidences"
    ADD CONSTRAINT "task_evidences_task_id_fkey" FOREIGN KEY ("task_id") REFERENCES "public"."tasks"("id") ON DELETE CASCADE;

ALTER TABLE ONLY "public"."task_referee_requests"
    ADD CONSTRAINT "task_referee_requests_matched_referee_id_fkey" FOREIGN KEY ("matched_referee_id") REFERENCES "public"."profiles"("id");

ALTER TABLE ONLY "public"."task_referee_requests"
    ADD CONSTRAINT "task_referee_requests_preferred_referee_id_fkey" FOREIGN KEY ("preferred_referee_id") REFERENCES "public"."profiles"("id");

ALTER TABLE ONLY "public"."task_referee_requests"
    ADD CONSTRAINT "task_referee_requests_task_id_fkey" FOREIGN KEY ("task_id") REFERENCES "public"."tasks"("id") ON DELETE CASCADE;

ALTER TABLE ONLY "public"."tasks"
    ADD CONSTRAINT "tasks_tasker_id_fkey" FOREIGN KEY ("tasker_id") REFERENCES "public"."profiles"("id") ON DELETE SET NULL;

ALTER TABLE ONLY "public"."stripe_accounts"
    ADD CONSTRAINT "stripe_accounts_profile_id_fkey" FOREIGN KEY ("profile_id") REFERENCES "public"."profiles"("id") ON DELETE CASCADE;


ALTER TABLE ONLY "public"."user_ratings"
    ADD CONSTRAINT "user_ratings_user_id_fkey" FOREIGN KEY ("user_id") REFERENCES "public"."profiles"("id") ON DELETE CASCADE;



-- Indexes
CREATE INDEX "idx_judgement_thread_assets_thread_id" ON "public"."judgement_thread_assets" USING "btree" ("thread_id");

CREATE INDEX "idx_judgement_threads_judgement_id" ON "public"."judgement_threads" USING "btree" ("judgement_id");

CREATE INDEX "idx_judgement_threads_sender_id" ON "public"."judgement_threads" USING "btree" ("sender_id");

CREATE INDEX "idx_judgements_evidence_timeout_confirmed" ON "public"."judgements" USING "btree" ("is_evidence_timeout_confirmed") WHERE ("status" = 'evidence_timeout'::"text");

CREATE INDEX "idx_judgements_referee_id" ON "public"."judgements" USING "btree" ("referee_id");

CREATE INDEX "idx_judgements_task_id" ON "public"."judgements" USING "btree" ("task_id");

CREATE INDEX "idx_profiles_timezone" ON "public"."profiles" USING "btree" ("timezone");

CREATE INDEX "idx_rating_histories_task_id" ON "public"."rating_histories" USING "btree" ("task_id");

CREATE INDEX "idx_rating_histories_user_id" ON "public"."rating_histories" USING "btree" ("ratee_id");

CREATE INDEX "idx_rating_histories_user_type" ON "public"."rating_histories" USING "btree" ("ratee_id", "rating_type");

CREATE INDEX "idx_referee_available_time_slots_dow_time" ON "public"."referee_available_time_slots" USING "btree" ("dow", "start_min", "end_min") WHERE ("is_active" = true);

CREATE INDEX "idx_referee_available_time_slots_user_id" ON "public"."referee_available_time_slots" USING "btree" ("user_id");

CREATE INDEX "idx_task_evidence_assets_evidence_id" ON "public"."task_evidence_assets" USING "btree" ("evidence_id");

CREATE INDEX "idx_task_evidence_assets_processing_status" ON "public"."task_evidence_assets" USING "btree" ("processing_status");

CREATE INDEX "idx_task_evidence_assets_public_url" ON "public"."task_evidence_assets" USING "btree" ("public_url");

CREATE INDEX "idx_task_evidences_status" ON "public"."task_evidences" USING "btree" ("status");

CREATE INDEX "idx_task_evidences_task_id" ON "public"."task_evidences" USING "btree" ("task_id");

CREATE INDEX "idx_task_referee_requests_matched_referee_id" ON "public"."task_referee_requests" USING "btree" ("matched_referee_id");

CREATE INDEX "idx_task_referee_requests_matching_strategy" ON "public"."task_referee_requests" USING "btree" ("matching_strategy");

CREATE INDEX "idx_task_referee_requests_status" ON "public"."task_referee_requests" USING "btree" ("status");

CREATE INDEX "idx_task_referee_requests_task_id" ON "public"."task_referee_requests" USING "btree" ("task_id");

CREATE INDEX "idx_tasks_status" ON "public"."tasks" USING "btree" ("status");

CREATE INDEX "idx_tasks_status_tasker_id" ON "public"."tasks" USING "btree" ("status", "tasker_id");

CREATE INDEX "idx_tasks_tasker_id" ON "public"."tasks" USING "btree" ("tasker_id");
