-- Seed subscription_plans
INSERT INTO public.subscription_plans (id, name, monthly_points, is_active)
VALUES
    ('light', 'Light Plan', 5, true),
    ('standard', 'Standard Plan', 10, true),
    ('premium', 'Premium Plan', 20, true)
ON CONFLICT (id) DO UPDATE SET
    name = EXCLUDED.name,
    monthly_points = EXCLUDED.monthly_points,
    is_active = EXCLUDED.is_active;

-- Seed subscription_plan_prices
-- Stripe Prices
INSERT INTO public.subscription_plan_prices (plan_id, currency_code, amount_minor, provider)
VALUES
    ('light', 'JPY', 480, 'stripe'),
    ('standard', 'JPY', 980, 'stripe'),
    ('premium', 'JPY', 1980, 'stripe')
ON CONFLICT (plan_id, currency_code, provider) DO UPDATE SET
    amount_minor = EXCLUDED.amount_minor;

-- Google Play Prices
INSERT INTO public.subscription_plan_prices (plan_id, currency_code, amount_minor, provider)
VALUES
    ('light', 'JPY', 650, 'google'),
    ('standard', 'JPY', 1280, 'google'),
    ('premium', 'JPY', 2580, 'google')
ON CONFLICT (plan_id, currency_code, provider) DO UPDATE SET
    amount_minor = EXCLUDED.amount_minor;
