ALTER TABLE public.user_fcm_tokens ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Users can view their own tokens" ON public.user_fcm_tokens
    FOR SELECT
    USING ((select auth.uid()) = user_id);

CREATE POLICY "Users can insert their own tokens" ON public.user_fcm_tokens
    FOR INSERT
    WITH CHECK ((select auth.uid()) = user_id);

CREATE POLICY "Users can update their own tokens" ON public.user_fcm_tokens
    FOR UPDATE
    USING ((select auth.uid()) = user_id);

CREATE POLICY "Users can delete their own tokens" ON public.user_fcm_tokens
    FOR DELETE
    USING ((select auth.uid()) = user_id);
