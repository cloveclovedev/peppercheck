begin;
create extension if not exists pgtap with schema extensions;
select plan(5);

-- ============================================================
-- Setup: one tasker + one referee + 4 matched tasks with mixed due_date values
-- ============================================================
delete from auth.users where id in (
  'bb000001-0000-0000-0000-000000000000',
  'bb000002-0000-0000-0000-000000000000'
);

insert into auth.users (id, email, instance_id, aud, role, encrypted_password, email_confirmed_at, created_at, updated_at)
values
  ('bb000001-0000-0000-0000-000000000000', 'tasker@test.com',  '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated', crypt('password123', gen_salt('bf')), now(), now(), now()),
  ('bb000002-0000-0000-0000-000000000000', 'referee@test.com', '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated', crypt('password123', gen_salt('bf')), now(), now(), now());

-- Insert tasks in the OPPOSITE of the expected return order so the test
-- fails reliably without an explicit ORDER BY in the RPC.
-- created_at offsets are also crafted so the NULL-bucket tie-break (created_at ASC) is observable.
insert into public.tasks (id, tasker_id, title, status, due_date, created_at)
values
  ('bb100001-0000-0000-0000-000000000000', 'bb000001-0000-0000-0000-000000000000', 'Null Older',  'open', null,                        now() - interval '10 days'),
  ('bb100002-0000-0000-0000-000000000000', 'bb000001-0000-0000-0000-000000000000', 'Null Newer',  'open', null,                        now() - interval '1 day'),
  ('bb100003-0000-0000-0000-000000000000', 'bb000001-0000-0000-0000-000000000000', 'Far Future',  'open', now() + interval '30 days',  now() - interval '5 days'),
  ('bb100004-0000-0000-0000-000000000000', 'bb000001-0000-0000-0000-000000000000', 'Near Future', 'open', now() + interval '1 day',    now() - interval '4 days'),
  ('bb100005-0000-0000-0000-000000000000', 'bb000001-0000-0000-0000-000000000000', 'Overdue',     'open', now() - interval '2 days',   now() - interval '3 days');

insert into public.task_referee_requests (id, task_id, matching_strategy, matched_referee_id, status)
values
  ('bb200001-0000-0000-0000-000000000000', 'bb100001-0000-0000-0000-000000000000', 'standard', 'bb000002-0000-0000-0000-000000000000', 'matched'),
  ('bb200002-0000-0000-0000-000000000000', 'bb100002-0000-0000-0000-000000000000', 'standard', 'bb000002-0000-0000-0000-000000000000', 'matched'),
  ('bb200003-0000-0000-0000-000000000000', 'bb100003-0000-0000-0000-000000000000', 'standard', 'bb000002-0000-0000-0000-000000000000', 'matched'),
  ('bb200004-0000-0000-0000-000000000000', 'bb100004-0000-0000-0000-000000000000', 'standard', 'bb000002-0000-0000-0000-000000000000', 'matched'),
  ('bb200005-0000-0000-0000-000000000000', 'bb100005-0000-0000-0000-000000000000', 'standard', 'bb000002-0000-0000-0000-000000000000', 'matched');

-- Authenticate as the referee
select set_config('request.jwt.claims', '{"sub": "bb000002-0000-0000-0000-000000000000"}', true);

-- ============================================================
-- Test: get_active_referee_tasks returns tasks ordered by
--       due_date ASC NULLS LAST, created_at ASC
-- Expected order: Overdue → Near Future → Far Future → Null Older → Null Newer
-- ============================================================
with ordered as (
  select
    (elem ->> 'task')::jsonb ->> 'id' as task_id,
    row_number() over () as pos
  from jsonb_array_elements(public.get_active_referee_tasks()) as elem
)
select is(
    (select task_id from ordered where pos = 1),
    'bb100005-0000-0000-0000-000000000000',
    'Test 1: overdue task is first (smallest due_date)'
);

with ordered as (
  select
    (elem ->> 'task')::jsonb ->> 'id' as task_id,
    row_number() over () as pos
  from jsonb_array_elements(public.get_active_referee_tasks()) as elem
)
select is(
    (select task_id from ordered where pos = 2),
    'bb100004-0000-0000-0000-000000000000',
    'Test 2: near-future task is second'
);

with ordered as (
  select
    (elem ->> 'task')::jsonb ->> 'id' as task_id,
    row_number() over () as pos
  from jsonb_array_elements(public.get_active_referee_tasks()) as elem
)
select is(
    (select task_id from ordered where pos = 3),
    'bb100003-0000-0000-0000-000000000000',
    'Test 3: far-future task is third'
);

with ordered as (
  select
    (elem ->> 'task')::jsonb ->> 'id' as task_id,
    row_number() over () as pos
  from jsonb_array_elements(public.get_active_referee_tasks()) as elem
)
select is(
    (select task_id from ordered where pos = 4),
    'bb100001-0000-0000-0000-000000000000',
    'Test 4: NULL bucket — older created_at first (Null Older)'
);

with ordered as (
  select
    (elem ->> 'task')::jsonb ->> 'id' as task_id,
    row_number() over () as pos
  from jsonb_array_elements(public.get_active_referee_tasks()) as elem
)
select is(
    (select task_id from ordered where pos = 5),
    'bb100002-0000-0000-0000-000000000000',
    'Test 5: NULL bucket — newer created_at last (Null Newer)'
);

select * from finish();
rollback;
