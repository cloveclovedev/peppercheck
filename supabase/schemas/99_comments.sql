-- Additional comments
COMMENT ON COLUMN "public"."judgements"."reopen_count" IS 'Number of times this judgement has been reopened after rejection (max 1 allowed)';

COMMENT ON COLUMN "public"."judgements"."is_evidence_timeout_confirmed" IS 'Indicates whether the referee has confirmed the evidence timeout. Used to trigger task_referee_request closure by the system.';

COMMENT ON TABLE "public"."task_evidences" IS 'Task-level evidence records shared across all referees';

COMMENT ON COLUMN "public"."task_evidences"."status" IS 'Upload status: pending_upload, ready';

COMMENT ON COLUMN "public"."tasks"."criteria" IS 'Evaluation criteria for the task. NULL allowed for draft status.';

COMMENT ON COLUMN "public"."tasks"."due_date" IS 'Due date for task completion. NULL allowed for draft status.';

COMMENT ON COLUMN "public"."tasks"."fee_amount" IS 'Fee amount for the task. NULL allowed for draft status.';

COMMENT ON COLUMN "public"."tasks"."fee_currency" IS 'Currency for fee amount. NULL allowed for draft status, defaults to JPY when published.';

COMMENT ON COLUMN "public"."tasks"."status" IS 'Valid values: draft, open, judging, rejected, completed, closed, self_completed, expired. No constraints during MVP phase.';

COMMENT ON COLUMN "public"."profiles"."timezone" IS 'User timezone in IANA format (e.g., Asia/Tokyo, America/New_York, Europe/London)';

COMMENT ON COLUMN "public"."rating_histories"."ratee_id" IS 'ID of the user who received the rating (renamed from user_id)';

COMMENT ON COLUMN "public"."rating_histories"."rating" IS '0-5 rating scale: 0=system timeout, 1-5=user rating';

COMMENT ON COLUMN "public"."rating_histories"."rater_id" IS 'ID of the user who gave the rating (automatically set to auth.uid() on insert)';

COMMENT ON COLUMN "public"."rating_histories"."judgement_id" IS 'ID of the specific judgement this rating is for (when rating_type is referee)';

COMMENT ON TABLE "public"."referee_available_time_slots" IS 'Referee available time slots using minute-based time slots with UUID primary key. Overlap prevention handled client-side in MVP, future: int4range + EXCLUDE USING GIST';

COMMENT ON COLUMN "public"."referee_available_time_slots"."dow" IS 'Day of week: 0=Sunday, 6=Saturday';

COMMENT ON COLUMN "public"."referee_available_time_slots"."start_min" IS 'Start time in minutes from midnight (0-1439)';

COMMENT ON COLUMN "public"."referee_available_time_slots"."end_min" IS 'End time in minutes from midnight (1-1440, where 1440 = next day 00:00)';

COMMENT ON TABLE "public"."task_evidence_assets" IS 'File assets associated with task evidences';

COMMENT ON COLUMN "public"."task_evidence_assets"."content_type" IS 'MIME type of the uploaded file (e.g., image/jpeg, image/png)';

COMMENT ON COLUMN "public"."task_evidence_assets"."public_url" IS 'Public URL for accessing the file via file.peppercheck.com (MVP: same as file_url for direct upload)';

COMMENT ON COLUMN "public"."task_evidence_assets"."processing_status" IS 'Processing status for future image pipeline (MVP: always ready since direct upload, future: pending, ready, failed)';

COMMENT ON COLUMN "public"."task_evidence_assets"."error_message" IS 'Error message if processing failed (reserved for future image processing pipeline)';

COMMENT ON TABLE "public"."task_referee_requests" IS 'Manages referee matching requests for tasks, supporting multiple referees per task with different strategies';

COMMENT ON COLUMN "public"."task_referee_requests"."matching_strategy" IS 'Referee matching strategy: standard (basic auto-match), premium (advanced auto-match), direct (manual selection)';

COMMENT ON COLUMN "public"."task_referee_requests"."preferred_referee_id" IS 'Specific referee ID for direct assignment (required when matching_strategy = direct)';

COMMENT ON COLUMN "public"."task_referee_requests"."status" IS 'Request status: pending → matched → accepted/declined/expired';

COMMENT ON COLUMN "public"."task_referee_requests"."matched_referee_id" IS 'Referee assigned by matching algorithm';

COMMENT ON COLUMN "public"."task_referee_requests"."responded_at" IS 'Timestamp when referee accepted or declined the request';

COMMENT ON CONSTRAINT "task_referee_requests_status_check" ON "public"."task_referee_requests" IS 'Updated constraint to include closed status for confirmed judgements';

COMMENT ON CONSTRAINT "unique_rating_per_judgement" ON "public"."rating_histories" IS 'Ensures that each rater can only rate each ratee once per judgement. This constraint enables ON CONFLICT functionality in the auto_score_timeout_referee trigger and prevents duplicate ratings.';

