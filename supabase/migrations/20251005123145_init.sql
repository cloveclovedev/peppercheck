create table "public"."judgement_thread_assets" (
    "id" uuid not null default gen_random_uuid(),
    "thread_id" uuid not null,
    "type" text not null,
    "file_url" text not null,
    "created_at" timestamp with time zone default now()
);


alter table "public"."judgement_thread_assets" enable row level security;

create table "public"."judgement_threads" (
    "id" uuid not null default gen_random_uuid(),
    "judgement_id" uuid not null,
    "sender_id" uuid not null,
    "message" text not null,
    "created_at" timestamp with time zone default now(),
    "updated_at" timestamp with time zone default now()
);


alter table "public"."judgement_threads" enable row level security;

create table "public"."judgements" (
    "id" uuid not null default gen_random_uuid(),
    "task_id" uuid not null,
    "referee_id" uuid not null,
    "comment" text,
    "status" text not null default 'open'::text,
    "created_at" timestamp with time zone default now(),
    "updated_at" timestamp with time zone default now(),
    "is_confirmed" boolean default false,
    "reopen_count" smallint not null default 0,
    "is_evidence_timeout_confirmed" boolean not null default false
);


alter table "public"."judgements" enable row level security;

create table "public"."profiles" (
    "id" uuid not null,
    "username" text,
    "avatar_url" text,
    "created_at" timestamp with time zone default now(),
    "stripe_connect_account_id" text,
    "updated_at" timestamp with time zone default now(),
    "timezone" text default 'UTC'::text
);


alter table "public"."profiles" enable row level security;

create table "public"."rating_histories" (
    "id" uuid not null default gen_random_uuid(),
    "ratee_id" uuid,
    "task_id" uuid,
    "rating_type" text not null,
    "rating" numeric not null,
    "comment" text,
    "created_at" timestamp with time zone default now(),
    "rater_id" uuid,
    "judgement_id" uuid
);


alter table "public"."rating_histories" enable row level security;

create table "public"."referee_available_time_slots" (
    "id" uuid not null default gen_random_uuid(),
    "user_id" uuid not null,
    "dow" smallint not null,
    "start_min" smallint not null,
    "end_min" smallint not null,
    "is_active" boolean default true,
    "created_at" timestamp with time zone not null default now(),
    "updated_at" timestamp with time zone not null default now()
);


alter table "public"."referee_available_time_slots" enable row level security;

create table "public"."task_evidence_assets" (
    "id" uuid not null default gen_random_uuid(),
    "evidence_id" uuid not null,
    "file_url" text not null,
    "file_size_bytes" bigint,
    "content_type" text,
    "created_at" timestamp with time zone default now(),
    "public_url" text,
    "processing_status" text default 'pending'::text,
    "error_message" text
);


alter table "public"."task_evidence_assets" enable row level security;

create table "public"."task_evidences" (
    "id" uuid not null default gen_random_uuid(),
    "task_id" uuid not null,
    "description" text not null,
    "status" text not null default 'pending_upload'::text,
    "created_at" timestamp with time zone default now(),
    "updated_at" timestamp with time zone default now()
);


alter table "public"."task_evidences" enable row level security;

create table "public"."task_referee_requests" (
    "id" uuid not null default gen_random_uuid(),
    "task_id" uuid not null,
    "matching_strategy" text not null,
    "preferred_referee_id" uuid,
    "status" text default 'pending'::text,
    "matched_referee_id" uuid,
    "responded_at" timestamp with time zone,
    "created_at" timestamp with time zone default now(),
    "updated_at" timestamp with time zone default now()
);


alter table "public"."task_referee_requests" enable row level security;

create table "public"."tasks" (
    "id" uuid not null default gen_random_uuid(),
    "tasker_id" uuid not null,
    "title" text not null,
    "description" text,
    "criteria" text,
    "due_date" timestamp with time zone,
    "fee_amount" numeric(36,18),
    "fee_currency" text,
    "status" text not null default 'draft'::text,
    "created_at" timestamp with time zone default now(),
    "updated_at" timestamp with time zone default now()
);


alter table "public"."tasks" enable row level security;

create table "public"."user_ratings" (
    "user_id" uuid not null,
    "tasker_rating" numeric default 0,
    "tasker_rating_count" integer default 0,
    "referee_rating" numeric default 0,
    "referee_rating_count" integer default 0,
    "created_at" timestamp with time zone default now(),
    "updated_at" timestamp with time zone default now()
);


alter table "public"."user_ratings" enable row level security;

CREATE INDEX idx_judgement_thread_assets_thread_id ON public.judgement_thread_assets USING btree (thread_id);

CREATE INDEX idx_judgement_threads_judgement_id ON public.judgement_threads USING btree (judgement_id);

CREATE INDEX idx_judgement_threads_sender_id ON public.judgement_threads USING btree (sender_id);

CREATE INDEX idx_judgements_evidence_timeout_confirmed ON public.judgements USING btree (is_evidence_timeout_confirmed) WHERE (status = 'evidence_timeout'::text);

CREATE INDEX idx_judgements_referee_id ON public.judgements USING btree (referee_id);

CREATE INDEX idx_judgements_task_id ON public.judgements USING btree (task_id);

CREATE INDEX idx_profiles_timezone ON public.profiles USING btree (timezone);

CREATE INDEX idx_rating_histories_task_id ON public.rating_histories USING btree (task_id);

CREATE INDEX idx_rating_histories_user_id ON public.rating_histories USING btree (ratee_id);

CREATE INDEX idx_rating_histories_user_type ON public.rating_histories USING btree (ratee_id, rating_type);

CREATE INDEX idx_referee_available_time_slots_dow_time ON public.referee_available_time_slots USING btree (dow, start_min, end_min) WHERE (is_active = true);

CREATE INDEX idx_referee_available_time_slots_user_id ON public.referee_available_time_slots USING btree (user_id);

CREATE INDEX idx_task_evidence_assets_evidence_id ON public.task_evidence_assets USING btree (evidence_id);

CREATE INDEX idx_task_evidence_assets_processing_status ON public.task_evidence_assets USING btree (processing_status);

CREATE INDEX idx_task_evidence_assets_public_url ON public.task_evidence_assets USING btree (public_url);

CREATE INDEX idx_task_evidences_status ON public.task_evidences USING btree (status);

CREATE INDEX idx_task_evidences_task_id ON public.task_evidences USING btree (task_id);

CREATE INDEX idx_task_referee_requests_matched_referee_id ON public.task_referee_requests USING btree (matched_referee_id);

CREATE INDEX idx_task_referee_requests_matching_strategy ON public.task_referee_requests USING btree (matching_strategy);

CREATE INDEX idx_task_referee_requests_status ON public.task_referee_requests USING btree (status);

CREATE INDEX idx_task_referee_requests_task_id ON public.task_referee_requests USING btree (task_id);

CREATE INDEX idx_tasks_status ON public.tasks USING btree (status);

CREATE INDEX idx_tasks_status_tasker_id ON public.tasks USING btree (status, tasker_id);

CREATE INDEX idx_tasks_tasker_id ON public.tasks USING btree (tasker_id);

CREATE UNIQUE INDEX judgement_thread_assets_pkey ON public.judgement_thread_assets USING btree (id);

CREATE UNIQUE INDEX judgement_threads_pkey ON public.judgement_threads USING btree (id);

CREATE UNIQUE INDEX judgements_pkey ON public.judgements USING btree (id);

CREATE UNIQUE INDEX profiles_pkey ON public.profiles USING btree (id);

CREATE UNIQUE INDEX profiles_username_key ON public.profiles USING btree (username);

CREATE UNIQUE INDEX rating_history_pkey ON public.rating_histories USING btree (id);

CREATE UNIQUE INDEX referee_available_time_slots_pkey ON public.referee_available_time_slots USING btree (id);

CREATE UNIQUE INDEX referee_available_time_slots_user_id_dow_start_min_key ON public.referee_available_time_slots USING btree (user_id, dow, start_min);

CREATE UNIQUE INDEX task_evidence_assets_pkey ON public.task_evidence_assets USING btree (id);

CREATE UNIQUE INDEX task_evidences_pkey ON public.task_evidences USING btree (id);

CREATE UNIQUE INDEX task_referee_requests_pkey ON public.task_referee_requests USING btree (id);

CREATE UNIQUE INDEX tasks_pkey ON public.tasks USING btree (id);

CREATE UNIQUE INDEX unique_rating_per_judgement ON public.rating_histories USING btree (rater_id, ratee_id, judgement_id);

CREATE UNIQUE INDEX user_ratings_pkey ON public.user_ratings USING btree (user_id);

alter table "public"."judgement_thread_assets" add constraint "judgement_thread_assets_pkey" PRIMARY KEY using index "judgement_thread_assets_pkey";

alter table "public"."judgement_threads" add constraint "judgement_threads_pkey" PRIMARY KEY using index "judgement_threads_pkey";

alter table "public"."judgements" add constraint "judgements_pkey" PRIMARY KEY using index "judgements_pkey";

alter table "public"."profiles" add constraint "profiles_pkey" PRIMARY KEY using index "profiles_pkey";

alter table "public"."rating_histories" add constraint "rating_history_pkey" PRIMARY KEY using index "rating_history_pkey";

alter table "public"."referee_available_time_slots" add constraint "referee_available_time_slots_pkey" PRIMARY KEY using index "referee_available_time_slots_pkey";

alter table "public"."task_evidence_assets" add constraint "task_evidence_assets_pkey" PRIMARY KEY using index "task_evidence_assets_pkey";

alter table "public"."task_evidences" add constraint "task_evidences_pkey" PRIMARY KEY using index "task_evidences_pkey";

alter table "public"."task_referee_requests" add constraint "task_referee_requests_pkey" PRIMARY KEY using index "task_referee_requests_pkey";

alter table "public"."tasks" add constraint "tasks_pkey" PRIMARY KEY using index "tasks_pkey";

alter table "public"."user_ratings" add constraint "user_ratings_pkey" PRIMARY KEY using index "user_ratings_pkey";

alter table "public"."judgement_thread_assets" add constraint "judgement_thread_assets_thread_id_fkey" FOREIGN KEY (thread_id) REFERENCES judgement_threads(id) ON DELETE CASCADE not valid;

alter table "public"."judgement_thread_assets" validate constraint "judgement_thread_assets_thread_id_fkey";

alter table "public"."judgement_threads" add constraint "judgement_threads_judgement_id_fkey" FOREIGN KEY (judgement_id) REFERENCES judgements(id) ON DELETE CASCADE not valid;

alter table "public"."judgement_threads" validate constraint "judgement_threads_judgement_id_fkey";

alter table "public"."judgement_threads" add constraint "judgement_threads_sender_id_fkey" FOREIGN KEY (sender_id) REFERENCES profiles(id) ON DELETE SET NULL not valid;

alter table "public"."judgement_threads" validate constraint "judgement_threads_sender_id_fkey";

alter table "public"."judgements" add constraint "judgements_referee_id_fkey" FOREIGN KEY (referee_id) REFERENCES profiles(id) ON DELETE SET NULL not valid;

alter table "public"."judgements" validate constraint "judgements_referee_id_fkey";

alter table "public"."judgements" add constraint "judgements_task_id_fkey" FOREIGN KEY (task_id) REFERENCES tasks(id) ON DELETE CASCADE not valid;

alter table "public"."judgements" validate constraint "judgements_task_id_fkey";

alter table "public"."profiles" add constraint "profiles_id_fkey" FOREIGN KEY (id) REFERENCES auth.users(id) not valid;

alter table "public"."profiles" validate constraint "profiles_id_fkey";

alter table "public"."profiles" add constraint "profiles_username_key" UNIQUE using index "profiles_username_key";

alter table "public"."rating_histories" add constraint "fk_rating_histories_judgement_id" FOREIGN KEY (judgement_id) REFERENCES judgements(id) not valid;

alter table "public"."rating_histories" validate constraint "fk_rating_histories_judgement_id";

alter table "public"."rating_histories" add constraint "fk_rating_histories_rater_id" FOREIGN KEY (rater_id) REFERENCES profiles(id) not valid;

alter table "public"."rating_histories" validate constraint "fk_rating_histories_rater_id";

alter table "public"."rating_histories" add constraint "rating_histories_rating_check" CHECK (((rating >= (0)::numeric) AND (rating <= (5)::numeric))) not valid;

alter table "public"."rating_histories" validate constraint "rating_histories_rating_check";

alter table "public"."rating_histories" add constraint "rating_histories_rating_type_check" CHECK ((rating_type = ANY (ARRAY['tasker'::text, 'referee'::text]))) not valid;

alter table "public"."rating_histories" validate constraint "rating_histories_rating_type_check";

alter table "public"."rating_histories" add constraint "rating_histories_task_id_fkey" FOREIGN KEY (task_id) REFERENCES tasks(id) ON DELETE SET NULL not valid;

alter table "public"."rating_histories" validate constraint "rating_histories_task_id_fkey";

alter table "public"."rating_histories" add constraint "rating_histories_user_id_fkey" FOREIGN KEY (ratee_id) REFERENCES profiles(id) ON DELETE SET NULL not valid;

alter table "public"."rating_histories" validate constraint "rating_histories_user_id_fkey";

alter table "public"."rating_histories" add constraint "unique_rating_per_judgement" UNIQUE using index "unique_rating_per_judgement";

alter table "public"."referee_available_time_slots" add constraint "referee_available_time_slots_dow_check" CHECK (((dow >= 0) AND (dow <= 6))) not valid;

alter table "public"."referee_available_time_slots" validate constraint "referee_available_time_slots_dow_check";

alter table "public"."referee_available_time_slots" add constraint "referee_available_time_slots_end_min_check" CHECK (((end_min >= 1) AND (end_min <= 1440))) not valid;

alter table "public"."referee_available_time_slots" validate constraint "referee_available_time_slots_end_min_check";

alter table "public"."referee_available_time_slots" add constraint "referee_available_time_slots_start_min_check" CHECK (((start_min >= 0) AND (start_min <= 1439))) not valid;

alter table "public"."referee_available_time_slots" validate constraint "referee_available_time_slots_start_min_check";

alter table "public"."referee_available_time_slots" add constraint "referee_available_time_slots_user_id_dow_start_min_key" UNIQUE using index "referee_available_time_slots_user_id_dow_start_min_key";

alter table "public"."referee_available_time_slots" add constraint "referee_available_time_slots_user_id_fkey" FOREIGN KEY (user_id) REFERENCES profiles(id) ON DELETE CASCADE not valid;

alter table "public"."referee_available_time_slots" validate constraint "referee_available_time_slots_user_id_fkey";

alter table "public"."referee_available_time_slots" add constraint "valid_time_range" CHECK ((start_min < end_min)) not valid;

alter table "public"."referee_available_time_slots" validate constraint "valid_time_range";

alter table "public"."task_evidence_assets" add constraint "task_evidence_assets_evidence_id_fkey" FOREIGN KEY (evidence_id) REFERENCES task_evidences(id) ON DELETE CASCADE not valid;

alter table "public"."task_evidence_assets" validate constraint "task_evidence_assets_evidence_id_fkey";

alter table "public"."task_evidences" add constraint "task_evidences_status_check" CHECK ((status = ANY (ARRAY['pending_upload'::text, 'ready'::text]))) not valid;

alter table "public"."task_evidences" validate constraint "task_evidences_status_check";

alter table "public"."task_evidences" add constraint "task_evidences_task_id_fkey" FOREIGN KEY (task_id) REFERENCES tasks(id) ON DELETE CASCADE not valid;

alter table "public"."task_evidences" validate constraint "task_evidences_task_id_fkey";

alter table "public"."task_referee_requests" add constraint "task_referee_requests_matched_referee_id_fkey" FOREIGN KEY (matched_referee_id) REFERENCES profiles(id) not valid;

alter table "public"."task_referee_requests" validate constraint "task_referee_requests_matched_referee_id_fkey";

alter table "public"."task_referee_requests" add constraint "task_referee_requests_matching_strategy_check" CHECK ((matching_strategy = ANY (ARRAY['standard'::text, 'premium'::text, 'direct'::text]))) not valid;

alter table "public"."task_referee_requests" validate constraint "task_referee_requests_matching_strategy_check";

alter table "public"."task_referee_requests" add constraint "task_referee_requests_preferred_referee_id_fkey" FOREIGN KEY (preferred_referee_id) REFERENCES profiles(id) not valid;

alter table "public"."task_referee_requests" validate constraint "task_referee_requests_preferred_referee_id_fkey";

alter table "public"."task_referee_requests" add constraint "task_referee_requests_status_check" CHECK ((status = ANY (ARRAY['pending'::text, 'matched'::text, 'accepted'::text, 'declined'::text, 'expired'::text, 'closed'::text]))) not valid;

alter table "public"."task_referee_requests" validate constraint "task_referee_requests_status_check";

alter table "public"."task_referee_requests" add constraint "task_referee_requests_task_id_fkey" FOREIGN KEY (task_id) REFERENCES tasks(id) ON DELETE CASCADE not valid;

alter table "public"."task_referee_requests" validate constraint "task_referee_requests_task_id_fkey";

alter table "public"."tasks" add constraint "tasks_tasker_id_fkey" FOREIGN KEY (tasker_id) REFERENCES profiles(id) ON DELETE SET NULL not valid;

alter table "public"."tasks" validate constraint "tasks_tasker_id_fkey";

alter table "public"."user_ratings" add constraint "user_ratings_user_id_fkey" FOREIGN KEY (user_id) REFERENCES profiles(id) ON DELETE CASCADE not valid;

alter table "public"."user_ratings" validate constraint "user_ratings_user_id_fkey";

set check_function_bodies = off;

CREATE OR REPLACE FUNCTION public.auto_score_timeout_referee()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
DECLARE
    v_judgement RECORD;
    v_task RECORD;
BEGIN
    -- Only process when is_confirmed changes from false to true
    IF TG_OP = 'UPDATE' AND OLD.is_confirmed = false AND NEW.is_confirmed = true THEN
        
        -- Get the judgement details with task info
        SELECT 
            j.id,
            j.task_id,
            j.referee_id,
            j.status,
            t.tasker_id
        INTO v_judgement
        FROM public.judgements j
        INNER JOIN public.tasks t ON j.task_id = t.id
        WHERE j.id = NEW.id;

        -- If this is a judgement_timeout confirmation, automatically score referee as 0
        IF v_judgement.status = 'judgement_timeout' THEN
            -- Insert rating from tasker to referee (0 points for timeout)
            -- The existing trigger_update_user_ratings will automatically update user_ratings table
            INSERT INTO public.rating_histories (
                rater_id,        -- tasker who confirms timeout (evaluator)
                ratee_id,        -- referee who timed out (being evaluated)
                judgement_id,    -- specific judgement being rated
                task_id,         -- task reference
                rating_type,     -- 'referee' - evaluating referee performance
                rating,          -- 0 points for timeout penalty
                comment,         -- explanation for automatic rating
                created_at       -- timestamp
            ) VALUES (
                v_judgement.tasker_id,  -- tasker rates the referee
                v_judgement.referee_id, -- referee gets rated
                v_judgement.id,         -- specific judgement
                v_judgement.task_id,    -- task reference
                'referee',              -- rating type: referee being rated
                0,                      -- 0 points for timeout
                'Automatic 0-point rating due to referee timeout', -- explanation
                NOW()                   -- timestamp
            ) ON CONFLICT (rater_id, ratee_id, judgement_id) DO NOTHING; -- Prevent duplicate ratings

            -- Note: user_ratings table will be automatically updated by the existing 
            -- trigger_update_user_ratings trigger after this rating_histories INSERT
            
            RAISE NOTICE 'Auto-scored referee % with 0 points for timeout on judgement %', 
                v_judgement.referee_id, v_judgement.id;
        END IF;
    END IF;

    RETURN NEW;
END;
$function$
;

CREATE OR REPLACE FUNCTION public.close_task_if_all_judgements_confirmed()
 RETURNS trigger
 LANGUAGE plpgsql
 SET search_path TO ''
AS $function$
BEGIN
  -- Concurrency protection: lock the task row to prevent race conditions
  PERFORM * FROM public.tasks WHERE id = NEW.task_id FOR UPDATE;
  
  -- Check if all judgements for this task are confirmed
  IF NOT EXISTS (
    SELECT 1 FROM public.judgements 
    WHERE task_id = NEW.task_id AND is_confirmed = FALSE
  ) THEN
    UPDATE public.tasks SET status = 'closed' WHERE id = NEW.task_id;
  END IF;
  
  RETURN NEW;
END;
$function$
;

CREATE OR REPLACE FUNCTION public.confirm_evidence_timeout_from_referee(p_judgement_id uuid)
 RETURNS json
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
DECLARE
    v_judgement_record public.judgements%ROWTYPE;
    v_now TIMESTAMP WITH TIME ZONE;
BEGIN
    v_now := NOW();
    
    -- Get judgement details and verify it exists and is in evidence_timeout status
    SELECT * INTO v_judgement_record
    FROM public.judgements 
    WHERE id = p_judgement_id;
    
    IF NOT FOUND THEN
        RAISE EXCEPTION 'Judgement not found';
    END IF;
    
    IF v_judgement_record.status != 'evidence_timeout' THEN
        RAISE EXCEPTION 'Judgement is not in evidence_timeout status';
    END IF;
    
    IF v_judgement_record.is_evidence_timeout_confirmed = true THEN
        RAISE EXCEPTION 'Evidence timeout already confirmed';
    END IF;
    
    -- Update judgement to mark evidence timeout as confirmed
    UPDATE public.judgements 
    SET 
        is_evidence_timeout_confirmed = true,
        updated_at = v_now
    WHERE id = p_judgement_id;
    
    RETURN json_build_object(
        'success', true,
        'judgement_id', p_judgement_id,
        'confirmed_at', v_now
    );

END;
$function$
;

CREATE OR REPLACE FUNCTION public.confirm_judgement_and_rate_referee(p_task_id uuid, p_judgement_id uuid, p_ratee_id uuid, p_rating integer, p_comment text)
 RETURNS void
 LANGUAGE plpgsql
 SET search_path TO ''
AS $function$
DECLARE
  v_is_confirmed boolean;
  v_rows_affected integer;
BEGIN
  -- Idempotency check: if already confirmed, do nothing
  SELECT is_confirmed INTO v_is_confirmed 
  FROM public.judgements WHERE id = p_judgement_id;
  
  IF v_is_confirmed = TRUE THEN
    RETURN;
  END IF;

  -- Atomic operation: Rating insertion + Judgement confirmation
  INSERT INTO public.rating_histories (task_id, judgement_id, ratee_id, rating_type, rating, comment)
  VALUES (p_task_id, p_judgement_id, p_ratee_id, 'referee', p_rating, p_comment);
  
  UPDATE public.judgements SET is_confirmed = TRUE WHERE id = p_judgement_id;
  
  -- Check if the UPDATE actually affected any rows
  GET DIAGNOSTICS v_rows_affected = ROW_COUNT;
  
  IF v_rows_affected = 0 THEN
    RAISE EXCEPTION 'Failed to update judgement confirmation status. No rows affected. This may be due to permission restrictions.';
  END IF;

  -- NOTE: task_referee_requests status update is now handled automatically by trigger
  -- No manual update needed here
    
END;
$function$
;

CREATE OR REPLACE FUNCTION public.detect_and_handle_evidence_timeouts()
 RETURNS json
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
DECLARE
    v_timeout_count INTEGER := 0;
    v_now TIMESTAMP WITH TIME ZONE;
BEGIN
    v_now := NOW();
    
    -- Update judgements that have evidence timeout (due_date passed without evidence)
    -- Only update judgements that are still 'open' and past the due date with no evidence
    UPDATE public.judgements 
    SET 
        status = 'evidence_timeout',
        updated_at = v_now
    FROM public.tasks t
    LEFT JOIN public.task_evidences te ON t.id = te.task_id
    WHERE public.judgements.task_id = t.id
    AND public.judgements.status = 'open'
    AND v_now > t.due_date
    AND te.id IS NULL; -- No evidence submitted

    GET DIAGNOSTICS v_timeout_count = ROW_COUNT;

    RETURN json_build_object(
        'success', true,
        'timeout_count', v_timeout_count,
        'processed_at', v_now
    );

EXCEPTION
    WHEN OTHERS THEN
        RETURN json_build_object(
            'success', false,
            'error', SQLERRM,
            'processed_at', v_now
        );
END;
$function$
;

CREATE OR REPLACE FUNCTION public.detect_and_handle_referee_timeouts()
 RETURNS json
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
DECLARE
    v_timeout_count INTEGER := 0;
    v_updated_judgements RECORD;
    v_now TIMESTAMP WITH TIME ZONE;
    v_timeout_threshold TIMESTAMP WITH TIME ZONE;
BEGIN
    v_now := NOW();
    
    -- Update judgements that have timed out (due_date + 3 hours)
    -- Only update judgements that are still 'open' and past the timeout threshold
    UPDATE public.judgements 
    SET 
        status = 'judgement_timeout',
        updated_at = v_now
    FROM public.tasks t
    WHERE public.judgements.task_id = t.id
    AND public.judgements.status = 'open'
    AND v_now > (t.due_date + INTERVAL '3 hours');

    GET DIAGNOSTICS v_timeout_count = ROW_COUNT;

    RETURN json_build_object(
        'success', true,
        'timeout_count', v_timeout_count,
        'processed_at', v_now
    );

EXCEPTION
    WHEN OTHERS THEN
        RETURN json_build_object(
            'success', false,
            'error', SQLERRM,
            'processed_at', v_now
        );
END;
$function$
;

CREATE OR REPLACE FUNCTION public.get_active_referee_tasks()
 RETURNS jsonb
 LANGUAGE sql
 SET search_path TO ''
AS $function$
  SELECT COALESCE(
    jsonb_agg(
      jsonb_build_object(
        'task', to_jsonb(t), -- Single task object
        'judgement', to_jsonb(j), -- judgement information with can_reopen
        'tasker_profile', to_jsonb(p) -- Full tasker profile
      )
    ),
    '[]'::jsonb
  )
  FROM
    public.task_referee_requests AS trr
  INNER JOIN
    public.tasks AS t ON trr.task_id = t.id
  LEFT JOIN
    public.judgements_ext AS j ON t.id = j.task_id AND trr.matched_referee_id = j.referee_id -- Changed to judgements_ext
  INNER JOIN
    public.profiles AS p ON t.tasker_id = p.id
  WHERE
    trr.matched_referee_id = auth.uid()
    AND trr.status IN ('matched', 'accepted');
$function$
;

CREATE OR REPLACE FUNCTION public.handle_evidence_timeout_confirmation()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
DECLARE
    v_task_id UUID;
    v_referee_id UUID;
    v_request_count INTEGER := 0;
    v_now TIMESTAMP WITH TIME ZONE;
BEGIN
    v_now := NOW();
    
    -- Only proceed if is_evidence_timeout_confirmed was changed from false to true
    -- and the judgement status is evidence_timeout
    IF NEW.is_evidence_timeout_confirmed = true 
       AND OLD.is_evidence_timeout_confirmed = false 
       AND NEW.status = 'evidence_timeout' THEN
        
        -- Get the task_id and referee_id from the judgement
        v_task_id := NEW.task_id;
        v_referee_id := NEW.referee_id;
        
        -- Close the specific task_referee_request for this task and referee
        UPDATE public.task_referee_requests 
        SET 
            status = 'closed',
            updated_at = v_now
        WHERE task_id = v_task_id 
        AND matched_referee_id = v_referee_id
        AND status = 'accepted';
        
        GET DIAGNOSTICS v_request_count = ROW_COUNT;
        
        RAISE NOTICE 'Evidence timeout confirmed: closed % task_referee_request(s) for task % referee %', 
            v_request_count, v_task_id, v_referee_id;
        
    END IF;
    
    RETURN NEW;
    
EXCEPTION
    WHEN OTHERS THEN
        -- Log error but don't fail the original update
        RAISE WARNING 'Error in handle_evidence_timeout_confirmation: %', SQLERRM;
        -- Return NEW to allow the original judgement update to succeed
        RETURN NEW;
END;
$function$
;

CREATE OR REPLACE FUNCTION public.handle_judgement_confirmation()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
BEGIN
  -- Only execute when is_confirmed changes from FALSE to TRUE
  IF NEW.is_confirmed = TRUE AND (OLD.is_confirmed IS NULL OR OLD.is_confirmed = FALSE) THEN
    
    -- Close the corresponding task_referee_request
    UPDATE public.task_referee_requests
    SET status = 'closed'
    WHERE task_id = NEW.task_id 
      AND matched_referee_id = NEW.referee_id
      AND status IN ('matched', 'accepted');
      
  END IF;

  RETURN NEW;
END;
$function$
;

CREATE OR REPLACE FUNCTION public.handle_new_user()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
BEGIN
  INSERT INTO public.profiles (id)
  VALUES (NEW.id);

  INSERT INTO public.user_ratings (user_id)
  VALUES (NEW.id);

  RETURN NEW;
END;
$function$
;

CREATE OR REPLACE FUNCTION public.handle_updated_at()
 RETURNS trigger
 LANGUAGE plpgsql
 SET search_path TO ''
AS $function$
BEGIN
  NEW.updated_at = NOW();
  RETURN NEW;
END;
$function$
;

CREATE OR REPLACE FUNCTION public.is_task_referee(task_uuid uuid, user_uuid uuid)
 RETURNS boolean
 LANGUAGE sql
 STABLE STRICT SECURITY DEFINER
 SET row_security TO 'off'
 SET search_path TO ''
AS $function$
  SELECT EXISTS (
    SELECT 1
      FROM public.judgements
     WHERE task_id   = task_uuid
       AND referee_id = user_uuid
  );
$function$
;

CREATE OR REPLACE FUNCTION public.is_task_referee_candidate(task_uuid uuid, user_uuid uuid)
 RETURNS boolean
 LANGUAGE sql
 STABLE STRICT SECURITY DEFINER
 SET row_security TO 'off'
 SET search_path TO ''
AS $function$
  SELECT EXISTS (
    SELECT 1
      FROM public.task_referee_requests
     WHERE task_id = task_uuid
       AND matched_referee_id = user_uuid
       AND status = 'matched'
  );
$function$
;

CREATE OR REPLACE FUNCTION public.is_task_tasker(task_uuid uuid, user_uuid uuid)
 RETURNS boolean
 LANGUAGE sql
 STABLE STRICT SECURITY DEFINER
 SET row_security TO 'off'
 SET search_path TO ''
AS $function$
  SELECT tasker_id = user_uuid
    FROM public.tasks
   WHERE id = task_uuid;
$function$
;

create or replace view "public"."judgements_ext" as  SELECT j.id,
    j.task_id,
    j.referee_id,
    j.comment,
    j.status,
    j.created_at,
    j.updated_at,
    j.is_confirmed,
    j.reopen_count,
    j.is_evidence_timeout_confirmed,
    ((j.status = 'rejected'::text) AND (j.reopen_count < 1) AND (t.due_date > now()) AND (EXISTS ( SELECT 1
           FROM task_evidences te
          WHERE ((te.task_id = j.task_id) AND (te.updated_at > j.updated_at))))) AS can_reopen
   FROM (judgements j
     JOIN tasks t ON ((j.task_id = t.id)));


CREATE OR REPLACE FUNCTION public.process_matching(p_request_id uuid)
 RETURNS json
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
DECLARE
    v_request RECORD;
    v_task RECORD;
    v_matched_referee_id UUID;
    v_due_date TIMESTAMP WITH TIME ZONE;
    v_available_referees UUID[];
    v_min_workload INTEGER;
    v_least_busy_referees UUID[];
    v_selected_referee UUID;
    v_debug_info JSONB;
BEGIN
    v_debug_info := jsonb_build_object();

    -- Get request details
    SELECT
        trr.id,
        trr.task_id,
        trr.matching_strategy,
        trr.preferred_referee_id,
        trr.status
    INTO v_request
    FROM public.task_referee_requests trr
    WHERE trr.id = p_request_id;

    v_debug_info := v_debug_info || jsonb_build_object('request', row_to_json(v_request));

    IF NOT FOUND THEN
        RETURN json_build_object(
            'success', false,
            'error', 'Request not found',
            'request_id', p_request_id,
            'debug', v_debug_info
        );
    END IF;

    -- Skip if already processed
    IF v_request.status != 'pending' THEN
        RETURN json_build_object(
            'success', true,
            'message', 'Request already processed',
            'status', v_request.status,
            'request_id', p_request_id,
            'debug', v_debug_info
        );
    END IF;

    -- Get task details
    SELECT t.id, t.due_date, t.tasker_id, t.status
    INTO v_task
    FROM public.tasks t
    WHERE t.id = v_request.task_id;

    v_debug_info := v_debug_info || jsonb_build_object('task', row_to_json(v_task));

    IF NOT FOUND OR v_task.status NOT IN ('open', 'judging') THEN
        RETURN json_build_object(
            'success', false,
            'error', 'Task not found or not available for matching',
            'request_id', p_request_id,
            'debug', v_debug_info
        );
    END IF;

    v_due_date := v_task.due_date;

    -- Process matching based on strategy
    CASE v_request.matching_strategy
        WHEN 'standard' THEN
            SELECT ARRAY_AGG(DISTINCT referee_id) INTO v_available_referees
            FROM (
                SELECT
                    rats.user_id as referee_id
                FROM public.referee_available_time_slots rats
                INNER JOIN public.profiles p ON rats.user_id = p.id
                WHERE rats.is_active = true
                AND rats.user_id != v_task.tasker_id
                AND EXTRACT(DOW FROM (v_due_date AT TIME ZONE COALESCE(p.timezone, 'UTC'))) = rats.dow
                AND (EXTRACT(HOUR FROM (v_due_date AT TIME ZONE COALESCE(p.timezone, 'UTC'))) * 60 +
                     EXTRACT(MINUTE FROM (v_due_date AT TIME ZONE COALESCE(p.timezone, 'UTC')))) >= rats.start_min
                AND (EXTRACT(HOUR FROM (v_due_date AT TIME ZONE COALESCE(p.timezone, 'UTC'))) * 60 +
                     EXTRACT(MINUTE FROM (v_due_date AT TIME ZONE COALESCE(p.timezone, 'UTC')))) <= rats.end_min
            ) available_refs;

            v_debug_info := v_debug_info || jsonb_build_object(
                'available_referees', v_available_referees,
                'available_referees_count', COALESCE(array_length(v_available_referees, 1), 0)
            );

            IF COALESCE(array_length(v_available_referees, 1), 0) = 0 THEN
                v_matched_referee_id := NULL;
            ELSE
                SELECT MIN(workload_count) INTO v_min_workload
                FROM (
                    SELECT
                        COALESCE(COUNT(j.id), 0) as workload_count
                    FROM (SELECT unnest(v_available_referees) as referee_id) refs
                    LEFT JOIN public.judgements j ON j.referee_id = refs.referee_id
                        AND j.status IN ('open', 'rejected', 'self_closed')
                    GROUP BY refs.referee_id
                ) workloads;

                v_debug_info := v_debug_info || jsonb_build_object('min_workload', v_min_workload);

                SELECT array_agg(referee_id) INTO v_least_busy_referees
                FROM (
                    SELECT
                        refs.referee_id,
                        COALESCE(COUNT(j.id), 0) as workload_count
                    FROM (SELECT unnest(v_available_referees) as referee_id) refs
                    LEFT JOIN public.judgements j ON j.referee_id = refs.referee_id
                        AND j.status IN ('open', 'rejected', 'self_closed')
                    GROUP BY refs.referee_id
                    HAVING COALESCE(COUNT(j.id), 0) = v_min_workload
                ) least_busy;

                v_debug_info := v_debug_info || jsonb_build_object(
                    'least_busy_referees', v_least_busy_referees,
                    'least_busy_referees_count', COALESCE(array_length(v_least_busy_referees, 1), 0)
                );

                IF COALESCE(array_length(v_least_busy_referees, 1), 0) > 0 THEN
                    v_selected_referee := v_least_busy_referees[1 + floor(random() * array_length(v_least_busy_referees, 1))::INTEGER];
                    v_matched_referee_id := v_selected_referee;
                    v_debug_info := v_debug_info || jsonb_build_object('selected_referee', v_selected_referee);
                ELSE
                    v_matched_referee_id := NULL;
                END IF;
            END IF;

        WHEN 'premium' THEN
            v_matched_referee_id := NULL;

        WHEN 'direct' THEN
            IF v_request.preferred_referee_id IS NOT NULL THEN
                v_matched_referee_id := v_request.preferred_referee_id;
            ELSE
                v_matched_referee_id := NULL;
            END IF;

        ELSE
            RETURN json_build_object(
                'success', false,
                'error', 'Unknown matching strategy',
                'request_id', p_request_id,
                'strategy', v_request.matching_strategy,
                'debug', v_debug_info
            );
    END CASE;

    IF v_matched_referee_id IS NOT NULL THEN
        UPDATE public.task_referee_requests
        SET
            status = 'accepted',
            matched_referee_id = v_matched_referee_id,
            responded_at = NOW()
        WHERE id = p_request_id;

        INSERT INTO public.judgements (task_id, referee_id, status)
        VALUES (v_request.task_id, v_matched_referee_id, 'open');

        RETURN json_build_object(
            'success', true,
            'matched', true,
            'referee_id', v_matched_referee_id,
            'request_id', p_request_id,
            'debug', v_debug_info
        );
    ELSE
        RETURN json_build_object(
            'success', true,
            'matched', false,
            'message', 'No suitable referee found',
            'request_id', p_request_id,
            'debug', v_debug_info
        );
    END IF;

EXCEPTION
    WHEN OTHERS THEN
        RETURN json_build_object(
            'success', false,
            'error', SQLERRM,
            'request_id', p_request_id,
            'debug', v_debug_info
        );
END;
$function$
;

CREATE OR REPLACE FUNCTION public.reopen_judgement(p_judgement_id uuid)
 RETURNS void
 LANGUAGE plpgsql
 SET search_path TO ''
AS $function$
DECLARE
  v_task_id uuid;
  v_can_reopen boolean;
BEGIN
  -- Get judgement details and can_reopen status from the view
  SELECT task_id, can_reopen
  INTO v_task_id, v_can_reopen
  FROM public.judgements_ext
  WHERE id = p_judgement_id;

  -- Check if judgement exists
  IF NOT FOUND THEN
    RAISE EXCEPTION 'Judgement not found';
  END IF;

  -- Security check: Only tasker can reopen their judgement
  IF NOT public.is_task_tasker(v_task_id, (SELECT auth.uid())) THEN
    RAISE EXCEPTION 'Only the task owner can request judgement reopening';
  END IF;

  -- Validation: Use the can_reopen logic from judgements_ext view
  IF NOT v_can_reopen THEN
    RAISE EXCEPTION 'Judgement cannot be reopened. Check: status must be rejected, reopen count < 1, task not past due date, and evidence updated after judgement.';
  END IF;

  -- All validations passed - reopen the judgement
  UPDATE public.judgements 
  SET 
    status = 'open',
    reopen_count = reopen_count + 1
  WHERE id = p_judgement_id;

END;
$function$
;

CREATE OR REPLACE FUNCTION public.set_rater_id()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
BEGIN
  -- Only set rater_id if it's not already provided
  IF NEW.rater_id IS NULL THEN
    NEW.rater_id := (select auth.uid());
  END IF;
  RETURN NEW;
END;
$function$
;

CREATE OR REPLACE FUNCTION public.trigger_process_matching()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
DECLARE
    v_result JSON;
BEGIN
    -- Only process on INSERT or UPDATE to pending status
    IF (TG_OP = 'INSERT' AND NEW.status = 'pending') OR 
       (TG_OP = 'UPDATE' AND NEW.status = 'pending' AND OLD.status != 'pending') THEN
        
        -- Process the specific request directly
        SELECT public.process_matching(NEW.id) INTO v_result;
        
        -- Log result if needed (optional)
        -- Could add logging here if required for debugging
    END IF;
    
    RETURN NEW;
END;
$function$
;

CREATE OR REPLACE FUNCTION public.update_user_ratings()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
DECLARE
    affected_user_id uuid;
BEGIN
    IF TG_OP = 'DELETE' THEN
        affected_user_id := OLD.ratee_id;
    ELSE
        affected_user_id := NEW.ratee_id;
    END IF;

    -- Recalculate tasker_rating and tasker_rating_count
    UPDATE public.user_ratings
    SET
        tasker_rating = COALESCE((SELECT AVG(rating)::numeric FROM public.rating_histories WHERE ratee_id = affected_user_id AND rating_type = 'tasker'), 0),
        tasker_rating_count = (SELECT COUNT(*)::integer FROM public.rating_histories WHERE ratee_id = affected_user_id AND rating_type = 'tasker'),
        updated_at = NOW()
    WHERE user_id = affected_user_id;

    -- Recalculate referee_rating and referee_rating_count
    UPDATE public.user_ratings
    SET
        referee_rating = COALESCE((SELECT AVG(rating)::numeric FROM public.rating_histories WHERE ratee_id = affected_user_id AND rating_type = 'referee'), 0),
        referee_rating_count = (SELECT COUNT(*)::integer FROM public.rating_histories WHERE ratee_id = affected_user_id AND rating_type = 'referee'),
        updated_at = NOW()
    WHERE user_id = affected_user_id;

    IF TG_OP = 'DELETE' THEN
        RETURN OLD;
    ELSE
        RETURN NEW;
    END IF;
END;
$function$
;

CREATE OR REPLACE FUNCTION public.validate_evidence_due_date()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
DECLARE
    v_due_date TIMESTAMP WITH TIME ZONE;
    v_now TIMESTAMP WITH TIME ZONE;
BEGIN
    v_now := NOW();
    
    -- Get task due_date
    SELECT t.due_date INTO v_due_date
    FROM public.tasks t
    WHERE t.id = NEW.task_id;
    
    -- Check if due date has passed
    IF v_due_date IS NOT NULL AND v_now > v_due_date THEN
        RAISE EXCEPTION 'Evidence cannot be submitted after due date.';
    END IF;
    
    RETURN NEW;
END;
$function$
;

grant delete on table "public"."judgement_thread_assets" to "anon";

grant insert on table "public"."judgement_thread_assets" to "anon";

grant references on table "public"."judgement_thread_assets" to "anon";

grant select on table "public"."judgement_thread_assets" to "anon";

grant trigger on table "public"."judgement_thread_assets" to "anon";

grant truncate on table "public"."judgement_thread_assets" to "anon";

grant update on table "public"."judgement_thread_assets" to "anon";

grant delete on table "public"."judgement_thread_assets" to "authenticated";

grant insert on table "public"."judgement_thread_assets" to "authenticated";

grant references on table "public"."judgement_thread_assets" to "authenticated";

grant select on table "public"."judgement_thread_assets" to "authenticated";

grant trigger on table "public"."judgement_thread_assets" to "authenticated";

grant truncate on table "public"."judgement_thread_assets" to "authenticated";

grant update on table "public"."judgement_thread_assets" to "authenticated";

grant delete on table "public"."judgement_thread_assets" to "service_role";

grant insert on table "public"."judgement_thread_assets" to "service_role";

grant references on table "public"."judgement_thread_assets" to "service_role";

grant select on table "public"."judgement_thread_assets" to "service_role";

grant trigger on table "public"."judgement_thread_assets" to "service_role";

grant truncate on table "public"."judgement_thread_assets" to "service_role";

grant update on table "public"."judgement_thread_assets" to "service_role";

grant delete on table "public"."judgement_threads" to "anon";

grant insert on table "public"."judgement_threads" to "anon";

grant references on table "public"."judgement_threads" to "anon";

grant select on table "public"."judgement_threads" to "anon";

grant trigger on table "public"."judgement_threads" to "anon";

grant truncate on table "public"."judgement_threads" to "anon";

grant update on table "public"."judgement_threads" to "anon";

grant delete on table "public"."judgement_threads" to "authenticated";

grant insert on table "public"."judgement_threads" to "authenticated";

grant references on table "public"."judgement_threads" to "authenticated";

grant select on table "public"."judgement_threads" to "authenticated";

grant trigger on table "public"."judgement_threads" to "authenticated";

grant truncate on table "public"."judgement_threads" to "authenticated";

grant update on table "public"."judgement_threads" to "authenticated";

grant delete on table "public"."judgement_threads" to "service_role";

grant insert on table "public"."judgement_threads" to "service_role";

grant references on table "public"."judgement_threads" to "service_role";

grant select on table "public"."judgement_threads" to "service_role";

grant trigger on table "public"."judgement_threads" to "service_role";

grant truncate on table "public"."judgement_threads" to "service_role";

grant update on table "public"."judgement_threads" to "service_role";

grant delete on table "public"."judgements" to "anon";

grant insert on table "public"."judgements" to "anon";

grant references on table "public"."judgements" to "anon";

grant select on table "public"."judgements" to "anon";

grant trigger on table "public"."judgements" to "anon";

grant truncate on table "public"."judgements" to "anon";

grant update on table "public"."judgements" to "anon";

grant delete on table "public"."judgements" to "authenticated";

grant insert on table "public"."judgements" to "authenticated";

grant references on table "public"."judgements" to "authenticated";

grant select on table "public"."judgements" to "authenticated";

grant trigger on table "public"."judgements" to "authenticated";

grant truncate on table "public"."judgements" to "authenticated";

grant update on table "public"."judgements" to "authenticated";

grant delete on table "public"."judgements" to "service_role";

grant insert on table "public"."judgements" to "service_role";

grant references on table "public"."judgements" to "service_role";

grant select on table "public"."judgements" to "service_role";

grant trigger on table "public"."judgements" to "service_role";

grant truncate on table "public"."judgements" to "service_role";

grant update on table "public"."judgements" to "service_role";

grant delete on table "public"."profiles" to "anon";

grant insert on table "public"."profiles" to "anon";

grant references on table "public"."profiles" to "anon";

grant select on table "public"."profiles" to "anon";

grant trigger on table "public"."profiles" to "anon";

grant truncate on table "public"."profiles" to "anon";

grant update on table "public"."profiles" to "anon";

grant delete on table "public"."profiles" to "authenticated";

grant insert on table "public"."profiles" to "authenticated";

grant references on table "public"."profiles" to "authenticated";

grant select on table "public"."profiles" to "authenticated";

grant trigger on table "public"."profiles" to "authenticated";

grant truncate on table "public"."profiles" to "authenticated";

grant update on table "public"."profiles" to "authenticated";

grant delete on table "public"."profiles" to "service_role";

grant insert on table "public"."profiles" to "service_role";

grant references on table "public"."profiles" to "service_role";

grant select on table "public"."profiles" to "service_role";

grant trigger on table "public"."profiles" to "service_role";

grant truncate on table "public"."profiles" to "service_role";

grant update on table "public"."profiles" to "service_role";

grant delete on table "public"."rating_histories" to "anon";

grant insert on table "public"."rating_histories" to "anon";

grant references on table "public"."rating_histories" to "anon";

grant select on table "public"."rating_histories" to "anon";

grant trigger on table "public"."rating_histories" to "anon";

grant truncate on table "public"."rating_histories" to "anon";

grant update on table "public"."rating_histories" to "anon";

grant delete on table "public"."rating_histories" to "authenticated";

grant insert on table "public"."rating_histories" to "authenticated";

grant references on table "public"."rating_histories" to "authenticated";

grant select on table "public"."rating_histories" to "authenticated";

grant trigger on table "public"."rating_histories" to "authenticated";

grant truncate on table "public"."rating_histories" to "authenticated";

grant update on table "public"."rating_histories" to "authenticated";

grant delete on table "public"."rating_histories" to "service_role";

grant insert on table "public"."rating_histories" to "service_role";

grant references on table "public"."rating_histories" to "service_role";

grant select on table "public"."rating_histories" to "service_role";

grant trigger on table "public"."rating_histories" to "service_role";

grant truncate on table "public"."rating_histories" to "service_role";

grant update on table "public"."rating_histories" to "service_role";

grant delete on table "public"."referee_available_time_slots" to "anon";

grant insert on table "public"."referee_available_time_slots" to "anon";

grant references on table "public"."referee_available_time_slots" to "anon";

grant select on table "public"."referee_available_time_slots" to "anon";

grant trigger on table "public"."referee_available_time_slots" to "anon";

grant truncate on table "public"."referee_available_time_slots" to "anon";

grant update on table "public"."referee_available_time_slots" to "anon";

grant delete on table "public"."referee_available_time_slots" to "authenticated";

grant insert on table "public"."referee_available_time_slots" to "authenticated";

grant references on table "public"."referee_available_time_slots" to "authenticated";

grant select on table "public"."referee_available_time_slots" to "authenticated";

grant trigger on table "public"."referee_available_time_slots" to "authenticated";

grant truncate on table "public"."referee_available_time_slots" to "authenticated";

grant update on table "public"."referee_available_time_slots" to "authenticated";

grant delete on table "public"."referee_available_time_slots" to "service_role";

grant insert on table "public"."referee_available_time_slots" to "service_role";

grant references on table "public"."referee_available_time_slots" to "service_role";

grant select on table "public"."referee_available_time_slots" to "service_role";

grant trigger on table "public"."referee_available_time_slots" to "service_role";

grant truncate on table "public"."referee_available_time_slots" to "service_role";

grant update on table "public"."referee_available_time_slots" to "service_role";

grant delete on table "public"."task_evidence_assets" to "anon";

grant insert on table "public"."task_evidence_assets" to "anon";

grant references on table "public"."task_evidence_assets" to "anon";

grant select on table "public"."task_evidence_assets" to "anon";

grant trigger on table "public"."task_evidence_assets" to "anon";

grant truncate on table "public"."task_evidence_assets" to "anon";

grant update on table "public"."task_evidence_assets" to "anon";

grant delete on table "public"."task_evidence_assets" to "authenticated";

grant insert on table "public"."task_evidence_assets" to "authenticated";

grant references on table "public"."task_evidence_assets" to "authenticated";

grant select on table "public"."task_evidence_assets" to "authenticated";

grant trigger on table "public"."task_evidence_assets" to "authenticated";

grant truncate on table "public"."task_evidence_assets" to "authenticated";

grant update on table "public"."task_evidence_assets" to "authenticated";

grant delete on table "public"."task_evidence_assets" to "service_role";

grant insert on table "public"."task_evidence_assets" to "service_role";

grant references on table "public"."task_evidence_assets" to "service_role";

grant select on table "public"."task_evidence_assets" to "service_role";

grant trigger on table "public"."task_evidence_assets" to "service_role";

grant truncate on table "public"."task_evidence_assets" to "service_role";

grant update on table "public"."task_evidence_assets" to "service_role";

grant delete on table "public"."task_evidences" to "anon";

grant insert on table "public"."task_evidences" to "anon";

grant references on table "public"."task_evidences" to "anon";

grant select on table "public"."task_evidences" to "anon";

grant trigger on table "public"."task_evidences" to "anon";

grant truncate on table "public"."task_evidences" to "anon";

grant update on table "public"."task_evidences" to "anon";

grant delete on table "public"."task_evidences" to "authenticated";

grant insert on table "public"."task_evidences" to "authenticated";

grant references on table "public"."task_evidences" to "authenticated";

grant select on table "public"."task_evidences" to "authenticated";

grant trigger on table "public"."task_evidences" to "authenticated";

grant truncate on table "public"."task_evidences" to "authenticated";

grant update on table "public"."task_evidences" to "authenticated";

grant delete on table "public"."task_evidences" to "service_role";

grant insert on table "public"."task_evidences" to "service_role";

grant references on table "public"."task_evidences" to "service_role";

grant select on table "public"."task_evidences" to "service_role";

grant trigger on table "public"."task_evidences" to "service_role";

grant truncate on table "public"."task_evidences" to "service_role";

grant update on table "public"."task_evidences" to "service_role";

grant delete on table "public"."task_referee_requests" to "anon";

grant insert on table "public"."task_referee_requests" to "anon";

grant references on table "public"."task_referee_requests" to "anon";

grant select on table "public"."task_referee_requests" to "anon";

grant trigger on table "public"."task_referee_requests" to "anon";

grant truncate on table "public"."task_referee_requests" to "anon";

grant update on table "public"."task_referee_requests" to "anon";

grant delete on table "public"."task_referee_requests" to "authenticated";

grant insert on table "public"."task_referee_requests" to "authenticated";

grant references on table "public"."task_referee_requests" to "authenticated";

grant select on table "public"."task_referee_requests" to "authenticated";

grant trigger on table "public"."task_referee_requests" to "authenticated";

grant truncate on table "public"."task_referee_requests" to "authenticated";

grant update on table "public"."task_referee_requests" to "authenticated";

grant delete on table "public"."task_referee_requests" to "service_role";

grant insert on table "public"."task_referee_requests" to "service_role";

grant references on table "public"."task_referee_requests" to "service_role";

grant select on table "public"."task_referee_requests" to "service_role";

grant trigger on table "public"."task_referee_requests" to "service_role";

grant truncate on table "public"."task_referee_requests" to "service_role";

grant update on table "public"."task_referee_requests" to "service_role";

grant delete on table "public"."tasks" to "anon";

grant insert on table "public"."tasks" to "anon";

grant references on table "public"."tasks" to "anon";

grant select on table "public"."tasks" to "anon";

grant trigger on table "public"."tasks" to "anon";

grant truncate on table "public"."tasks" to "anon";

grant update on table "public"."tasks" to "anon";

grant delete on table "public"."tasks" to "authenticated";

grant insert on table "public"."tasks" to "authenticated";

grant references on table "public"."tasks" to "authenticated";

grant select on table "public"."tasks" to "authenticated";

grant trigger on table "public"."tasks" to "authenticated";

grant truncate on table "public"."tasks" to "authenticated";

grant update on table "public"."tasks" to "authenticated";

grant delete on table "public"."tasks" to "service_role";

grant insert on table "public"."tasks" to "service_role";

grant references on table "public"."tasks" to "service_role";

grant select on table "public"."tasks" to "service_role";

grant trigger on table "public"."tasks" to "service_role";

grant truncate on table "public"."tasks" to "service_role";

grant update on table "public"."tasks" to "service_role";

grant delete on table "public"."user_ratings" to "anon";

grant insert on table "public"."user_ratings" to "anon";

grant references on table "public"."user_ratings" to "anon";

grant select on table "public"."user_ratings" to "anon";

grant trigger on table "public"."user_ratings" to "anon";

grant truncate on table "public"."user_ratings" to "anon";

grant update on table "public"."user_ratings" to "anon";

grant delete on table "public"."user_ratings" to "authenticated";

grant insert on table "public"."user_ratings" to "authenticated";

grant references on table "public"."user_ratings" to "authenticated";

grant select on table "public"."user_ratings" to "authenticated";

grant trigger on table "public"."user_ratings" to "authenticated";

grant truncate on table "public"."user_ratings" to "authenticated";

grant update on table "public"."user_ratings" to "authenticated";

grant delete on table "public"."user_ratings" to "service_role";

grant insert on table "public"."user_ratings" to "service_role";

grant references on table "public"."user_ratings" to "service_role";

grant select on table "public"."user_ratings" to "service_role";

grant trigger on table "public"."user_ratings" to "service_role";

grant truncate on table "public"."user_ratings" to "service_role";

grant update on table "public"."user_ratings" to "service_role";

create policy "Thread Assets: delete if sender"
on "public"."judgement_thread_assets"
as permissive
for delete
to public
using ((EXISTS ( SELECT 1
   FROM judgement_threads jt
  WHERE ((jt.id = judgement_thread_assets.thread_id) AND (jt.sender_id = ( SELECT auth.uid() AS uid))))));


create policy "Thread Assets: insert if participant"
on "public"."judgement_thread_assets"
as permissive
for insert
to public
with check ((EXISTS ( SELECT 1
   FROM ((judgement_threads jt
     JOIN judgements j ON ((jt.judgement_id = j.id)))
     JOIN tasks t ON ((j.task_id = t.id)))
  WHERE ((jt.id = judgement_thread_assets.thread_id) AND ((t.tasker_id = ( SELECT auth.uid() AS uid)) OR (j.referee_id = ( SELECT auth.uid() AS uid)))))));


create policy "Thread Assets: select if participant"
on "public"."judgement_thread_assets"
as permissive
for select
to public
using ((EXISTS ( SELECT 1
   FROM ((judgement_threads jt
     JOIN judgements j ON ((jt.judgement_id = j.id)))
     JOIN tasks t ON ((j.task_id = t.id)))
  WHERE ((jt.id = judgement_thread_assets.thread_id) AND ((t.tasker_id = ( SELECT auth.uid() AS uid)) OR (j.referee_id = ( SELECT auth.uid() AS uid)))))));


create policy "Thread Assets: update if sender"
on "public"."judgement_thread_assets"
as permissive
for update
to public
using ((EXISTS ( SELECT 1
   FROM judgement_threads jt
  WHERE ((jt.id = judgement_thread_assets.thread_id) AND (jt.sender_id = ( SELECT auth.uid() AS uid))))));


create policy "Threads: delete if sender"
on "public"."judgement_threads"
as permissive
for delete
to public
using ((sender_id = ( SELECT auth.uid() AS uid)));


create policy "Threads: insert if participant"
on "public"."judgement_threads"
as permissive
for insert
to public
with check ((EXISTS ( SELECT 1
   FROM (judgements j
     JOIN tasks t ON ((j.task_id = t.id)))
  WHERE ((j.id = judgement_threads.judgement_id) AND ((t.tasker_id = ( SELECT auth.uid() AS uid)) OR (j.referee_id = ( SELECT auth.uid() AS uid)))))));


create policy "Threads: select if participant"
on "public"."judgement_threads"
as permissive
for select
to public
using ((EXISTS ( SELECT 1
   FROM (judgements j
     JOIN tasks t ON ((j.task_id = t.id)))
  WHERE ((j.id = judgement_threads.judgement_id) AND ((t.tasker_id = ( SELECT auth.uid() AS uid)) OR (j.referee_id = ( SELECT auth.uid() AS uid)))))));


create policy "Threads: update if sender"
on "public"."judgement_threads"
as permissive
for update
to public
using ((sender_id = ( SELECT auth.uid() AS uid)));


create policy "Judgements: insert if referee"
on "public"."judgements"
as permissive
for insert
to public
with check ((referee_id = ( SELECT auth.uid() AS uid)));


create policy "Judgements: select if tasker or referee"
on "public"."judgements"
as permissive
for select
to public
using (((referee_id = ( SELECT auth.uid() AS uid)) OR is_task_tasker(task_id, ( SELECT auth.uid() AS uid))));


create policy "Judgements: update if referee or tasker"
on "public"."judgements"
as permissive
for update
to public
using (((referee_id = ( SELECT auth.uid() AS uid)) OR is_task_tasker(task_id, ( SELECT auth.uid() AS uid))));


create policy "Profiles: public read"
on "public"."profiles"
as permissive
for select
to public
using (true);


create policy "Profiles: update if self"
on "public"."profiles"
as permissive
for update
to public
using ((id = ( SELECT auth.uid() AS uid)));


create policy "Rating Histories: insert if authenticated"
on "public"."rating_histories"
as permissive
for insert
to authenticated
with check (true);


create policy "Rating Histories: select if task participant"
on "public"."rating_histories"
as permissive
for select
to authenticated
using (((EXISTS ( SELECT 1
   FROM tasks t
  WHERE ((t.id = rating_histories.task_id) AND (t.tasker_id = ( SELECT auth.uid() AS uid))))) OR (EXISTS ( SELECT 1
   FROM judgements j
  WHERE ((j.task_id = rating_histories.task_id) AND (j.referee_id = ( SELECT auth.uid() AS uid)))))));


create policy "referee_available_time_slots: delete for own records"
on "public"."referee_available_time_slots"
as permissive
for delete
to public
using ((user_id = ( SELECT auth.uid() AS uid)));


create policy "referee_available_time_slots: insert for own records"
on "public"."referee_available_time_slots"
as permissive
for insert
to public
with check ((user_id = ( SELECT auth.uid() AS uid)));


create policy "referee_available_time_slots: select for all"
on "public"."referee_available_time_slots"
as permissive
for select
to public
using (true);


create policy "referee_available_time_slots: update for own records"
on "public"."referee_available_time_slots"
as permissive
for update
to public
using ((user_id = ( SELECT auth.uid() AS uid)));


create policy "Task Evidence Assets: delete if tasker"
on "public"."task_evidence_assets"
as permissive
for delete
to public
using ((EXISTS ( SELECT 1
   FROM (task_evidences te
     JOIN tasks t ON ((te.task_id = t.id)))
  WHERE ((te.id = task_evidence_assets.evidence_id) AND (t.tasker_id = ( SELECT auth.uid() AS uid))))));


create policy "Task Evidence Assets: insert if tasker"
on "public"."task_evidence_assets"
as permissive
for insert
to public
with check ((EXISTS ( SELECT 1
   FROM (task_evidences te
     JOIN tasks t ON ((te.task_id = t.id)))
  WHERE ((te.id = task_evidence_assets.evidence_id) AND (t.tasker_id = ( SELECT auth.uid() AS uid))))));


create policy "Task Evidence Assets: select if tasker or referee"
on "public"."task_evidence_assets"
as permissive
for select
to public
using (((EXISTS ( SELECT 1
   FROM (task_evidences te
     JOIN tasks t ON ((te.task_id = t.id)))
  WHERE ((te.id = task_evidence_assets.evidence_id) AND (t.tasker_id = ( SELECT auth.uid() AS uid))))) OR (EXISTS ( SELECT 1
   FROM (task_evidences te
     JOIN judgements j ON ((te.task_id = j.task_id)))
  WHERE ((te.id = task_evidence_assets.evidence_id) AND (j.referee_id = ( SELECT auth.uid() AS uid)))))));


create policy "Task Evidence Assets: update if tasker"
on "public"."task_evidence_assets"
as permissive
for update
to public
using ((EXISTS ( SELECT 1
   FROM (task_evidences te
     JOIN tasks t ON ((te.task_id = t.id)))
  WHERE ((te.id = task_evidence_assets.evidence_id) AND (t.tasker_id = ( SELECT auth.uid() AS uid))))));


create policy "Task Evidences: delete if tasker"
on "public"."task_evidences"
as permissive
for delete
to public
using ((EXISTS ( SELECT 1
   FROM tasks t
  WHERE ((t.id = task_evidences.task_id) AND (t.tasker_id = ( SELECT auth.uid() AS uid))))));


create policy "Task Evidences: insert if tasker"
on "public"."task_evidences"
as permissive
for insert
to public
with check ((EXISTS ( SELECT 1
   FROM tasks t
  WHERE ((t.id = task_evidences.task_id) AND (t.tasker_id = ( SELECT auth.uid() AS uid))))));


create policy "Task Evidences: select if tasker or referee"
on "public"."task_evidences"
as permissive
for select
to public
using (((EXISTS ( SELECT 1
   FROM tasks t
  WHERE ((t.id = task_evidences.task_id) AND (t.tasker_id = ( SELECT auth.uid() AS uid))))) OR (EXISTS ( SELECT 1
   FROM judgements j
  WHERE ((j.task_id = task_evidences.task_id) AND (j.referee_id = ( SELECT auth.uid() AS uid)))))));


create policy "Task Evidences: update if tasker"
on "public"."task_evidences"
as permissive
for update
to public
using ((EXISTS ( SELECT 1
   FROM tasks t
  WHERE ((t.id = task_evidences.task_id) AND (t.tasker_id = ( SELECT auth.uid() AS uid))))));


create policy "task_referee_requests: insert if tasker"
on "public"."task_referee_requests"
as permissive
for insert
to public
with check ((task_id IN ( SELECT tasks.id
   FROM tasks
  WHERE (tasks.tasker_id = ( SELECT auth.uid() AS uid)))));


create policy "task_referee_requests: select for owners and assigned referees"
on "public"."task_referee_requests"
as permissive
for select
to public
using (((task_id IN ( SELECT tasks.id
   FROM tasks
  WHERE (tasks.tasker_id = ( SELECT auth.uid() AS uid)))) OR (matched_referee_id = ( SELECT auth.uid() AS uid))));


create policy "task_referee_requests: update for assigned referees"
on "public"."task_referee_requests"
as permissive
for update
to public
using ((matched_referee_id = ( SELECT auth.uid() AS uid)))
with check ((matched_referee_id = ( SELECT auth.uid() AS uid)));


create policy "Tasks: delete if tasker"
on "public"."tasks"
as permissive
for delete
to public
using ((tasker_id = ( SELECT auth.uid() AS uid)));


create policy "Tasks: insert if authenticated"
on "public"."tasks"
as permissive
for insert
to public
with check ((tasker_id = ( SELECT auth.uid() AS uid)));


create policy "Tasks: select if tasker, referee, or referee candidate"
on "public"."tasks"
as permissive
for select
to public
using (((tasker_id = ( SELECT auth.uid() AS uid)) OR is_task_referee(id, ( SELECT auth.uid() AS uid)) OR is_task_referee_candidate(id, ( SELECT auth.uid() AS uid))));


create policy "Tasks: update if tasker"
on "public"."tasks"
as permissive
for update
to public
using ((tasker_id = ( SELECT auth.uid() AS uid)));


create policy "user_ratings: select for all"
on "public"."user_ratings"
as permissive
for select
to public
using (true);


CREATE TRIGGER on_judgement_threads_update BEFORE UPDATE ON public.judgement_threads FOR EACH ROW EXECUTE FUNCTION handle_updated_at();

CREATE TRIGGER auto_score_timeout_referee_trigger AFTER UPDATE ON public.judgements FOR EACH ROW EXECUTE FUNCTION auto_score_timeout_referee();

CREATE TRIGGER on_judgement_confirmed AFTER UPDATE ON public.judgements FOR EACH ROW WHEN ((old.is_confirmed IS DISTINCT FROM new.is_confirmed)) EXECUTE FUNCTION handle_judgement_confirmation();

CREATE TRIGGER on_judgements_update BEFORE UPDATE ON public.judgements FOR EACH ROW EXECUTE FUNCTION handle_updated_at();

CREATE TRIGGER trigger_auto_close_task AFTER UPDATE ON public.judgements FOR EACH ROW WHEN (((new.is_confirmed = true) AND (old.is_confirmed = false))) EXECUTE FUNCTION close_task_if_all_judgements_confirmed();

CREATE TRIGGER trigger_evidence_timeout_confirmation AFTER UPDATE OF is_evidence_timeout_confirmed ON public.judgements FOR EACH ROW EXECUTE FUNCTION handle_evidence_timeout_confirmation();

CREATE TRIGGER on_profiles_update BEFORE UPDATE ON public.profiles FOR EACH ROW EXECUTE FUNCTION handle_updated_at();

CREATE TRIGGER trigger_set_rater_id BEFORE INSERT ON public.rating_histories FOR EACH ROW EXECUTE FUNCTION set_rater_id();

CREATE TRIGGER trigger_update_user_ratings AFTER INSERT OR DELETE OR UPDATE ON public.rating_histories FOR EACH ROW EXECUTE FUNCTION update_user_ratings();

CREATE TRIGGER set_referee_available_time_slots_updated_at BEFORE UPDATE ON public.referee_available_time_slots FOR EACH ROW EXECUTE FUNCTION handle_updated_at();

CREATE TRIGGER set_task_evidences_updated_at BEFORE UPDATE ON public.task_evidences FOR EACH ROW EXECUTE FUNCTION handle_updated_at();

CREATE TRIGGER validate_evidence_due_date_insert BEFORE INSERT ON public.task_evidences FOR EACH ROW EXECUTE FUNCTION validate_evidence_due_date();

CREATE TRIGGER validate_evidence_due_date_update BEFORE UPDATE OF description, status ON public.task_evidences FOR EACH ROW EXECUTE FUNCTION validate_evidence_due_date();

CREATE TRIGGER set_task_referee_requests_updated_at BEFORE UPDATE ON public.task_referee_requests FOR EACH ROW EXECUTE FUNCTION handle_updated_at();

CREATE TRIGGER task_referee_requests_matching_trigger AFTER INSERT OR UPDATE ON public.task_referee_requests FOR EACH ROW EXECUTE FUNCTION trigger_process_matching();

CREATE TRIGGER on_tasks_update BEFORE UPDATE ON public.tasks FOR EACH ROW EXECUTE FUNCTION handle_updated_at();

CREATE TRIGGER set_user_ratings_updated_at BEFORE UPDATE ON public.user_ratings FOR EACH ROW EXECUTE FUNCTION handle_updated_at();


