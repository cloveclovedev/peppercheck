-- Table: billing_prices
-- Defines price per matching_strategy and currency. Amount stored in smallest unit (exponent defined in currencies).
CREATE TABLE IF NOT EXISTS public.billing_prices (
    currency_code text NOT NULL,
    matching_strategy text NOT NULL,
    amount_minor bigint NOT NULL CHECK (amount_minor >= 0),
    CONSTRAINT billing_prices_pkey PRIMARY KEY (currency_code, matching_strategy)
);

ALTER TABLE public.billing_prices OWNER TO postgres;

CREATE INDEX idx_billing_prices_matching_strategy ON public.billing_prices USING btree (matching_strategy);
CREATE INDEX idx_billing_prices_currency_code ON public.billing_prices USING btree (currency_code);

COMMENT ON TABLE public.billing_prices IS 'Price table per currency and matching strategy; amount stored in smallest currency unit.';
COMMENT ON COLUMN public.billing_prices.amount_minor IS 'Amount in smallest unit (respect currencies.exponent).';
