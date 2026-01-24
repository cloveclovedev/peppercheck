-- Snippet to manually force process the first pending matching request
-- Useful for debugging matching logic without waiting for triggers or when triggers fail silently.

DO $$
DECLARE
    v_req_id uuid;
    v_res json;
BEGIN
    -- 1. Get the first 'pending' request
    SELECT id INTO v_req_id 
    FROM public.task_referee_requests 
    WHERE status = 'pending' 
    LIMIT 1;
    
    -- 2. Process if found
    IF v_req_id IS NOT NULL THEN
        RAISE NOTICE 'Processing request ID: %', v_req_id;
        
        -- Call process_matching function
        v_res := public.process_matching(v_req_id);
        
        -- Log the result
        RAISE NOTICE 'Result: %', v_res;
    ELSE
        RAISE NOTICE 'No pending requests found.';
    END IF;
END $$;
