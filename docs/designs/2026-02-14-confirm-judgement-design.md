# Confirm Judgement & Binary Rating Design

## Context

Part of Issue #72 (Epic: Flutter Android) MVP Features — implementing the Confirm functionality.
Follows the lifecycle defined in `developer-docs/modules/ROOT/examples/features/task/lifecycle.pu`.
Allows a Tasker to confirm a judgement and rate the Referee.

## Scope

- **In scope:** Manual Confirm & Rate from `approved` / `rejected` status only
- **Out of scope:** Auto-Confirm (System), judgement_timeout confirm, evidence_timeout confirm, Billing Trigger
- Backend (Supabase) only. Flutter UI will be a separate PR.

## Decision: Binary Rating System

Replacing the 1-5 numeric scale with Binary (positive/negative) + optional comment.

### Rationale

- 5-star systems suffer from grade inflation, compressing to 4.5-5.0 range (observed on Uber, Airbnb)
- Binary yields higher completion rates (Netflix saw +200% after switching from stars)
- More statistically reliable with small sample sizes (suitable for a small marketplace)
- Nature 2025 study (100K+ jobs): switching to binary eliminated a 9% racial earnings gap in gig work
- Referee evidence review quality is fundamentally a yes/no assessment

### Storage

Store as `is_positive boolean`, aggregate as positive percentage.
Mapping binary to 1/5 numeric is not recommended (averages get confused with star ratings).

## Schema Changes

### rating_histories table

```sql
-- rating_type enum defined at the top of rating_histories.sql
CREATE TYPE rating_type AS ENUM ('tasker', 'referee');

CREATE TABLE rating_histories (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    judgement_id uuid NOT NULL REFERENCES judgements(id),
    ratee_id uuid REFERENCES profiles(id) ON DELETE SET NULL,
    rater_id uuid REFERENCES profiles(id),
    rating_type rating_type NOT NULL,
    is_positive boolean NOT NULL,
    comment text,
    created_at timestamptz DEFAULT now(),
    CONSTRAINT unique_rating_per_judgement UNIQUE (judgement_id, rating_type)
);
```

Changes from current:
- `rating numeric` -> `is_positive boolean NOT NULL`
- `task_id uuid` column removed (derivable via `judgement_id -> task_referee_requests.task_id`)
- `rating_type text` -> `rating_type` enum
- `rating_check` constraint removed (boolean is self-constraining)
- Unique constraint: `(rater_id, ratee_id, judgement_id)` -> `(judgement_id, rating_type)`

### user_ratings table

```sql
CREATE TABLE user_ratings (
    user_id uuid PRIMARY KEY REFERENCES profiles(id) ON DELETE CASCADE,
    tasker_positive_count integer DEFAULT 0,
    tasker_total_count integer DEFAULT 0,
    tasker_positive_pct numeric DEFAULT 0,
    referee_positive_count integer DEFAULT 0,
    referee_total_count integer DEFAULT 0,
    referee_positive_pct numeric DEFAULT 0,
    created_at timestamptz DEFAULT now(),
    updated_at timestamptz DEFAULT now()
);
```

Changes from current:
- `tasker_rating numeric` / `tasker_rating_count integer` -> `tasker_positive_count` / `tasker_total_count` / `tasker_positive_pct`
- Same for referee columns

## RPC Changes

### confirm_judgement_and_rate_referee (modified)

```sql
confirm_judgement_and_rate_referee(
  p_judgement_id uuid,
  p_is_positive boolean,
  p_comment text  -- optional
) RETURNS void
```

Logic:
1. Validate caller is tasker (`auth.uid()` = `tasks.tasker_id` via judgement -> task_referee_requests -> tasks)
2. Validate judgement status is `approved` or `rejected`
3. Idempotency: if `is_confirmed` already TRUE, return early
4. Insert into `rating_histories` (ratee_id = referee, rater_id = `auth.uid()`, rating_type = 'referee')
5. Update `judgements.is_confirmed = TRUE`

Changes from current:
- `p_rating integer` -> `p_is_positive boolean`
- `p_ratee_id uuid` removed (derived from judgement)
- `p_task_id uuid` removed (derived from judgement)
- `rater_id` set directly in RPC (previously set by trigger)

## Trigger Changes

### Modified Functions

| Function | Change |
|----------|--------|
| `update_user_ratings()` | AVG(rating) -> positive percentage calculation |
| `handle_judgement_confirmed()` (renamed from `handle_judgement_confirmation`) | Add notification: `notify_event(referee_id, 'notification_judgement_confirmed', ...)` when status is approved/rejected |
| `handle_evidence_timeout_confirmed()` (renamed from `handle_evidence_timeout_confirmation`) | Rename only |
| `auto_score_timeout_referee()` | `rating = 0` -> `is_positive = false`, remove task_id reference |

### New Triggers (function + trigger definition in one file)

| Trigger File | Logic |
|-------------|-------|
| `on_judgement_confirmed_close_request.sql` | When `is_confirmed` FALSE->TRUE OR `is_evidence_timeout_confirmed` FALSE->TRUE: set `task_referee_requests.status = 'closed'` |
| `on_all_requests_closed_close_task.sql` | When `task_referee_requests.status` changes to 'closed': if all requests for the task are closed, set `tasks.status = 'closed'` |

### Deleted

| File | Reason |
|------|--------|
| `set_rater_id.sql` (function) | Logic moved into RPC |
| `on_rating_histories_insert_set_rater_id.sql` (trigger) | Same |
| `on_judgements_confirmed_close_task.sql` (trigger) | Split into 2 triggers |
| `close_task_if_all_judgements_confirmed.sql` (function) | Same |

## Notification

On `is_confirmed` FALSE -> TRUE:
- If judgement status is `approved` or `rejected`: send `notification_judgement_confirmed` to referee with rating info (is_positive, comment)
- If judgement status is `review_timeout`: no notification (out of scope for this PR)
- Evidence timeout: handled separately via `is_evidence_timeout_confirmed`

## RLS Policy Changes

### rating_histories SELECT policy

```sql
-- Changed from task_id-based to judgement_id-based JOIN
CREATE POLICY "Rating Histories: select if task participant" ON rating_histories
FOR SELECT TO authenticated
USING (
  EXISTS (
    SELECT 1 FROM task_referee_requests trr
    JOIN tasks t ON t.id = trr.task_id
    WHERE trr.id = rating_histories.judgement_id
    AND (t.tasker_id = auth.uid() OR trr.matched_referee_id = auth.uid())
  )
);
```

## Close Flow (Updated)

```
Judgement confirmed (is_confirmed or is_evidence_timeout_confirmed)
  -> task_referee_requests.status = 'closed'
    -> If ALL requests for task are closed -> tasks.status = 'closed'
```

This replaces the previous direct judgement -> task close path.

## Out of Scope (Future PRs)

- Auto-Confirm (System Auto-Confirm after DueDate + N days)
- Judgement Timeout confirm
- Evidence Timeout confirm
- Billing Trigger integration
- Flutter UI for confirm
- Wilson score ranking for user sorting
