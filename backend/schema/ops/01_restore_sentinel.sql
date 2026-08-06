-- Marker rows written by the PITR restore drill. The drill inserts a 'pre'
-- row, records a timestamp, inserts a 'post' row, then restores to that
-- timestamp and asserts only the 'pre' row survives. Not referenced by any
-- Go application code; it exists purely to prove restore correctness.
CREATE TABLE public.restore_sentinel (
    id         bigserial PRIMARY KEY,
    tag        text,
    created_at timestamptz NOT NULL DEFAULT now()
);
