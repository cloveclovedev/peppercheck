CREATE TYPE public.referee_request_status AS ENUM (
    'pending',
    'matched',
    'accepted',
    'declined',
    'expired',
    'payment_processing',
    'closed'
);

CREATE TYPE public.matching_strategy AS ENUM (
    'standard',
    'premium',
    'direct'
);
