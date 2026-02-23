# Reopen & Evidence Update Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Allow Taskers to edit evidence during `in_review` and resubmit once after rejection.

**Architecture:** Three RPCs: `submit_evidence` (initial, simplified), `update_evidence` (edit in-place during in_review), `resubmit_evidence` (edit in-place + judgement transition after rejection). Two triggers collaborate for notifications: evidence trigger skips when judgement is `rejected`, judgement trigger handles resubmission notification on `rejected → in_review`.

**Tech Stack:** PostgreSQL (Supabase), Flutter/Dart (Riverpod, Freezed), Slang i18n, pgTAP

---

### Task 1: Remove `reopen_judgement` and simplify `submit_evidence`

**Files:**
- Delete: `supabase/schemas/judgement/functions/reopen_judgement.sql`
- Modify: `supabase/config.toml:135`
- Modify: `supabase/schemas/evidence/functions/submit_evidence.sql`

**Step 1: Delete `reopen_judgement.sql`**

```bash
rm supabase/schemas/judgement/functions/reopen_judgement.sql
```

**Step 2: Remove from `config.toml`**

In `supabase/config.toml`, remove line 135:

```toml
  "./schemas/judgement/functions/reopen_judgement.sql",
```

**Step 3: Simplify `submit_evidence.sql`**

Replace the authorization check (lines 36-50) to only accept `awaiting_evidence`:

```sql
    -- 1.2 Authorization & Status Check
    IF NOT EXISTS (
        SELECT 1
        FROM public.tasks t
        JOIN public.task_referee_requests trr ON trr.task_id = t.id
        JOIN public.judgements j ON j.id = trr.id
        WHERE t.id = p_task_id
          AND t.tasker_id = auth.uid()
          AND j.status = 'awaiting_evidence'
    ) THEN
        RAISE EXCEPTION 'Not authorized or task not in valid state for evidence submission';
    END IF;
```

Replace the judgement update (lines 91-103) to only transition from `awaiting_evidence`:

```sql
    -- 3. Update Judgements
    UPDATE public.judgements j
    SET
        status = 'in_review',
        updated_at = v_now
    FROM public.task_referee_requests trr
    WHERE
        j.id = trr.id
        AND trr.task_id = p_task_id
        AND j.status = 'awaiting_evidence';
```

**Step 4: Commit**

```bash
git add -A && git commit -m "refactor: remove reopen_judgement and simplify submit_evidence"
```

---

### Task 2: Create `update_evidence` RPC

**Files:**
- Create: `supabase/schemas/evidence/functions/update_evidence.sql`
- Modify: `supabase/config.toml` (add after `submit_evidence.sql` entry, line 125)
- Create: `supabase/tests/database/update_evidence.test.sql`

**Step 1: Write the test**

Create `supabase/tests/database/update_evidence.test.sql`. Use pgTAP format with `supabase test db`:

```sql
begin;
create extension if not exists pgtap with schema extensions;
select plan(9);

-- [Setup] Create test users
delete from auth.users where id in (
  '11111111-1111-1111-1111-111111111111',
  '22222222-2222-2222-2222-222222222222'
);

insert into auth.users (id, email, instance_id, aud, role, encrypted_password, email_confirmed_at, created_at, updated_at)
values
  ('11111111-1111-1111-1111-111111111111', 'tasker@test.com', '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated', crypt('password123', gen_salt('bf')), now(), now(), now()),
  ('22222222-2222-2222-2222-222222222222', 'referee@test.com', '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated', crypt('password123', gen_salt('bf')), now(), now(), now());

-- [Setup] Initialize wallets
update public.point_wallets set balance = 10, locked = 1 where user_id = '11111111-1111-1111-1111-111111111111';

-- [Setup] Create task (in_review state)
insert into public.tasks (id, tasker_id, title, status, due_date, created_at, updated_at)
values ('aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa', '11111111-1111-1111-1111-111111111111', 'Test Task', 'open', now() + interval '1 day', now(), now());

insert into public.task_referee_requests (id, task_id, matching_strategy, status, matched_referee_id, created_at, updated_at)
values ('bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb', 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa', 'standard', 'accepted', '22222222-2222-2222-2222-222222222222', now(), now());

update public.judgements set status = 'in_review' where id = 'bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb';

-- [Setup] Create existing evidence with 2 assets
insert into public.task_evidences (id, task_id, description, status, created_at, updated_at)
values ('cccccccc-cccc-cccc-cccc-cccccccccccc', 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa', 'Original description', 'ready', now(), now());

insert into public.task_evidence_assets (id, evidence_id, file_url, file_size_bytes, content_type, created_at, processing_status, public_url)
values
  ('dddddddd-dddd-dddd-dddd-dddddddddddd', 'cccccccc-cccc-cccc-cccc-cccccccccccc', 'evidence/old1.jpg', 1024, 'image/jpeg', now(), 'completed', 'https://example.com/old1.jpg'),
  ('eeeeeeee-eeee-eeee-eeee-eeeeeeeeeeee', 'cccccccc-cccc-cccc-cccc-cccccccccccc', 'evidence/old2.jpg', 2048, 'image/jpeg', now(), 'completed', 'https://example.com/old2.jpg');

-- Test 1: Update description and swap assets
select set_config('request.jwt.claims', '{"sub": "11111111-1111-1111-1111-111111111111"}', true);

select lives_ok(
  $$select public.update_evidence(
    'cccccccc-cccc-cccc-cccc-cccccccccccc',
    'Updated description',
    '[{"file_url": "evidence/new1.jpg", "file_size_bytes": 3072, "content_type": "image/jpeg", "public_url": "https://example.com/new1.jpg"}]'::jsonb,
    ARRAY['dddddddd-dddd-dddd-dddd-dddddddddddd']::uuid[]
  )$$,
  'Test 1: update_evidence should succeed'
);

select is(
  (select description from public.task_evidences where id = 'cccccccc-cccc-cccc-cccc-cccccccccccc'),
  'Updated description',
  'Test 1: description should be updated'
);

select is(
  (select count(*)::int from public.task_evidence_assets where evidence_id = 'cccccccc-cccc-cccc-cccc-cccccccccccc'),
  2,
  'Test 1: should have 2 assets (removed 1, added 1, kept 1)'
);

select is(
  (select status from public.judgements where id = 'bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb')::text,
  'in_review',
  'Test 1: judgement should remain in_review'
);

-- Test 2: Cannot update when status is not in_review
update public.judgements set status = 'approved' where id = 'bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb';
select set_config('request.jwt.claims', '{"sub": "11111111-1111-1111-1111-111111111111"}', true);

select throws_ok(
  $$select public.update_evidence('cccccccc-cccc-cccc-cccc-cccccccccccc', 'Should not work', null, null)$$,
  'Not authorized or evidence not in valid state for update',
  'Test 2: update blocked when not in_review'
);

-- Test 3: Non-tasker cannot update
update public.judgements set status = 'in_review' where id = 'bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb';
select set_config('request.jwt.claims', '{"sub": "22222222-2222-2222-2222-222222222222"}', true);

select throws_ok(
  $$select public.update_evidence('cccccccc-cccc-cccc-cccc-cccccccccccc', 'Referee attempt', null, null)$$,
  'Not authorized or evidence not in valid state for update',
  'Test 3: non-tasker update blocked'
);

-- Test 4: Update with only description (no asset changes)
select set_config('request.jwt.claims', '{"sub": "11111111-1111-1111-1111-111111111111"}', true);

select lives_ok(
  $$select public.update_evidence('cccccccc-cccc-cccc-cccc-cccccccccccc', 'Only description changed', null, null)$$,
  'Test 4: description-only update should succeed'
);

select is(
  (select description from public.task_evidences where id = 'cccccccc-cccc-cccc-cccc-cccccccccccc'),
  'Only description changed',
  'Test 4: description should be updated'
);

select is(
  (select count(*)::int from public.task_evidence_assets where evidence_id = 'cccccccc-cccc-cccc-cccc-cccccccccccc'),
  2,
  'Test 4: asset count should remain 2'
);

select * from finish();
rollback;
```

**Step 2: Run test to verify it fails**

```bash
supabase test db supabase/tests/database/update_evidence.test.sql
```

Expected: FAIL — `function public.update_evidence does not exist`

**Step 3: Write `update_evidence.sql`**

Create `supabase/schemas/evidence/functions/update_evidence.sql`:

```sql
CREATE OR REPLACE FUNCTION public.update_evidence(
    p_evidence_id UUID,
    p_description TEXT,
    p_assets_to_add JSONB DEFAULT NULL,
    p_asset_ids_to_remove UUID[] DEFAULT NULL
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO ''
AS $function$
DECLARE
    v_task_id UUID;
    v_asset JSONB;
    v_now TIMESTAMP WITH TIME ZONE;
BEGIN
    v_now := NOW();

    -- 1. Validation
    IF p_description IS NULL OR trim(p_description) = '' THEN
        RAISE EXCEPTION 'Description is required';
    END IF;

    -- 2. Authorization & Status Check
    -- Must be tasker AND judgement must be in_review
    SELECT te.task_id INTO v_task_id
    FROM public.task_evidences te
    JOIN public.tasks t ON t.id = te.task_id
    JOIN public.task_referee_requests trr ON trr.task_id = t.id
    JOIN public.judgements j ON j.id = trr.id
    WHERE te.id = p_evidence_id
      AND t.tasker_id = auth.uid()
      AND j.status = 'in_review';

    IF v_task_id IS NULL THEN
        RAISE EXCEPTION 'Not authorized or evidence not in valid state for update';
    END IF;

    -- 3. Update description
    UPDATE public.task_evidences
    SET description = p_description,
        updated_at = v_now
    WHERE id = p_evidence_id;

    -- 4. Remove specified assets
    IF p_asset_ids_to_remove IS NOT NULL AND array_length(p_asset_ids_to_remove, 1) > 0 THEN
        DELETE FROM public.task_evidence_assets
        WHERE id = ANY(p_asset_ids_to_remove)
          AND evidence_id = p_evidence_id;
    END IF;

    -- 5. Add new assets
    IF p_assets_to_add IS NOT NULL AND jsonb_array_length(p_assets_to_add) > 0 THEN
        FOR v_asset IN SELECT * FROM jsonb_array_elements(p_assets_to_add)
        LOOP
            INSERT INTO public.task_evidence_assets (
                evidence_id,
                file_url,
                file_size_bytes,
                content_type,
                created_at,
                processing_status,
                public_url
            ) VALUES (
                p_evidence_id,
                v_asset->>'file_url',
                (v_asset->>'file_size_bytes')::BIGINT,
                v_asset->>'content_type',
                v_now,
                'completed',
                v_asset->>'public_url'
            );
        END LOOP;
    END IF;

    RETURN jsonb_build_object(
        'success', true,
        'evidence_id', p_evidence_id
    );

EXCEPTION
    WHEN OTHERS THEN
        RAISE EXCEPTION 'Failed to update evidence: %', SQLERRM;
END;
$function$;
```

**Step 4: Register in `config.toml`**

Add after `"./schemas/evidence/functions/submit_evidence.sql"` (line 125):

```toml
  "./schemas/evidence/functions/update_evidence.sql",
```

**Step 5: Reset DB and run test**

```bash
./scripts/db-reset-and-clear-android-emulators-cache.sh
supabase test db supabase/tests/database/update_evidence.test.sql
```

Expected: All 9 tests PASS

**Step 6: Commit**

```bash
git add -A && git commit -m "feat: add update_evidence RPC with pgTAP tests"
```

---

### Task 3: Create `resubmit_evidence` RPC

**Files:**
- Create: `supabase/schemas/evidence/functions/resubmit_evidence.sql`
- Modify: `supabase/config.toml` (add after `update_evidence.sql` entry)
- Create: `supabase/tests/database/resubmit_evidence.test.sql`

**Step 1: Write the test**

Create `supabase/tests/database/resubmit_evidence.test.sql`:

```sql
begin;
create extension if not exists pgtap with schema extensions;
select plan(11);

-- [Setup] Create test users
delete from auth.users where id in (
  '11111111-1111-1111-1111-111111111111',
  '22222222-2222-2222-2222-222222222222'
);

insert into auth.users (id, email, instance_id, aud, role, encrypted_password, email_confirmed_at, created_at, updated_at)
values
  ('11111111-1111-1111-1111-111111111111', 'tasker@test.com', '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated', crypt('password123', gen_salt('bf')), now(), now(), now()),
  ('22222222-2222-2222-2222-222222222222', 'referee@test.com', '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated', crypt('password123', gen_salt('bf')), now(), now(), now());

-- [Setup] Initialize wallets
update public.point_wallets set balance = 10, locked = 1 where user_id = '11111111-1111-1111-1111-111111111111';

-- [Setup] Create task with future due_date
insert into public.tasks (id, tasker_id, title, status, due_date, created_at, updated_at)
values ('aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa', '11111111-1111-1111-1111-111111111111', 'Test Task', 'open', now() + interval '1 day', now(), now());

-- [Setup] Create referee request + judgement in rejected state
insert into public.task_referee_requests (id, task_id, matching_strategy, status, matched_referee_id, created_at, updated_at)
values ('bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb', 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa', 'standard', 'accepted', '22222222-2222-2222-2222-222222222222', now(), now());

update public.judgements
set status = 'rejected', comment = 'Not clear enough', reopen_count = 0
where id = 'bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb';

-- [Setup] Create existing evidence (the one that was rejected)
insert into public.task_evidences (id, task_id, description, status, created_at, updated_at)
values ('cccccccc-cccc-cccc-cccc-cccccccccccc', 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa', 'Original evidence', 'ready', now(), now());

insert into public.task_evidence_assets (id, evidence_id, file_url, file_size_bytes, content_type, created_at, processing_status, public_url)
values ('dddddddd-dddd-dddd-dddd-dddddddddddd', 'cccccccc-cccc-cccc-cccc-cccccccccccc', 'evidence/old1.jpg', 1024, 'image/jpeg', now(), 'completed', 'https://example.com/old1.jpg');

-- Test 1: Successful resubmission
select set_config('request.jwt.claims', '{"sub": "11111111-1111-1111-1111-111111111111"}', true);

select lives_ok(
  $$select public.resubmit_evidence(
    'cccccccc-cccc-cccc-cccc-cccccccccccc',
    'Updated evidence with better photos',
    '[{"file_url": "evidence/new1.jpg", "file_size_bytes": 3072, "content_type": "image/jpeg", "public_url": "https://example.com/new1.jpg"}]'::jsonb,
    ARRAY['dddddddd-dddd-dddd-dddd-dddddddddddd']::uuid[]
  )$$,
  'Test 1: resubmit_evidence should succeed'
);

select is(
  (select status from public.judgements where id = 'bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb')::text,
  'in_review',
  'Test 1: judgement status should be in_review'
);

select is(
  (select reopen_count::int from public.judgements where id = 'bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb'),
  1,
  'Test 1: reopen_count should be 1'
);

select is(
  (select description from public.task_evidences where id = 'cccccccc-cccc-cccc-cccc-cccccccccccc'),
  'Updated evidence with better photos',
  'Test 1: evidence description should be updated in-place'
);

-- Only 1 evidence record (updated, not new)
select is(
  (select count(*)::int from public.task_evidences where task_id = 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa'),
  1,
  'Test 1: should still have 1 evidence record (updated in-place)'
);

-- Test 2: Cannot resubmit twice (reopen_count >= 1)
update public.judgements set status = 'rejected', comment = 'Still not good'
where id = 'bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb';

select set_config('request.jwt.claims', '{"sub": "11111111-1111-1111-1111-111111111111"}', true);

select throws_ok(
  $$select public.resubmit_evidence(
    'cccccccc-cccc-cccc-cccc-cccccccccccc', 'Third attempt', null, null
  )$$,
  'Not authorized or evidence not in valid state for resubmission',
  'Test 2: second resubmission blocked'
);

-- Test 3: Cannot resubmit after due_date
update public.judgements set status = 'rejected', reopen_count = 0
where id = 'bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb';
update public.tasks set due_date = now() - interval '1 hour'
where id = 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa';

select set_config('request.jwt.claims', '{"sub": "11111111-1111-1111-1111-111111111111"}', true);

select throws_ok(
  $$select public.resubmit_evidence(
    'cccccccc-cccc-cccc-cccc-cccccccccccc', 'Past due attempt', null, null
  )$$,
  null,
  'Test 3: past-due resubmission blocked'
);

-- Test 4: Cannot resubmit when is_confirmed = true
update public.tasks set due_date = now() + interval '1 day'
where id = 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa';
update public.judgements set status = 'rejected', reopen_count = 0, is_confirmed = true
where id = 'bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb';

select set_config('request.jwt.claims', '{"sub": "11111111-1111-1111-1111-111111111111"}', true);

select throws_ok(
  $$select public.resubmit_evidence(
    'cccccccc-cccc-cccc-cccc-cccccccccccc', 'Confirmed attempt', null, null
  )$$,
  'Not authorized or evidence not in valid state for resubmission',
  'Test 4: confirmed resubmission blocked'
);

-- Test 5: Non-tasker cannot resubmit
update public.judgements set status = 'rejected', reopen_count = 0, is_confirmed = false
where id = 'bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb';

select set_config('request.jwt.claims', '{"sub": "22222222-2222-2222-2222-222222222222"}', true);

select throws_ok(
  $$select public.resubmit_evidence(
    'cccccccc-cccc-cccc-cccc-cccccccccccc', 'Referee attempt', null, null
  )$$,
  'Not authorized or evidence not in valid state for resubmission',
  'Test 5: non-tasker resubmission blocked'
);

-- Test 6: Description is required
select set_config('request.jwt.claims', '{"sub": "11111111-1111-1111-1111-111111111111"}', true);

select throws_ok(
  $$select public.resubmit_evidence('cccccccc-cccc-cccc-cccc-cccccccccccc', '', null, null)$$,
  'Description is required',
  'Test 6: empty description rejected'
);

select * from finish();
rollback;
```

**Step 2: Run test to verify it fails**

```bash
supabase test db supabase/tests/database/resubmit_evidence.test.sql
```

Expected: FAIL — `function public.resubmit_evidence does not exist`

**Step 3: Write `resubmit_evidence.sql`**

Create `supabase/schemas/evidence/functions/resubmit_evidence.sql`:

```sql
CREATE OR REPLACE FUNCTION public.resubmit_evidence(
    p_evidence_id UUID,
    p_description TEXT,
    p_assets_to_add JSONB DEFAULT NULL,
    p_asset_ids_to_remove UUID[] DEFAULT NULL
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO ''
AS $function$
DECLARE
    v_task_id UUID;
    v_asset JSONB;
    v_now TIMESTAMP WITH TIME ZONE;
BEGIN
    v_now := NOW();

    -- 1. Validation
    IF p_description IS NULL OR trim(p_description) = '' THEN
        RAISE EXCEPTION 'Description is required';
    END IF;

    -- 2. Authorization & Status Check
    -- Resubmission requires: rejected, reopen_count < 1, due_date > now(), is_confirmed = false
    SELECT te.task_id INTO v_task_id
    FROM public.task_evidences te
    JOIN public.tasks t ON t.id = te.task_id
    JOIN public.task_referee_requests trr ON trr.task_id = t.id
    JOIN public.judgements j ON j.id = trr.id
    WHERE te.id = p_evidence_id
      AND t.tasker_id = auth.uid()
      AND j.status = 'rejected'
      AND j.reopen_count < 1
      AND j.is_confirmed = false
      AND t.due_date > v_now;

    IF v_task_id IS NULL THEN
        RAISE EXCEPTION 'Not authorized or evidence not in valid state for resubmission';
    END IF;

    -- 3. Update evidence FIRST (while judgement is still 'rejected')
    -- Evidence trigger will skip notification because judgement status is 'rejected'
    UPDATE public.task_evidences
    SET description = p_description,
        updated_at = v_now
    WHERE id = p_evidence_id;

    -- 3.1 Remove specified assets
    IF p_asset_ids_to_remove IS NOT NULL AND array_length(p_asset_ids_to_remove, 1) > 0 THEN
        DELETE FROM public.task_evidence_assets
        WHERE id = ANY(p_asset_ids_to_remove)
          AND evidence_id = p_evidence_id;
    END IF;

    -- 3.2 Add new assets
    IF p_assets_to_add IS NOT NULL AND jsonb_array_length(p_assets_to_add) > 0 THEN
        FOR v_asset IN SELECT * FROM jsonb_array_elements(p_assets_to_add)
        LOOP
            INSERT INTO public.task_evidence_assets (
                evidence_id,
                file_url,
                file_size_bytes,
                content_type,
                created_at,
                processing_status,
                public_url
            ) VALUES (
                p_evidence_id,
                v_asset->>'file_url',
                (v_asset->>'file_size_bytes')::BIGINT,
                v_asset->>'content_type',
                v_now,
                'completed',
                v_asset->>'public_url'
            );
        END LOOP;
    END IF;

    -- 4. Update judgement SECOND (triggers resubmission notification)
    -- Judgement trigger detects rejected → in_review with reopen_count > 0
    UPDATE public.judgements j
    SET
        status = 'in_review',
        reopen_count = reopen_count + 1,
        updated_at = v_now
    FROM public.task_referee_requests trr
    WHERE
        j.id = trr.id
        AND trr.task_id = v_task_id
        AND j.status = 'rejected'
        AND j.reopen_count < 1;

    RETURN jsonb_build_object(
        'success', true,
        'evidence_id', p_evidence_id
    );

EXCEPTION
    WHEN OTHERS THEN
        RAISE EXCEPTION 'Failed to resubmit evidence: %', SQLERRM;
END;
$function$;
```

**Step 4: Register in `config.toml`**

Add after the `update_evidence.sql` entry:

```toml
  "./schemas/evidence/functions/resubmit_evidence.sql",
```

**Step 5: Reset DB and run test**

```bash
./scripts/db-reset-and-clear-android-emulators-cache.sh
supabase test db supabase/tests/database/resubmit_evidence.test.sql
```

Expected: All 11 tests PASS

**Step 6: Commit**

```bash
git add -A && git commit -m "feat: add resubmit_evidence RPC with pgTAP tests"
```

---

### Task 4: Update notification triggers

**Files:**
- Modify: `supabase/schemas/evidence/triggers/on_task_evidences_upserted_notify_referee.sql`
- Modify: `supabase/schemas/judgement/triggers/on_judgements_status_changed.sql`

**Step 1: Update evidence trigger to skip notification when judgement is `rejected`**

In `on_task_evidences_upserted_notify_referee.sql`, replace the function body:

```sql
CREATE OR REPLACE FUNCTION public.on_task_evidences_upserted_notify_referee()
    RETURNS trigger
    LANGUAGE plpgsql
    SECURITY DEFINER
    SET search_path = ''
    AS $$
DECLARE
    v_referee_id uuid;
    v_task_title text;
    v_notification_key text;
    v_judgement_status text;
BEGIN
    -- 1. Identify Recipient (Referee) and current judgement status
    SELECT trr.matched_referee_id, j.status::text
    INTO v_referee_id, v_judgement_status
    FROM public.task_referee_requests trr
    JOIN public.judgements j ON j.id = trr.id
    WHERE trr.task_id = NEW.task_id;

    IF v_referee_id IS NULL THEN
        RETURN NEW;
    END IF;

    -- 2. Determine Event Key
    IF TG_OP = 'INSERT' THEN
        v_notification_key := 'notification_evidence_submitted';
    ELSIF TG_OP = 'UPDATE' THEN
        -- During resubmission, evidence is updated while judgement is still 'rejected'.
        -- The judgement status change trigger handles the resubmission notification.
        IF v_judgement_status = 'rejected' THEN
            RETURN NEW;
        END IF;
        v_notification_key := 'notification_evidence_updated';
    END IF;

    -- 3. Identify Task Details
    SELECT title INTO v_task_title FROM public.tasks WHERE id = NEW.task_id;

    -- 4. Invoke Notification
    PERFORM public.notify_event(
        v_referee_id,
        v_notification_key,
        ARRAY[v_task_title],
        jsonb_build_object('task_id', NEW.task_id)
    );

    RETURN NEW;
END;
$$;

ALTER FUNCTION public.on_task_evidences_upserted_notify_referee() OWNER TO postgres;

DROP TRIGGER IF EXISTS on_task_evidences_upserted_notify_referee ON public.task_evidences;

CREATE TRIGGER on_task_evidences_upserted_notify_referee
    AFTER INSERT OR UPDATE ON public.task_evidences
    FOR EACH ROW
    EXECUTE FUNCTION public.on_task_evidences_upserted_notify_referee();
```

**Step 2: Update judgement status change trigger for resubmission notification**

In `on_judgements_status_changed.sql`, add the `in_review` case. The trigger needs to also resolve the referee ID for resubmission notifications:

```sql
CREATE OR REPLACE FUNCTION public.on_judgements_status_changed()
    RETURNS trigger
    LANGUAGE plpgsql
    SECURITY DEFINER
    SET search_path = ''
    AS $$
DECLARE
    v_tasker_id uuid;
    v_referee_id uuid;
    v_task_id uuid;
    v_task_title text;
    v_notification_key text;
    v_recipient_id uuid;
BEGIN
    IF OLD.status = NEW.status THEN
        RETURN NEW;
    END IF;

    -- Resolve task info via task_referee_requests
    SELECT t.id, t.tasker_id, t.title, trr.matched_referee_id
    INTO v_task_id, v_tasker_id, v_task_title, v_referee_id
    FROM public.task_referee_requests trr
    JOIN public.tasks t ON t.id = trr.task_id
    WHERE trr.id = NEW.id;

    IF NOT FOUND THEN
        RETURN NEW;
    END IF;

    -- Determine notification based on new status
    CASE NEW.status
        WHEN 'approved' THEN
            v_notification_key := 'notification_judgement_approved';
            v_recipient_id := v_tasker_id;
        WHEN 'rejected' THEN
            v_notification_key := 'notification_judgement_rejected';
            v_recipient_id := v_tasker_id;
        WHEN 'in_review' THEN
            -- Resubmission: rejected → in_review with reopen_count > 0
            IF OLD.status = 'rejected' AND NEW.reopen_count > 0 THEN
                v_notification_key := 'notification_evidence_resubmitted';
                v_recipient_id := v_referee_id;
            ELSE
                RETURN NEW;
            END IF;
        ELSE
            RETURN NEW;
    END CASE;

    -- Send notification
    PERFORM public.notify_event(
        v_recipient_id,
        v_notification_key,
        ARRAY[v_task_title],
        jsonb_build_object('task_id', v_task_id, 'judgement_id', NEW.id)
    );

    RETURN NEW;
END;
$$;

ALTER FUNCTION public.on_judgements_status_changed() OWNER TO postgres;

DROP TRIGGER IF EXISTS on_judgements_status_changed ON public.judgements;

CREATE TRIGGER on_judgements_status_changed
    AFTER UPDATE ON public.judgements
    FOR EACH ROW
    WHEN (OLD.status IS DISTINCT FROM NEW.status)
    EXECUTE FUNCTION public.on_judgements_status_changed();
```

**Step 3: Commit**

```bash
git add -A && git commit -m "feat: update notification triggers for evidence resubmission"
```

---

### Task 5: Add i18n strings and notification resolver

**Files:**
- Modify: `peppercheck_flutter/assets/i18n/ja.i18n.json`
- Modify: `peppercheck_flutter/lib/features/notification/application/notification_text_resolver.dart`

**Step 1: Add i18n strings**

In `peppercheck_flutter/assets/i18n/ja.i18n.json`, add under `"notification"`, after `"evidence_updated_body"`:

```json
    "evidence_resubmitted_title": "エビデンス再提出",
    "evidence_resubmitted_body": "${taskTitle}のエビデンスが再提出されました。再度判定してください。",
```

Also add under `"task" > "evidence"` (find the existing evidence strings):

```json
    "edit": "編集",
    "resubmit": "エビデンスを再提出",
    "resubmit_success": "エビデンスを再提出しました",
    "update_success": "エビデンスを更新しました",
```

**Step 2: Add notification resolver entries**

In `notification_text_resolver.dart`, add after the `notification_evidence_updated_body` case (line 52):

```dart
    case 'notification_evidence_resubmitted_title':
      return t.notification.evidence_resubmitted_title;
    case 'notification_evidence_resubmitted_body':
      return t.notification.evidence_resubmitted_body(taskTitle: taskTitle);
```

**Step 3: Run Slang codegen**

```bash
cd peppercheck_flutter && dart run slang
```

Expected: Regenerates strings files without errors.

**Step 4: Commit**

```bash
git add -A && git commit -m "feat: add i18n strings for evidence resubmission notification"
```

---

### Task 6: Remove `canReopen` field from Judgement model

**Files:**
- Modify: `peppercheck_flutter/lib/features/judgement/domain/judgement.dart:16`

**Step 1: Remove `canReopen` field**

Remove this line from the `Judgement` class:

```dart
    @JsonKey(name: 'can_reopen') @Default(false) bool canReopen,
```

This field came from a view that no longer exists. `canReopen` will be computed in the UI.

**Step 2: Run build_runner**

```bash
cd peppercheck_flutter && dart run build_runner build --delete-conflicting-outputs
```

**Step 3: Commit**

```bash
git add -A && git commit -m "refactor: remove canReopen field from Judgement model"
```

---

### Task 7: Add repository and controller methods

**Files:**
- Modify: `peppercheck_flutter/lib/features/evidence/data/evidence_repository.dart`
- Modify: `peppercheck_flutter/lib/features/evidence/presentation/controllers/evidence_controller.dart`

**Step 1: Add `updateEvidence` to `EvidenceRepository`**

Add a method that uploads new images via presigned URLs, then calls `update_evidence` RPC:

```dart
  Future<void> updateEvidence({
    required String evidenceId,
    required String taskId,
    required String description,
    required List<XFile> newImages,
    required List<String> assetIdsToRemove,
  }) async {
    try {
      List<Map<String, dynamic>>? assetsToAdd;

      if (newImages.isNotEmpty) {
        assetsToAdd = [];
        final dio = Dio();

        for (final image in newImages) {
          final length = await image.length();
          final mimeType =
              lookupMimeType(image.path) ?? 'application/octet-stream';

          final response = await _client.functions.invoke(
            'generate-upload-url',
            body: {
              'task_id': taskId,
              'filename': image.name,
              'content_type': mimeType,
              'file_size_bytes': length,
              'kind': 'evidence',
            },
          );

          if (response.status != 200) {
            throw Exception('Failed to get upload URL: ${response.data}');
          }

          final uploadUrl = response.data['upload_url'] as String;
          final r2Key = response.data['r2_key'] as String;
          final publicUrl = response.data['public_url'] as String?;

          final fileBytes = await image.readAsBytes();
          await dio.put(
            uploadUrl,
            data: Stream.fromIterable([fileBytes]),
            options: Options(
              headers: {'Content-Type': mimeType, 'Content-Length': length},
            ),
          );

          assetsToAdd.add({
            'file_url': r2Key,
            'file_size_bytes': length,
            'content_type': mimeType,
            'public_url': publicUrl,
          });
        }
      }

      await _client.rpc(
        'update_evidence',
        params: {
          'p_evidence_id': evidenceId,
          'p_description': description,
          if (assetsToAdd != null) 'p_assets_to_add': assetsToAdd,
          if (assetIdsToRemove.isNotEmpty)
            'p_asset_ids_to_remove': assetIdsToRemove,
        },
      );
    } catch (e, st) {
      _logger.e('updateEvidence failed', error: e, stackTrace: st);
      rethrow;
    }
  }
```

**Step 2: Add `resubmitEvidence` to `EvidenceRepository`**

Same as `updateEvidence` but calls `resubmit_evidence` RPC:

```dart
  Future<void> resubmitEvidence({
    required String evidenceId,
    required String taskId,
    required String description,
    required List<XFile> newImages,
    required List<String> assetIdsToRemove,
  }) async {
    try {
      List<Map<String, dynamic>>? assetsToAdd;

      if (newImages.isNotEmpty) {
        assetsToAdd = [];
        final dio = Dio();

        for (final image in newImages) {
          // Same upload logic as updateEvidence
          final length = await image.length();
          final mimeType =
              lookupMimeType(image.path) ?? 'application/octet-stream';

          final response = await _client.functions.invoke(
            'generate-upload-url',
            body: {
              'task_id': taskId,
              'filename': image.name,
              'content_type': mimeType,
              'file_size_bytes': length,
              'kind': 'evidence',
            },
          );

          if (response.status != 200) {
            throw Exception('Failed to get upload URL: ${response.data}');
          }

          final uploadUrl = response.data['upload_url'] as String;
          final r2Key = response.data['r2_key'] as String;
          final publicUrl = response.data['public_url'] as String?;

          final fileBytes = await image.readAsBytes();
          await dio.put(
            uploadUrl,
            data: Stream.fromIterable([fileBytes]),
            options: Options(
              headers: {'Content-Type': mimeType, 'Content-Length': length},
            ),
          );

          assetsToAdd.add({
            'file_url': r2Key,
            'file_size_bytes': length,
            'content_type': mimeType,
            'public_url': publicUrl,
          });
        }
      }

      await _client.rpc(
        'resubmit_evidence',
        params: {
          'p_evidence_id': evidenceId,
          'p_description': description,
          if (assetsToAdd != null) 'p_assets_to_add': assetsToAdd,
          if (assetIdsToRemove.isNotEmpty)
            'p_asset_ids_to_remove': assetIdsToRemove,
        },
      );
    } catch (e, st) {
      _logger.e('resubmitEvidence failed', error: e, stackTrace: st);
      rethrow;
    }
  }
```

Note: The upload logic is duplicated across `uploadEvidence`, `updateEvidence`, and `resubmitEvidence`. Consider extracting a private `_uploadImages` helper to DRY this up during implementation.

**Step 3: Add controller methods to `EvidenceController`**

Add `update` and `resubmit` methods following the existing `submit` pattern:

```dart
  Future<void> update({
    required String taskId,
    required String evidenceId,
    required String description,
    required List<XFile> newImages,
    required List<String> assetIdsToRemove,
    required VoidCallback onSuccess,
  }) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      await ref.read(evidenceRepositoryProvider).updateEvidence(
            evidenceId: evidenceId,
            taskId: taskId,
            description: description,
            newImages: newImages,
            assetIdsToRemove: assetIdsToRemove,
          );
      ref.invalidate(taskProvider(taskId));
      onSuccess();
    });
  }

  Future<void> resubmit({
    required String taskId,
    required String evidenceId,
    required String description,
    required List<XFile> newImages,
    required List<String> assetIdsToRemove,
    required VoidCallback onSuccess,
  }) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      await ref.read(evidenceRepositoryProvider).resubmitEvidence(
            evidenceId: evidenceId,
            taskId: taskId,
            description: description,
            newImages: newImages,
            assetIdsToRemove: assetIdsToRemove,
          );
      ref.invalidate(taskProvider(taskId));
      onSuccess();
    });
  }
```

**Step 4: Run build_runner**

```bash
cd peppercheck_flutter && dart run build_runner build --delete-conflicting-outputs
```

**Step 5: Commit**

```bash
git add -A && git commit -m "feat: add repository and controller methods for evidence update/resubmit"
```

---

### Task 8: Update evidence submission UI

**Files:**
- Modify: `peppercheck_flutter/lib/features/evidence/presentation/widgets/evidence_submission_section.dart`

This is the most complex UI task. The widget needs to support three modes:

1. **Read-only** (existing: evidence submitted) — add "Edit" button when `in_review` and user is tasker
2. **Edit mode** (new) — pre-filled form with existing evidence, "Update" / "Resubmit" button
3. **Resubmit mode** (new: after rejection) — same form as edit, different action

**Step 1: Add state management for edit mode**

Add to the `State` class:
- `bool _isEditing = false`
- `List<String> _assetIdsToRemove = []`
- Track existing assets vs new images separately

**Step 2: Add helper methods**

```dart
bool _canReopen(Task task) {
  final judgement = task.refereeRequests
      .cast<RefereeRequest?>()
      .firstWhere((req) => req?.judgement?.status == 'rejected', orElse: () => null)
      ?.judgement;
  if (judgement == null) return false;

  final dueDate = task.dueDate != null ? DateTime.parse(task.dueDate!) : null;
  return judgement.status == 'rejected' &&
      judgement.reopenCount < 1 &&
      !judgement.isConfirmed &&
      dueDate != null &&
      dueDate.isAfter(DateTime.now());
}

bool _isInReview(Task task) {
  return task.refereeRequests.any(
    (req) => req.judgement?.status == 'in_review',
  );
}

bool _isCurrentUserTasker(Task task) {
  return Supabase.instance.client.auth.currentUser?.id == task.taskerId;
}
```

**Step 3: Modify the evidence display state**

When evidence exists and `_isEditing` is false:
- Show existing evidence (read-only) — current behavior
- If `_isInReview && _isCurrentUserTasker`: add "Edit" button → sets `_isEditing = true`, pre-fills form
- If `_canReopen`: add "Resubmit Evidence" button → sets `_isEditing = true`, pre-fills form

When `_isEditing` is true:
- Show edit form with pre-filled description and existing images
- User can remove existing images (track IDs in `_assetIdsToRemove`) and add new images
- Submit button label and action depend on context:
  - If `_isInReview`: "Update" → calls `evidenceController.update()`
  - If `_canReopen`: "Resubmit" → calls `evidenceController.resubmit()`
- Cancel button to exit edit mode

**Step 4: Verify app compiles**

```bash
cd peppercheck_flutter && flutter build apk --debug 2>&1 | tail -5
```

Expected: Build succeeds

**Step 5: Commit**

```bash
git add -A && git commit -m "feat: add evidence edit and resubmit UI"
```

---

### Task 9: Generate migration and verify

**Step 1: Generate migration**

```bash
cd /Users/makoto/projects/peppercheck && supabase db diff -f add_reopen_evidence_update
```

**Step 2: Review the generated migration file**

Check the generated file in `supabase/migrations/` for correctness. It should include:
- DROP of `reopen_judgement` function
- CREATE of `update_evidence` function
- CREATE of `resubmit_evidence` function
- Updated `submit_evidence` function
- Updated `on_task_evidences_upserted_notify_referee` trigger function
- Updated `on_judgements_status_changed` trigger function

**Step 3: Full reset and verify**

```bash
./scripts/db-reset-and-clear-android-emulators-cache.sh
```

Expected: Clean DB reset with all migrations applied successfully.

**Step 4: Run all pgTAP tests**

```bash
supabase test db
```

Expected: All tests PASS.

**Step 5: Commit**

```bash
git add -A && git commit -m "feat: add migration for reopen and evidence update"
```
