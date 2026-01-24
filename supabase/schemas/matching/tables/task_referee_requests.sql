-- Table: task_referee_requests
-- Enums (referee_request_status, matching_strategy) are defined in schemas/matching/tables/enums.sql

CREATE TABLE IF NOT EXISTS public.task_referee_requests (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    task_id uuid NOT NULL,
    matching_strategy public.matching_strategy NOT NULL,
    preferred_referee_id uuid,
    status public.referee_request_status DEFAULT 'pending'::public.referee_request_status,
    matched_referee_id uuid,
    responded_at timestamp with time zone,
    created_at timestamp with time zone DEFAULT now(),
    updated_at timestamp with time zone DEFAULT now()
);

ALTER TABLE public.task_referee_requests OWNER TO postgres;

ALTER TABLE ONLY public.task_referee_requests
    ADD CONSTRAINT task_referee_requests_pkey PRIMARY KEY (id);

-- Indexes
CREATE INDEX idx_task_referee_requests_matched_referee_id ON public.task_referee_requests USING btree (matched_referee_id);
CREATE INDEX idx_task_referee_requests_matching_strategy ON public.task_referee_requests USING btree (matching_strategy);
CREATE INDEX idx_task_referee_requests_status ON public.task_referee_requests USING btree (status);
CREATE INDEX idx_task_referee_requests_task_id ON public.task_referee_requests USING btree (task_id);

COMMENT ON TABLE public.task_referee_requests IS 'Manages referee matching requests for tasks, supporting multiple referees per task with different strategies';
COMMENT ON COLUMN public.task_referee_requests.matching_strategy IS 'Referee matching strategy: standard (basic auto-match), premium (advanced auto-match), direct (manual selection)';
COMMENT ON COLUMN public.task_referee_requests.preferred_referee_id IS 'Specific referee ID for direct assignment (required when matching_strategy = direct)';
COMMENT ON COLUMN public.task_referee_requests.status IS 'Request status: pending → matched → accepted/declined/expired → payment_processing → closed';
COMMENT ON COLUMN public.task_referee_requests.matched_referee_id IS 'Referee assigned by matching algorithm';
COMMENT ON COLUMN public.task_referee_requests.responded_at IS 'Timestamp when referee accepted or declined the request';


ALTER TABLE ONLY public.task_referee_requests
    ADD CONSTRAINT task_referee_requests_matched_referee_id_fkey FOREIGN KEY (matched_referee_id) REFERENCES public.profiles(id);

ALTER TABLE ONLY public.task_referee_requests
    ADD CONSTRAINT task_referee_requests_preferred_referee_id_fkey FOREIGN KEY (preferred_referee_id) REFERENCES public.profiles(id);

ALTER TABLE ONLY public.task_referee_requests
    ADD CONSTRAINT task_referee_requests_task_id_fkey FOREIGN KEY (task_id) REFERENCES public.tasks(id) ON DELETE CASCADE;
