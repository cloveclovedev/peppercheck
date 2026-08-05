-- Referee availability inputs consumed by candidate selection: weekly recurring
-- time slots (in the referee's local timezone, read from profiles.timezone),
-- blocked date ranges, and per-referee knobs (accepting toggle + optional
-- concurrent-assignment cap). All updated_at columns are Go-maintained
-- (updated_at = now() on each UPDATE).

-- Weekly recurring availability. dow is 0=Sunday..6=Saturday; start_min/end_min
-- are minutes-past-midnight in the referee's local timezone.
CREATE TABLE public.referee_available_time_slots (
    id         uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id    uuid NOT NULL REFERENCES public.users (id) ON DELETE CASCADE,
    dow        smallint NOT NULL CHECK (dow BETWEEN 0 AND 6),
    start_min  smallint NOT NULL CHECK (start_min BETWEEN 0 AND 1439),
    end_min    smallint NOT NULL CHECK (end_min BETWEEN 1 AND 1440),
    is_active  boolean NOT NULL DEFAULT true,
    created_at timestamptz NOT NULL DEFAULT now(),
    updated_at timestamptz NOT NULL DEFAULT now(),
    CONSTRAINT valid_time_range CHECK (start_min < end_min),
    UNIQUE (user_id, dow, start_min)
);

CREATE INDEX idx_ravts_user ON public.referee_available_time_slots (user_id);
CREATE INDEX idx_ravts_dow_time
    ON public.referee_available_time_slots (dow, start_min, end_min)
    WHERE is_active;

-- Date ranges during which the referee is unavailable (holidays, etc.).
CREATE TABLE public.referee_blocked_dates (
    id         uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id    uuid NOT NULL REFERENCES public.users (id) ON DELETE CASCADE,
    start_date date NOT NULL,
    end_date   date NOT NULL,
    reason     text,
    created_at timestamptz NOT NULL DEFAULT now(),
    updated_at timestamptz NOT NULL DEFAULT now(),
    CONSTRAINT valid_date_range CHECK (end_date >= start_date)
);

CREATE INDEX idx_rbd_user ON public.referee_blocked_dates (user_id);

-- Per-referee availability knobs (1:1). Forward-built now; the edit UI arrives
-- later. max_concurrent_assignments NULL means "no cap".
CREATE TABLE public.referee_availability (
    user_id                   uuid PRIMARY KEY REFERENCES public.users (id) ON DELETE CASCADE,
    is_accepting              boolean NOT NULL DEFAULT true,
    max_concurrent_assignments int,
    created_at                timestamptz NOT NULL DEFAULT now(),
    updated_at                timestamptz NOT NULL DEFAULT now()
);
