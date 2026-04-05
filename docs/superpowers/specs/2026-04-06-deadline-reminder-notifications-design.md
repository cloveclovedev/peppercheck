# Deadline Reminder Notifications Design

Issues: #310, #311
Parent issue: #257
Audit document: PR #306

## Overview

Implement pre-deadline reminder notifications for evidence submission (Tasker), judgement (Referee), and auto-confirm (Tasker). These were identified as GAP-1 and GAP-2 in the notification system audit.

Unlike existing timeout notifications which fire after a deadline and trigger state transitions, reminders fire before a deadline and are purely informational — they do not change any domain state.

## Architecture: Hybrid Approach

A shared helper function handles the common logic (idempotency check via sent_log + notify_event dispatch), while per-type detection functions handle the type-specific query and deadline calculation.

```
cron (every minute)
  ├→ detect_evidence_deadline_warnings()
  ├→ detect_judgement_deadline_warnings()
  └→ detect_auto_confirm_deadline_warnings()
       └→ send_deadline_reminder()           ← shared helper
            ├→ INSERT notification_sent_log (ON CONFLICT DO NOTHING)
            └→ notify_event()
                └→ Edge Function → FCM
```

## Database Schema

### notification_settings (new table)

Stores per-user reminder preferences. Separate from `profiles` to keep notification concerns isolated.

```sql
CREATE TABLE public.notification_settings (
  user_id                       UUID PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
  evidence_reminder_minutes     INTEGER[] DEFAULT '{10}',     -- Tasker. NULL = OFF
  judgement_reminder_minutes    INTEGER[] DEFAULT '{10}',     -- Referee. NULL = OFF
  auto_confirm_reminder_minutes INTEGER[] DEFAULT NULL,       -- Tasker. NULL = OFF (default)
  evidence_reminder_even_if_submitted BOOLEAN DEFAULT false,  -- future: remind even after submission
  created_at                    TIMESTAMPTZ DEFAULT now(),
  updated_at                    TIMESTAMPTZ DEFAULT now()
);
```

- Array columns allow multiple reminders per type (e.g., `'{60, 10}'` for 1h and 10min before)
- `NULL` or empty array = reminders disabled for that type
- A row is auto-inserted on user creation with default values
- `evidence_reminder_even_if_submitted`: reserved for future use. When `true`, evidence deadline reminders also fire when evidence is already submitted (as a modification deadline reminder). MVP: always `false`.

### notification_sent_log (new table)

Ensures each reminder is sent exactly once per judgement + key + timing combination.

```sql
CREATE TABLE public.notification_sent_log (
  id               UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  judgement_id     UUID NOT NULL REFERENCES public.judgements(id) ON DELETE CASCADE,
  notification_key TEXT NOT NULL,
  reminder_minutes INTEGER NOT NULL,
  sent_at          TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE UNIQUE INDEX idx_notification_sent_log_unique
  ON public.notification_sent_log (judgement_id, notification_key, reminder_minutes);
```

Idempotency is enforced by the unique index: `INSERT ... ON CONFLICT DO NOTHING`. If the row already exists, the helper returns without sending.

## SQL Functions

### send_deadline_reminder() — shared helper

```
send_deadline_reminder(
  p_judgement_id     UUID,
  p_user_id          UUID,
  p_notification_key TEXT,
  p_reminder_minutes INTEGER,
  p_deadline         TIMESTAMPTZ,
  p_task_id          UUID,
  p_task_title       TEXT
) RETURNS void
```

1. `INSERT INTO notification_sent_log (judgement_id, notification_key, reminder_minutes) VALUES (...) ON CONFLICT DO NOTHING`
2. Check if insert succeeded (row count = 1). If not, return (already sent).
3. Format `p_deadline` as localized time string for `body_loc_args`.
4. Call `notify_event()` with:
   - `user_ids`: `ARRAY[p_user_id]`
   - `notification_key`: `p_notification_key`
   - `body_loc_args`: `ARRAY[p_task_title, formatted_deadline_time]`
   - `data`: `jsonb_build_object('task_id', p_task_id)`

### detect_evidence_deadline_warnings()

- Target: `judgements.status = 'awaiting_evidence'` AND no evidence submitted (`task_evidences.id IS NULL`)
- Deadline: `tasks.due_date`
- Condition: `NOW() >= tasks.due_date - (reminder_minutes || ' minutes')::INTERVAL`
- Recipient: `tasks.user_id` (Tasker)
- Notification key: `notification_evidence_deadline_warning_tasker`
- Settings column: `notification_settings.evidence_reminder_minutes`

Query pattern:
1. JOIN `judgements` → `task_referee_requests` → `tasks`
2. LEFT JOIN `task_evidences` (filter: `te.id IS NULL`)
3. JOIN `notification_settings` on `tasks.user_id`
4. `CROSS JOIN LATERAL unnest(evidence_reminder_minutes) AS reminder_minutes`
5. LEFT JOIN `notification_sent_log` (filter: not yet sent)
6. WHERE time condition met AND sent_log row is NULL
7. Loop: call `send_deadline_reminder()` for each row

### detect_judgement_deadline_warnings()

- Target: `judgements.status = 'in_review'`
- Deadline: `tasks.due_date + INTERVAL '3 hours'`
- Condition: `NOW() >= (tasks.due_date + INTERVAL '3 hours') - (reminder_minutes || ' minutes')::INTERVAL`
- Recipient: `task_referee_requests.matched_referee_id` (Referee)
- Notification key: `notification_judgement_deadline_warning_referee`
- Settings column: `notification_settings.judgement_reminder_minutes`

Note: The `status = 'in_review'` guard ensures this only fires when evidence has been submitted and judgement has not been completed. No separate check is needed for these conditions.

### detect_auto_confirm_deadline_warnings()

- Target: `judgements.is_confirmed = false` AND `status IN ('approved', 'rejected', 'review_timeout', 'evidence_timeout')`
- Deadline: `tasks.due_date + INTERVAL '3 days'` (hardcoded; parameterization tracked in #331)
- Condition: `NOW() >= (tasks.due_date + INTERVAL '3 days') - (reminder_minutes || ' minutes')::INTERVAL`
- Recipient: `tasks.user_id` (Tasker)
- Notification key: `notification_auto_confirm_deadline_warning_tasker`
- Settings column: `notification_settings.auto_confirm_reminder_minutes`

Note: Default `NULL` means this does not fire unless the user explicitly enables it.

### Cron registration

Three separate jobs, all running every minute:

```sql
SELECT cron.schedule('detect-evidence-deadline-warnings',   '* * * * *', $$SELECT public.detect_evidence_deadline_warnings()$$);
SELECT cron.schedule('detect-judgement-deadline-warnings',   '* * * * *', $$SELECT public.detect_judgement_deadline_warnings()$$);
SELECT cron.schedule('detect-auto-confirm-deadline-warnings','* * * * *', $$SELECT public.detect_auto_confirm_deadline_warnings()$$);
```

## Notification Keys and Text

### New notification keys

All keys follow the naming convention: `notification_{event}_{recipient}`.

`body_loc_args`: `%1$s` = task title, `%2$s` = deadline time.

### notification_evidence_deadline_warning_tasker

| | EN | JA |
|---|---|---|
| title | `Evidence deadline approaching` | `エビデンス提出期限が近づいています` |
| body | `The evidence deadline for "%1$s" is %2$s. Don't forget to submit!` | `「%1$s」のエビデンス提出期限は%2$sです。忘れずに提出してください！` |

### notification_judgement_deadline_warning_referee

| | EN | JA |
|---|---|---|
| title | `Judgement deadline approaching` | `判定期限が近づいています` |
| body | `The judgement deadline for "%1$s" is %2$s. Please complete your review.` | `「%1$s」の判定期限は%2$sです。判定を完了してください。` |

### notification_auto_confirm_deadline_warning_tasker

| | EN | JA |
|---|---|---|
| title | `Task confirmation deadline approaching` | `タスクの確認期限が近づいています` |
| body | `The result for "%1$s" will be auto-confirmed at %2$s.` | `「%1$s」の結果が%2$sに自動確認されます。` |

### 5-layer implementation

Each key requires entries in all 5 layers:

1. **SQL**: `send_deadline_reminder()` passes the key to `notify_event()`
2. **Flutter `notification_text_resolver.dart`**: Add switch/case for each key
3. **Flutter `ja.i18n.json`**: Add `_title` / `_body` entries in `notification` section
4. **Android `strings.xml`** (en + ja): Add `_title` / `_body` string resources
5. **iOS `Localizable.strings`** (en + ja): Add `_title` / `_body` entries

After editing `ja.i18n.json`, regenerate slang: `cd peppercheck_flutter && dart run build_runner build`

## File Placement

All new files go under `supabase/schemas/notification/`:

```
supabase/schemas/notification/
├── tables/
│   ├── user_fcm_tokens.sql              (existing)
│   ├── notification_settings.sql         (new)
│   └── notification_sent_log.sql         (new)
├── functions/
│   ├── notify_event.sql                  (existing)
│   ├── send_deadline_reminder.sql        (new)
│   ├── detect_evidence_deadline_warnings.sql    (new)
│   ├── detect_judgement_deadline_warnings.sql    (new)
│   └── detect_auto_confirm_deadline_warnings.sql (new)
└── cron/
    ├── cron_detect_evidence_deadline_warnings.sql   (new)
    ├── cron_detect_judgement_deadline_warnings.sql   (new)
    └── cron_detect_auto_confirm_deadline_warnings.sql (new)
```

New schema files must be registered in `supabase/config.toml` under `[db.migrations]`.

## Testing

### Unit tests (pgTAP, `supabase/tests/database/`)

**test_deadline_reminders.sql**:
- Normal send: `notification_sent_log` record is inserted after detection runs
- Idempotency: running detection twice produces only one `notification_sent_log` row
- Multiple reminders: `'{60, 10}'` setting creates separate log entries for each timing
- NULL setting (OFF): no reminder fires when setting is NULL
- Wrong status: evidence reminder does not fire for non-`awaiting_evidence` status
- Before deadline: no reminder fires when deadline minus reminder_minutes has not been reached

**test_notification_settings.sql**:
- Default row auto-inserted on user creation
- Array update is correctly persisted

### Manual test snippet (`supabase/snippets/`)

**snippet_deadline_reminder_setup.sql**:
- Creates a task + judgement with `due_date` set to 11 minutes from now
- Allows emulator-based verification that push notification arrives within ~1 minute

### Verification checklist

1. DB reset: full migration history applies cleanly
2. All existing pgTAP tests pass (no regressions)
3. New pgTAP tests pass
4. Emulator receives push notification for each reminder type

## Scope

### In scope (MVP)

- `notification_settings` table with default values and auto-insert
- `notification_sent_log` table
- `send_deadline_reminder()` shared helper
- 3 detection functions + 3 cron jobs (every minute)
- 3 notification keys x 5 layers
- pgTAP tests + manual test snippet
- `evidence_reminder_even_if_submitted` column (reserved, `DEFAULT false`)

### Out of scope (separate issues)

- Flutter settings UI for configuring reminder minutes and ON/OFF toggle
- Enabling `evidence_reminder_even_if_submitted` via UI
- Default-enabling auto-confirm reminders
- Notification text refinement beyond initial version
- Parameterize hardcoded judgement timeout (`3 hours`) and auto-confirm grace period (`3 days`) into a config table → #331
