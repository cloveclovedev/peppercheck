# Evidence Timeout Settlement Design

## Context

Issue #72 continuation. The confirm + reward flow for normal judgements (approved/rejected) is complete. Next step: handle evidence timeout — when a tasker fails to submit evidence by the due date.

### Current State

- `detect_and_handle_evidence_timeouts()` exists and updates judgement status to `evidence_timeout`, but is not scheduled via cron
- `confirm_evidence_timeout_from_referee()` exists but only sets `is_evidence_timeout_confirmed = true` with no point settlement
- `handle_evidence_timeout_confirmed()` trigger exists but has `NULL;` body (billing was removed)
- Task closure is triggered when all requests are closed (`on_all_requests_closed_close_task`), which conflates referee-side and tasker-side completion

### Problem

1. Evidence timeouts are never detected (no cron job)
2. No point settlement occurs on evidence timeout (tasker points stay locked, referee gets no reward)
3. If we auto-settle and auto-close the request, the task also closes, and the tasker never sees what happened

## Design

### Key Principle: Separate referee-side and tasker-side completion

- **Referee side** (`is_evidence_timeout_confirmed`): Referee did nothing wrong; auto-complete their side
- **Tasker side** (`is_confirmed`): Tasker must acknowledge the timeout before the task disappears

### Flow

```
cron (every 5 minutes)
  detect_and_handle_evidence_timeouts()
    └─ UPDATE status = 'evidence_timeout'
         WHERE status = 'awaiting_evidence'
         AND now() > task.due_date
         AND no evidence submitted

trigger: on status change to 'evidence_timeout'
  ├─ consume_points(tasker)           # settle locked points
  ├─ grant_reward(referee)            # reward for the work slot
  ├─ is_evidence_timeout_confirmed = true
  │    └─ existing trigger → request close (referee home cleared)
  └─ notify(referee: reward granted, tasker: timeout occurred)

tasker sees task on home screen (is_confirmed = false)
  └─ tasker confirms evidence timeout
       └─ is_confirmed = true
            └─ new trigger: if all judgements confirmed → task close
```

### Changes Required

#### 1. Schedule cron job

```sql
SELECT cron.schedule(
  'detect-evidence-timeouts',
  '*/5 * * * *',
  $$SELECT public.detect_and_handle_evidence_timeouts()$$
);
```

#### 2. New trigger: settle on evidence_timeout status change

Create a trigger on `judgements` that fires when `status` changes to `evidence_timeout`. The trigger function will:

1. Look up tasker_id, referee_id, matching_strategy via joins
2. Call `consume_points(tasker_id, cost, 'matching_settled', ...)`
3. Call `grant_reward(referee_id, cost, 'evidence_timeout', ...)`
4. Set `is_evidence_timeout_confirmed = true` (cascades to close request via existing trigger)
5. Notify both parties

#### 3. Modify `handle_evidence_timeout_confirmed()` trigger

The existing trigger currently has `NULL;` body. Options:
- Leave as-is (it's harmless) since settlement is handled by the status change trigger
- Or remove it entirely if the status change trigger sets `is_evidence_timeout_confirmed`

Decision: Leave the existing trigger as-is. The request closure is handled by `on_judgement_confirmed_close_request` trigger which already fires on `is_evidence_timeout_confirmed` change.

#### 4. Tasker confirm function for evidence timeout

New function `confirm_evidence_timeout(p_judgement_id uuid)`:
- Validates caller is the tasker
- Validates judgement status is `evidence_timeout`
- Sets `is_confirmed = true`
- No point operations needed (already settled by trigger)
- No rating needed (evidence timeout is tasker's fault, not referee's)

#### 5. Change task closure condition

**Current**: `on_all_requests_closed_close_task` — task closes when all requests are `closed`

**New**: `on_all_judgements_confirmed_close_task` — task closes when all judgements have `is_confirmed = true`

```sql
CREATE OR REPLACE FUNCTION public.close_task_if_all_judgements_confirmed() RETURNS trigger
AS $$
DECLARE
    v_task_id uuid;
BEGIN
    SELECT trr.task_id INTO v_task_id
    FROM public.task_referee_requests trr
    WHERE trr.id = NEW.id;

    PERFORM * FROM public.tasks WHERE id = v_task_id FOR UPDATE;

    IF NOT EXISTS (
        SELECT 1 FROM public.judgements j
        JOIN public.task_referee_requests trr ON j.id = trr.id
        WHERE trr.task_id = v_task_id AND j.is_confirmed = false
    ) THEN
        UPDATE public.tasks
        SET status = 'closed'::public.task_status
        WHERE id = v_task_id;
    END IF;

    RETURN NEW;
END;
$$;

CREATE OR REPLACE TRIGGER on_all_judgements_confirmed_close_task
    AFTER UPDATE ON public.judgements
    FOR EACH ROW
    WHEN (NEW.is_confirmed = true AND OLD.is_confirmed = false)
    EXECUTE FUNCTION public.close_task_if_all_judgements_confirmed();
```

Drop the old `on_all_requests_closed_close_task` trigger.

#### 6. Delete `confirm_evidence_timeout_from_referee()`

This function is no longer needed since the referee doesn't need to manually confirm. Settlement and request closure happen automatically via trigger.

#### 7. Tests

- Evidence timeout detection: status changes to `evidence_timeout` when due_date passed and no evidence
- Settlement trigger: tasker points consumed, referee reward granted on status change
- Request auto-close: request status becomes `closed` after evidence timeout
- Task NOT auto-closed: task stays `open` until tasker confirms
- Tasker confirm: `is_confirmed = true` → task closes
- Idempotency: calling detect function again doesn't double-settle

## Out of Scope

- Flutter UI for tasker confirm of evidence timeout (separate PR)
- Review timeout handling (separate PR)
- Auto-confirm after N days (separate PR)
- Stripe payout (separate feature)

## Trigger Chain Summary

```
Normal flow:
  tasker confirms → confirm_judgement_and_rate_referee()
    → is_confirmed = true
    → close_referee_request_on_confirmed (request close)
    → close_task_if_all_judgements_confirmed (task close)

Evidence timeout flow:
  cron → status = 'evidence_timeout'
    → NEW trigger: settle points + grant reward + set is_evidence_timeout_confirmed = true
      → close_referee_request_on_confirmed (request close)
      → task stays open (is_confirmed still false)
  tasker confirms later → confirm_evidence_timeout()
    → is_confirmed = true
    → close_task_if_all_judgements_confirmed (task close)
```
