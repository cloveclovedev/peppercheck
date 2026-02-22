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

insert into public.judgements (id, status)
values ('bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb', 'in_review');

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
