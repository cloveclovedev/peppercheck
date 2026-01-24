CREATE TYPE public.point_reason AS ENUM (
    'plan_renewal',      -- Monthly subscription points grant
    'plan_upgrade',      -- Prorated points adjustment on upgrade
    'matching_request',  -- Consumed when requesting a referee matching (task creation)
    'matching_refund',   -- Refunded if matching fails or task is cancelled
    'manual_adjustment', -- Admin operation/Support
    'referral_bonus'     -- Points earned from referring users
);
