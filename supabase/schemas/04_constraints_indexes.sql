-- Constraints
ALTER TABLE ONLY "public"."judgement_thread_assets"
    ADD CONSTRAINT "judgement_thread_assets_pkey" PRIMARY KEY ("id");

ALTER TABLE ONLY "public"."judgement_threads"
    ADD CONSTRAINT "judgement_threads_pkey" PRIMARY KEY ("id");

ALTER TABLE ONLY "public"."judgements"
    ADD CONSTRAINT "judgements_pkey" PRIMARY KEY ("id");

ALTER TABLE ONLY "public"."profiles"
    ADD CONSTRAINT "profiles_pkey" PRIMARY KEY ("id");

ALTER TABLE ONLY "public"."profiles"
    ADD CONSTRAINT "profiles_username_key" UNIQUE ("username");

ALTER TABLE ONLY "public"."rating_histories"
    ADD CONSTRAINT "rating_history_pkey" PRIMARY KEY ("id");

ALTER TABLE ONLY "public"."referee_available_time_slots"
    ADD CONSTRAINT "referee_available_time_slots_pkey" PRIMARY KEY ("id");

ALTER TABLE ONLY "public"."referee_available_time_slots"
    ADD CONSTRAINT "referee_available_time_slots_user_id_dow_start_min_key" UNIQUE ("user_id", "dow", "start_min");

ALTER TABLE ONLY "public"."task_evidence_assets"
    ADD CONSTRAINT "task_evidence_assets_pkey" PRIMARY KEY ("id");

ALTER TABLE ONLY "public"."task_evidences"
    ADD CONSTRAINT "task_evidences_pkey" PRIMARY KEY ("id");

ALTER TABLE ONLY "public"."task_referee_requests"
    ADD CONSTRAINT "task_referee_requests_pkey" PRIMARY KEY ("id");

ALTER TABLE ONLY "public"."tasks"
    ADD CONSTRAINT "tasks_pkey" PRIMARY KEY ("id");


ALTER TABLE ONLY "public"."rating_histories"
    ADD CONSTRAINT "unique_rating_per_judgement" UNIQUE ("rater_id", "ratee_id", "judgement_id");


ALTER TABLE ONLY "public"."user_ratings"
    ADD CONSTRAINT "user_ratings_pkey" PRIMARY KEY ("user_id");


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
    ADD CONSTRAINT "stripe_accounts_pkey" PRIMARY KEY ("profile_id");

ALTER TABLE ONLY "public"."stripe_accounts"
    ADD CONSTRAINT "stripe_accounts_stripe_customer_id_key" UNIQUE ("stripe_customer_id");

ALTER TABLE ONLY "public"."stripe_accounts"
    ADD CONSTRAINT "stripe_accounts_stripe_connect_account_id_key" UNIQUE ("stripe_connect_account_id");

ALTER TABLE ONLY "public"."stripe_accounts"
    ADD CONSTRAINT "stripe_accounts_profile_id_fkey" FOREIGN KEY ("profile_id") REFERENCES "public"."profiles"("id") ON DELETE CASCADE;


ALTER TABLE ONLY "public"."user_ratings"
    ADD CONSTRAINT "user_ratings_user_id_fkey" FOREIGN KEY ("user_id") REFERENCES "public"."profiles"("id") ON DELETE CASCADE;

