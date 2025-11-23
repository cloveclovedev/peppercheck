
-- Billing job status
CREATE TYPE public.billing_job_status AS ENUM ('pending', 'processing', 'succeeded', 'failed');

-- Payout job status
CREATE TYPE public.payout_job_status AS ENUM ('pending', 'processing', 'succeeded', 'failed');
