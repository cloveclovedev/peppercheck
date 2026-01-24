CREATE TYPE public.subscription_status AS ENUM (
    'active',             -- Subscription is active and paid.
    'past_due',           -- Payment failed, retry logic active.
    'canceled',           -- Subscription canceled (won't renew).
    'unpaid',             -- Final payment failure, subscription suspended.
    'incomplete',         -- Initial payment failed.
    'incomplete_expired', -- Initial payment verification failed/expired.
    'trialing',           -- Free trial.
    'paused'              -- Paused (void).
);

CREATE TYPE public.subscription_provider AS ENUM (
    'stripe',
    'google',
    'apple'
);
