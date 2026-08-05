-- Typed singleton matching configuration (one row, id = true). Replaces the
-- old key/value matching_time_config. The ordering invariant encodes the
-- lifecycle windows: a request is open for open_deadline_hours; a referee may
-- cancel up to cancel_deadline_hours before the task due date; and matching
-- stops rematching once within rematch_cutoff_hours of the due date. Hence
-- open_deadline_hours > rematch_cutoff_hours > cancel_deadline_hours.
CREATE TABLE public.matching_config (
    id                    boolean PRIMARY KEY DEFAULT true CHECK (id = true),
    open_deadline_hours   int NOT NULL,
    cancel_deadline_hours int NOT NULL CHECK (cancel_deadline_hours > 0),
    rematch_cutoff_hours  int NOT NULL,
    max_referees_per_task int NOT NULL DEFAULT 2 CHECK (max_referees_per_task >= 1),
    point_cost_per_request int NOT NULL DEFAULT 1 CHECK (point_cost_per_request >= 0),
    updated_at            timestamptz NOT NULL DEFAULT now(),
    CONSTRAINT ordering_invariant CHECK (
        open_deadline_hours > rematch_cutoff_hours
        AND rematch_cutoff_hours > cancel_deadline_hours
    )
);
