-- Tasker-authored tasks. A task starts as a 'draft' the tasker can edit or
-- delete; publishing flips it to 'open' (atomically with its referee_requests)
-- and it becomes 'closed' once the lifecycle completes (4c). tasker_id is
-- nullable ON DELETE SET NULL so the account-deletion saga (Phase 6) can null
-- the author without cascading away the task history. updated_at is maintained
-- by the Go store (updated_at = now() on each UPDATE), not a DB trigger.
CREATE TYPE public.task_status AS ENUM ('draft', 'open', 'closed');

CREATE TABLE public.tasks (
    id          uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    tasker_id   uuid REFERENCES public.users (id) ON DELETE SET NULL,
    title       text NOT NULL,
    description text,
    criteria    text,
    due_date    timestamptz,
    status      public.task_status NOT NULL DEFAULT 'draft',
    created_at  timestamptz NOT NULL DEFAULT now(),
    updated_at  timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX idx_tasks_tasker_status ON public.tasks (tasker_id, status);
