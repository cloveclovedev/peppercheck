CREATE POLICY "notification_settings: users can read own settings"
    ON public.notification_settings FOR SELECT
    USING (auth.uid() = user_id);

CREATE POLICY "notification_settings: users can update own settings"
    ON public.notification_settings FOR UPDATE
    USING (auth.uid() = user_id);
