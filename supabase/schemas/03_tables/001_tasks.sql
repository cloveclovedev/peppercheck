-- Table: tasks
CREATE TABLE IF NOT EXISTS public.tasks (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    tasker_id uuid NOT NULL,
    title text NOT NULL,
    description text,
    criteria text,
    due_date timestamp with time zone,
    fee_amount numeric(36,18),
    fee_currency text,
    status text DEFAULT 'draft'::text NOT NULL,
    created_at timestamp with time zone DEFAULT now(),
    updated_at timestamp with time zone DEFAULT now()
);

ALTER TABLE public.tasks OWNER TO postgres;

ALTER TABLE ONLY public.tasks
    ADD CONSTRAINT tasks_pkey PRIMARY KEY (id);

-- Indexes
CREATE INDEX idx_tasks_status ON public.tasks USING btree (status);
CREATE INDEX idx_tasks_status_tasker_id ON public.tasks USING btree (status, tasker_id);
CREATE INDEX idx_tasks_tasker_id ON public.tasks USING btree (tasker_id);
