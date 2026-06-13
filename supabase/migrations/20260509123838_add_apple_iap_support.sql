alter table "public"."user_subscriptions" add column "apple_original_transaction_id" text;

CREATE INDEX idx_user_subscriptions_apple_id ON public.user_subscriptions USING btree (apple_original_transaction_id);

-- DML, not detected by schema diff

-- Apple subscription prices (Issue #402)
INSERT INTO public.subscription_plan_prices (plan_id, currency_code, amount_minor, provider)
VALUES
    ('light', 'JPY', 650, 'apple'),
    ('standard', 'JPY', 1280, 'apple'),
    ('premium', 'JPY', 2480, 'apple')
ON CONFLICT (plan_id, currency_code, provider) DO UPDATE SET
    amount_minor = EXCLUDED.amount_minor;

-- Align Google Play premium price with Apple (Issue #411)
UPDATE public.subscription_plan_prices
SET amount_minor = 2480
WHERE plan_id = 'premium' AND provider = 'google';
