begin;
create extension if not exists pgtap with schema extensions;
select plan(6);

-- ============================================================
-- Setup: one tasker + one referee + 6 matched tasks covering every
-- branch of the ordering rule (overdue, non-NULL-bucket tie, far, NULL-bucket tie)
-- ============================================================
delete from auth.users where id in (
  'bb000001-0000-0000-0000-000000000000',
  'bb000002-0000-0000-0000-000000000000'
);

insert into auth.users (id, email, instance_id, aud, role, encrypted_password, email_confirmed_at, created_at, updated_at)
values
  ('bb000001-0000-0000-0000-000000000000', 'tasker@test.com',  '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated', crypt('password123', gen_salt('bf')), now(), now(), now()),
  ('bb000002-0000-0000-0000-000000000000', 'referee@test.com', '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated', crypt('password123', gen_salt('bf')), now(), now(), now());

-- Insert tasks in roughly the OPPOSITE of the expected return order so the
-- test would fail reliably without an explicit ORDER BY in the RPC.
-- "Near Older" / "Near Newer" share the same due_date so the non-NULL-bucket
-- tie-break (created_at ASC) is observable; same idea for "Null Older" / "Null Newer".
insert into public.tasks (id, tasker_id, title, status, due_date, created_at)
values
  ('bb100001-0000-0000-0000-000000000000', 'bb000001-0000-0000-0000-000000000000', 'Null Older', 'open', null,                       now() - interval '10 days'),
  ('bb100002-0000-0000-0000-000000000000', 'bb000001-0000-0000-0000-000000000000', 'Null Newer', 'open', null,                       now() - interval '1 day'),
  ('bb100003-0000-0000-0000-000000000000', 'bb000001-0000-0000-0000-000000000000', 'Far Future', 'open', now() + interval '30 days', now() - interval '5 days'),
  ('bb100004-0000-0000-0000-000000000000', 'bb000001-0000-0000-0000-000000000000', 'Near Older', 'open', now() + interval '1 day',   now() - interval '4 days'),
  ('bb100006-0000-0000-0000-000000000000', 'bb000001-0000-0000-0000-000000000000', 'Near Newer', 'open', now() + interval '1 day',   now() - interval '2 days'),
  ('bb100005-0000-0000-0000-000000000000', 'bb000001-0000-0000-0000-000000000000', 'Overdue',    'open', now() - interval '2 days',  now() - interval '3 days');

insert into public.task_referee_requests (id, task_id, matching_strategy, matched_referee_id, status)
values
  ('bb200001-0000-0000-0000-000000000000', 'bb100001-0000-0000-0000-000000000000', 'standard', 'bb000002-0000-0000-0000-000000000000', 'matched'),
  ('bb200002-0000-0000-0000-000000000000', 'bb100002-0000-0000-0000-000000000000', 'standard', 'bb000002-0000-0000-0000-000000000000', 'matched'),
  ('bb200003-0000-0000-0000-000000000000', 'bb100003-0000-0000-0000-000000000000', 'standard', 'bb000002-0000-0000-0000-000000000000', 'matched'),
  ('bb200004-0000-0000-0000-000000000000', 'bb100004-0000-0000-0000-000000000000', 'standard', 'bb000002-0000-0000-0000-000000000000', 'matched'),
  ('bb200006-0000-0000-0000-000000000000', 'bb100006-0000-0000-0000-000000000000', 'standard', 'bb000002-0000-0000-0000-000000000000', 'matched'),
  ('bb200005-0000-0000-0000-000000000000', 'bb100005-0000-0000-0000-000000000000', 'standard', 'bb000002-0000-0000-0000-000000000000', 'matched');

-- Authenticate as the referee
select set_config('request.jwt.claims', '{"sub": "bb000002-0000-0000-0000-000000000000"}', true);

-- ============================================================
-- Test: get_active_referee_tasks returns tasks ordered by
--       due_date ASC NULLS LAST, created_at ASC
-- Expected order:
--   1. Overdue     (smallest due_date)
--   2. Near Older  (next due_date; older created_at within the tie)
--   3. Near Newer  (same due_date as Near Older; newer created_at)
--   4. Far Future
--   5. Null Older  (NULL bucket; older created_at)
--   6. Null Newer  (NULL bucket; newer created_at)
-- ============================================================

-- Materialise the RPC output once and assert each position against the temp
-- table; avoids re-running the function (and its joins) for every assertion.
create temp table ordered_result on commit drop as
select
  (elem -> 'task') ->> 'id' as task_id,
  row_number() over () as pos
from jsonb_array_elements(public.get_active_referee_tasks()) as elem;

select is(
    (select task_id from ordered_result where pos = 1),
    'bb100005-0000-0000-0000-000000000000',
    'Test 1: overdue task is first (smallest due_date)'
);

select is(
    (select task_id from ordered_result where pos = 2),
    'bb100004-0000-0000-0000-000000000000',
    'Test 2: non-NULL bucket — older created_at first (Near Older)'
);

select is(
    (select task_id from ordered_result where pos = 3),
    'bb100006-0000-0000-0000-000000000000',
    'Test 3: non-NULL bucket — same due_date, newer created_at second (Near Newer)'
);

select is(
    (select task_id from ordered_result where pos = 4),
    'bb100003-0000-0000-0000-000000000000',
    'Test 4: far-future task is fourth'
);

select is(
    (select task_id from ordered_result where pos = 5),
    'bb100001-0000-0000-0000-000000000000',
    'Test 5: NULL bucket — older created_at first (Null Older)'
);

select is(
    (select task_id from ordered_result where pos = 6),
    'bb100002-0000-0000-0000-000000000000',
    'Test 6: NULL bucket — newer created_at last (Null Newer)'
);

select * from finish();
rollback;
