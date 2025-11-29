# Billing Retry Policy (MVP)

## Scope
- Applies to `billing_jobs` processed by the Stripe billing worker.
- Covers automatic retries for payment failures (no error-type-specific handling).

## Retry rule
- `max_retry_attempts` is stored in `public.billing_settings` (singleton row id=1).
- Default value: 3. Changeable by updating the row; both SQL functions and the Edge Function read from the same table.
- A job is considered permanently failed when `attempt_count >= max_retry_attempts` **and** `status = 'failed'`.

## Execution flow
1) **Cron trigger (hourly)**: `retry_failed_billing_jobs()` selects jobs where `status='failed'` AND `attempt_count < max_retry_attempts`, then posts each job id to the billing worker HTTP endpoint via `pg_net`.
2) **Claim & increment**: `claim_billing_job(p_job_id)` locks the job, sets `status='processing'`, increments `attempt_count`, and returns the row only if it is `pending` or `failed` and still under the retry limit.
3) **PaymentIntent**: Billing worker recreates/uses the same PaymentIntent with idempotency key `billing_job_{id}`. Stripe webhook (`finalize_billing_job`) sets the final status (`succeeded` or `failed`) and records the latest error code/message.

## Manual retry after updating payment method
- Endpoint: `force_retry_failed_billing_jobs(p_user_id default auth.uid)` (allowed for self or service_role). Enqueues failed jobs for the user with `force_retry=true` to bypass the max attempts guard.
- Flow: user updates card → press "Retry payment" → call this RPC → jobs are re-sent to billing-worker. On success the job becomes `succeeded` and is no longer action-required.

## Action-required lookup
- Endpoint: `is_billing_action_required(p_user_id default auth.uid)` returns a boolean indicating whether the user has any `failed` billing jobs at/over `max_retry_attempts`.
- For task creation guard, the BEFORE INSERT trigger on `tasks` calls this function and blocks with message: "You have an unpaid task. Please update your payment method and retry the payment."

## Idempotency & safety
- Claim function guards against double-processing by status filter + attempt limit + row lock.
- Cron query excludes `processing`/`succeeded` jobs.
- Missing `billing_settings` or `max_retry_attempts` causes functions/worker to fail fast (no silent fallback).

## Operational notes
- Ensure `billing_worker_url` and `service_role_key` secrets are present for cron-triggered HTTP calls.
- To adjust retries, update `public.billing_settings.max_retry_attempts` (id=1) and redeploy if needed.
- Manual retry kick: `SELECT public.retry_failed_billing_jobs();` (requires proper secrets).
