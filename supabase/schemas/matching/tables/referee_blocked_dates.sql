CREATE TABLE IF NOT EXISTS public.referee_blocked_dates (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id uuid NOT NULL,
    start_date date NOT NULL,
    end_date date NOT NULL,
    reason text,
    created_at timestamptz DEFAULT now(),
    updated_at timestamptz DEFAULT now(),
    CONSTRAINT referee_blocked_dates_user_id_fkey FOREIGN KEY (user_id) REFERENCES public.profiles(id) ON DELETE CASCADE,
    CONSTRAINT valid_date_range CHECK (end_date >= start_date)
);

ALTER TABLE public.referee_blocked_dates OWNER TO postgres;

CREATE INDEX idx_referee_blocked_dates_user_id ON public.referee_blocked_dates USING btree (user_id);
CREATE INDEX idx_referee_blocked_dates_date_range ON public.referee_blocked_dates USING btree (start_date, end_date);
