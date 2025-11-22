-- Seed JPY currency and standard billing price
BEGIN;

INSERT INTO public.currencies (code, kind, exponent, description)
VALUES ('JPY', 'fiat', 0, 'Japanese Yen')
ON CONFLICT (code) DO NOTHING;

INSERT INTO public.billing_prices (currency_code, matching_strategy, amount_minor)
VALUES ('JPY', 'standard', 50)
ON CONFLICT (currency_code, matching_strategy)
DO UPDATE SET amount_minor = EXCLUDED.amount_minor;

COMMIT;
