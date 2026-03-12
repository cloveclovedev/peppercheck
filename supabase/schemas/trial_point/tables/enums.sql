CREATE TYPE public.trial_point_reason AS ENUM (
    'initial_grant',
    'matching_lock',
    'matching_unlock',
    'matching_settled',
    'matching_refund',
    'subscription_deactivation'
);

CREATE TYPE public.referee_obligation_status AS ENUM (
    'pending',
    'fulfilled',
    'cancelled'
);

CREATE TYPE public.point_source_type AS ENUM (
    'regular',
    'trial'
);
