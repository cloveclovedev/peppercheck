-- Table: rating_histories
CREATE TABLE IF NOT EXISTS public.rating_histories (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    ratee_id uuid,
    task_id uuid,
    rating_type text NOT NULL,
    rating numeric NOT NULL,
    comment text,
    created_at timestamp with time zone DEFAULT now(),
    rater_id uuid,
    judgement_id uuid,
    CONSTRAINT rating_histories_rating_check CHECK (((rating >= (0)::numeric) AND (rating <= (5)::numeric))),
    CONSTRAINT rating_histories_rating_type_check CHECK ((rating_type = ANY (ARRAY['tasker'::text, 'referee'::text])))
);

ALTER TABLE public.rating_histories OWNER TO postgres;

ALTER TABLE ONLY public.rating_histories
    ADD CONSTRAINT rating_history_pkey PRIMARY KEY (id);

ALTER TABLE ONLY public.rating_histories
    ADD CONSTRAINT unique_rating_per_judgement UNIQUE (rater_id, ratee_id, judgement_id);

-- Indexes
CREATE INDEX idx_rating_histories_task_id ON public.rating_histories USING btree (task_id);
CREATE INDEX idx_rating_histories_user_id ON public.rating_histories USING btree (ratee_id);
CREATE INDEX idx_rating_histories_user_type ON public.rating_histories USING btree (ratee_id, rating_type);

COMMENT ON COLUMN public.rating_histories.ratee_id IS 'ID of the user who received the rating (renamed from user_id)';
COMMENT ON COLUMN public.rating_histories.rating IS '0-5 rating scale: 0=system timeout, 1-5=user rating';
COMMENT ON COLUMN public.rating_histories.rater_id IS 'ID of the user who gave the rating; if NULL on insert, trigger set_rater_id() sets auth.uid()';
COMMENT ON COLUMN public.rating_histories.judgement_id IS 'ID of the specific judgement this rating is for (when rating_type is referee)';
COMMENT ON CONSTRAINT unique_rating_per_judgement ON public.rating_histories IS 'Ensures that each rater can only rate each ratee once per judgement. This constraint enables ON CONFLICT functionality in the auto_score_timeout_referee trigger and prevents duplicate ratings.';

ALTER TABLE ONLY public.rating_histories
    ADD CONSTRAINT fk_rating_histories_judgement_id FOREIGN KEY (judgement_id) REFERENCES public.judgements(id);

ALTER TABLE ONLY public.rating_histories
    ADD CONSTRAINT fk_rating_histories_rater_id FOREIGN KEY (rater_id) REFERENCES public.profiles(id);

ALTER TABLE ONLY public.rating_histories
    ADD CONSTRAINT rating_histories_task_id_fkey FOREIGN KEY (task_id) REFERENCES public.tasks(id) ON DELETE SET NULL;

ALTER TABLE ONLY public.rating_histories
    ADD CONSTRAINT rating_histories_user_id_fkey FOREIGN KEY (ratee_id) REFERENCES public.profiles(id) ON DELETE SET NULL;
