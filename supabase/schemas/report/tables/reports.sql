CREATE TABLE IF NOT EXISTS public.reports (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    reporter_id uuid NOT NULL,
    task_id uuid NOT NULL,
    reporter_role public.reporter_role NOT NULL,
    content_type public.report_content_type NOT NULL,
    content_id uuid,
    reason public.report_reason NOT NULL,
    detail text,
    status public.report_status NOT NULL DEFAULT 'pending'::public.report_status,
    admin_note text,
    resolved_at timestamp with time zone,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL,
    CONSTRAINT reports_pkey PRIMARY KEY (id),
    CONSTRAINT reports_reporter_id_fkey FOREIGN KEY (reporter_id) REFERENCES auth.users(id) ON DELETE CASCADE,
    CONSTRAINT reports_task_id_fkey FOREIGN KEY (task_id) REFERENCES public.tasks(id) ON DELETE CASCADE,
    CONSTRAINT reports_unique_per_user_task UNIQUE (reporter_id, task_id)
);

ALTER TABLE public.reports OWNER TO postgres;

CREATE INDEX idx_reports_task_id ON public.reports USING btree (task_id);
CREATE INDEX idx_reports_status ON public.reports USING btree (status);
CREATE INDEX idx_reports_created_at ON public.reports USING btree (created_at);

CREATE TRIGGER on_reports_update_set_updated_at
    BEFORE UPDATE ON public.reports
    FOR EACH ROW
    EXECUTE FUNCTION public.handle_updated_at();
