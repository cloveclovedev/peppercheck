CREATE TABLE IF NOT EXISTS public.referee_obligations (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    user_id uuid NOT NULL,
    status public.referee_obligation_status NOT NULL DEFAULT 'pending',
    source_request_id uuid NOT NULL,
    fulfill_request_id uuid,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    fulfilled_at timestamp with time zone,
    CONSTRAINT referee_obligations_pkey PRIMARY KEY (id),
    CONSTRAINT referee_obligations_user_id_fkey FOREIGN KEY (user_id) REFERENCES auth.users(id) ON DELETE CASCADE,
    CONSTRAINT referee_obligations_source_request_id_fkey FOREIGN KEY (source_request_id) REFERENCES public.task_referee_requests(id),
    CONSTRAINT referee_obligations_fulfill_request_id_fkey FOREIGN KEY (fulfill_request_id) REFERENCES public.task_referee_requests(id)
);

ALTER TABLE public.referee_obligations OWNER TO postgres;

CREATE INDEX idx_referee_obligations_user_id_status ON public.referee_obligations USING btree (user_id, status);

COMMENT ON TABLE public.referee_obligations IS 'Tracks referee obligations created when trial points are consumed. Each record represents one obligation to serve as a free referee (no reward points).';
