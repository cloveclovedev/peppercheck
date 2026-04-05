-- Enable Realtime for user_subscriptions so Flutter clients can detect
-- subscription status changes from RTDN processing
ALTER PUBLICATION supabase_realtime ADD TABLE public.user_subscriptions;
