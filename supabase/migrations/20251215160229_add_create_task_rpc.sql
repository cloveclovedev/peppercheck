set check_function_bodies = off;

CREATE OR REPLACE FUNCTION public.create_task(title text, description text DEFAULT NULL::text, criteria text DEFAULT NULL::text, due_date timestamp with time zone DEFAULT NULL::timestamp with time zone, status text DEFAULT 'draft'::text, referee_requests jsonb[] DEFAULT NULL::jsonb[])
 RETURNS uuid
 LANGUAGE plpgsql
AS $function$
DECLARE
    new_task_id uuid;
    request_item jsonb;
    request_strategy text;
    request_preferred_referee_id uuid;
BEGIN
    -- Validate inputs based on status
    IF status = 'draft' THEN
        IF title IS NULL OR length(trim(title)) = 0 THEN
             RAISE EXCEPTION 'Title is required for draft tasks';
        END IF;
    ELSIF status = 'open' THEN
        IF title IS NULL OR length(trim(title)) = 0 THEN
             RAISE EXCEPTION 'Title is required for open tasks';
        END IF;
        IF description IS NULL OR length(trim(description)) = 0 THEN
             RAISE EXCEPTION 'Description is required for open tasks';
        END IF;
        IF criteria IS NULL OR length(trim(criteria)) = 0 THEN
             RAISE EXCEPTION 'Criteria is required for open tasks';
        END IF;
        IF due_date IS NULL THEN
             RAISE EXCEPTION 'Due date is required for open tasks';
        END IF;
        IF referee_requests IS NULL OR array_length(referee_requests, 1) IS NULL THEN
             RAISE EXCEPTION 'At least one referee request is required for open tasks';
        END IF;
    END IF;

    -- Insert into tasks
    INSERT INTO public.tasks (
        title,
        description,
        criteria,
        due_date,
        status,
        tasker_id -- Assumes RLS will handle this default or trigger, but usually we need auth.uid() if not passed.
                  -- Wait, table definition says tasker_id is NOT NULL.
                  -- Usually we set tasker_id = auth.uid() here.
    )
    VALUES (
        title,
        description,
        criteria,
        due_date,
        status,
        auth.uid()
    )
    RETURNING id INTO new_task_id;

    -- Handle Referee Requests if provided (Only for Open tasks)
    IF status = 'open' AND referee_requests IS NOT NULL THEN
        FOREACH request_item IN ARRAY referee_requests
        LOOP
            request_strategy := request_item->>'matching_strategy';

            -- Handle optional fields safely
            IF (request_item->>'preferred_referee_id') IS NOT NULL THEN
                request_preferred_referee_id := (request_item->>'preferred_referee_id')::uuid;
            ELSE
                request_preferred_referee_id := NULL;
            END IF;

            IF request_strategy IS NULL THEN
                 RAISE EXCEPTION 'matching_strategy is required in referee_requests';
            END IF;

            INSERT INTO public.task_referee_requests (
                task_id,
                matching_strategy,
                preferred_referee_id,
                status
            )
            VALUES (
                new_task_id,
                request_strategy,
                request_preferred_referee_id,
                'pending'
            );
        END LOOP;
    END IF;

    RETURN new_task_id;
END;
$function$
;


