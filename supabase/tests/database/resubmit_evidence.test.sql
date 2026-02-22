begin;
create extension if not exists pgtap with schema extensions;
select plan(10);

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

-- IMPORTANT: Use INSERT (not UPDATE) for the judgement row because the matching trigger
-- does not auto-create judgements when referee request is inserted with status='accepted'.
-- This was learned from Task 2.
insert into public.judgements (id, status, comment, reopen_count)
values ('bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb', 'rejected', 'Not clear enough', 0);

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
  'Not authorized or evidence not in valid state for resubmission',
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
