-- Table: referee_available_time_slots
CREATE TABLE IF NOT EXISTS public.referee_available_time_slots (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    user_id uuid NOT NULL,
    dow smallint NOT NULL,
    start_min smallint NOT NULL,
    end_min smallint NOT NULL,
    is_active boolean DEFAULT true,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL,
    CONSTRAINT referee_available_time_slots_dow_check CHECK (((dow >= 0) AND (dow <= 6))),
    CONSTRAINT referee_available_time_slots_end_min_check CHECK (((end_min >= 1) AND (end_min <= 1440))),
    CONSTRAINT referee_available_time_slots_start_min_check CHECK (((start_min >= 0) AND (start_min <= 1439))),
    CONSTRAINT valid_time_range CHECK ((start_min < end_min))
);

ALTER TABLE public.referee_available_time_slots OWNER TO postgres;

ALTER TABLE ONLY public.referee_available_time_slots
    ADD CONSTRAINT referee_available_time_slots_pkey PRIMARY KEY (id);

ALTER TABLE ONLY public.referee_available_time_slots
    ADD CONSTRAINT referee_available_time_slots_user_id_dow_start_min_key UNIQUE (user_id, dow, start_min);

-- Indexes
CREATE INDEX idx_referee_available_time_slots_dow_time ON public.referee_available_time_slots USING btree (dow, start_min, end_min) WHERE (is_active = true);
CREATE INDEX idx_referee_available_time_slots_user_id ON public.referee_available_time_slots USING btree (user_id);

COMMENT ON TABLE public.referee_available_time_slots IS 'Referee available time slots using minute-based time slots with UUID primary key. Overlap prevention handled client-side in MVP, future: int4range + EXCLUDE USING GIST';
COMMENT ON COLUMN public.referee_available_time_slots.dow IS 'Day of week: 0=Sunday, 6=Saturday';
COMMENT ON COLUMN public.referee_available_time_slots.start_min IS 'Start time in minutes from midnight (0-1439)';
COMMENT ON COLUMN public.referee_available_time_slots.end_min IS 'End time in minutes from midnight (1-1440, where 1440 = next day 00:00)';

ALTER TABLE ONLY public.referee_available_time_slots
    ADD CONSTRAINT referee_available_time_slots_user_id_fkey FOREIGN KEY (user_id) REFERENCES public.profiles(id) ON DELETE CASCADE;
