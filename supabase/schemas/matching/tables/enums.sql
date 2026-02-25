CREATE TYPE public.referee_request_status AS ENUM (
    'pending',
    'matched',
    'accepted',
    'declined',
    'expired',
    'payment_processing',
    'closed',
    'cancelled'
);

CREATE TYPE public.matching_strategy AS ENUM (
    'standard',
    'premium',
    'direct'
);
