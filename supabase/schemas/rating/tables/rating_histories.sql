-- Enum: rating_type (only used by rating_histories)
CREATE TYPE public.rating_type AS ENUM ('tasker', 'referee');

-- Table: rating_histories
CREATE TABLE IF NOT EXISTS public.rating_histories (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    judgement_id uuid NOT NULL,
    ratee_id uuid,
    rater_id uuid,
    rating_type public.rating_type NOT NULL,
    is_positive boolean NOT NULL,
    comment text,
    created_at timestamp with time zone DEFAULT now(),
    CONSTRAINT rating_history_pkey PRIMARY KEY (id),
    CONSTRAINT unique_rating_per_judgement UNIQUE (judgement_id, rating_type)
);

ALTER TABLE public.rating_histories OWNER TO postgres;

-- Indexes
CREATE INDEX idx_rating_histories_ratee_id ON public.rating_histories USING btree (ratee_id);
CREATE INDEX idx_rating_histories_ratee_type ON public.rating_histories USING btree (ratee_id, rating_type);

COMMENT ON COLUMN public.rating_histories.ratee_id IS 'ID of the user who received the rating';
COMMENT ON COLUMN public.rating_histories.rater_id IS 'ID of the user who gave the rating; set by RPC';
COMMENT ON COLUMN public.rating_histories.judgement_id IS 'ID of the specific judgement this rating is for';
COMMENT ON COLUMN public.rating_histories.is_positive IS 'Binary rating: true = positive, false = negative';
COMMENT ON CONSTRAINT unique_rating_per_judgement ON public.rating_histories IS 'One rating per rating_type per judgement. Enables ON CONFLICT in auto_score_timeout_referee.';

ALTER TABLE ONLY public.rating_histories
    ADD CONSTRAINT fk_rating_histories_judgement_id FOREIGN KEY (judgement_id) REFERENCES public.judgements(id);

ALTER TABLE ONLY public.rating_histories
    ADD CONSTRAINT fk_rating_histories_rater_id FOREIGN KEY (rater_id) REFERENCES public.profiles(id);

ALTER TABLE ONLY public.rating_histories
    ADD CONSTRAINT fk_rating_histories_ratee_id FOREIGN KEY (ratee_id) REFERENCES public.profiles(id) ON DELETE SET NULL;
