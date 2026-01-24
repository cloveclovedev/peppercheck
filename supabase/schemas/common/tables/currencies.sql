-- Table: currencies
CREATE TABLE IF NOT EXISTS public.currencies (
    code text PRIMARY KEY,
    kind text NOT NULL CHECK (kind IN ('fiat', 'crypto')),
    exponent integer NOT NULL CHECK (exponent BETWEEN 0 AND 18),
    description text
);

ALTER TABLE public.currencies OWNER TO postgres;
