ALTER TABLE public.referee_blocked_dates ENABLE ROW LEVEL SECURITY;

CREATE POLICY "referee_blocked_dates: select for own records"
    ON public.referee_blocked_dates FOR SELECT
    USING ((user_id = (SELECT auth.uid() AS uid)));

CREATE POLICY "referee_blocked_dates: insert for own records"
    ON public.referee_blocked_dates FOR INSERT
    WITH CHECK ((user_id = (SELECT auth.uid() AS uid)));

CREATE POLICY "referee_blocked_dates: update for own records"
    ON public.referee_blocked_dates FOR UPDATE
    USING ((user_id = (SELECT auth.uid() AS uid)));

CREATE POLICY "referee_blocked_dates: delete for own records"
    ON public.referee_blocked_dates FOR DELETE
    USING ((user_id = (SELECT auth.uid() AS uid)));
