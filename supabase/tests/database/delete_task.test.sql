begin;
create extension if not exists pgtap with schema extensions;
select plan(8);

-- ============================================================
-- Setup: two test users + tasks in various states
-- ============================================================
delete from auth.users where id in (
  'aa000001-0000-0000-0000-000000000000',
  'aa000002-0000-0000-0000-000000000000'
);

insert into auth.users (id, email, instance_id, aud, role, encrypted_password, email_confirmed_at, created_at, updated_at)
values
  ('aa000001-0000-0000-0000-000000000000', 'tasker@test.com', '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated', crypt('password123', gen_salt('bf')), now(), now(), now()),
  ('aa000002-0000-0000-0000-000000000000', 'other@test.com',  '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated', crypt('password123', gen_salt('bf')), now(), now(), now());

insert into public.tasks (id, tasker_id, title, status, due_date)
values
  ('aa100001-0000-0000-0000-000000000000', 'aa000001-0000-0000-0000-000000000000', 'Draft Task',  'draft', null),
  ('aa100002-0000-0000-0000-000000000000', 'aa000001-0000-0000-0000-000000000000', 'Open Task',   'open',  now() + interval '1 day'),
  ('aa100003-0000-0000-0000-000000000000', 'aa000001-0000-0000-0000-000000000000', 'Closed Task', 'closed', now() + interval '1 day'),
  ('aa100004-0000-0000-0000-000000000000', 'aa000002-0000-0000-0000-000000000000', 'Other Draft', 'draft', null);

-- ============================================================
-- Test 1: tasker deletes own draft task → succeeds
-- ============================================================
select set_config('request.jwt.claims', '{"sub": "aa000001-0000-0000-0000-000000000000"}', true);

select lives_ok(
    $$ select public.delete_task('aa100001-0000-0000-0000-000000000000') $$,
    'Test 1: tasker can delete own draft task'
);

-- Test 2: row was actually removed
select is(
    (select count(*) from public.tasks where id = 'aa100001-0000-0000-0000-000000000000'),
    0::bigint,
    'Test 2: deleted task row is removed'
);

-- ============================================================
-- Test 3: tasker cannot delete own open task
-- ============================================================
select set_config('request.jwt.claims', '{"sub": "aa000001-0000-0000-0000-000000000000"}', true);

select throws_ok(
    $$ select public.delete_task('aa100002-0000-0000-0000-000000000000') $$,
    'P0001',
    'Only draft tasks can be deleted',
    'Test 3: open task deletion raises exception'
);

-- ============================================================
-- Test 4: tasker cannot delete own closed task
-- ============================================================
select set_config('request.jwt.claims', '{"sub": "aa000001-0000-0000-0000-000000000000"}', true);

select throws_ok(
    $$ select public.delete_task('aa100003-0000-0000-0000-000000000000') $$,
    'P0001',
    'Only draft tasks can be deleted',
    'Test 4: closed task deletion raises exception'
);

-- ============================================================
-- Test 5: non-owner cannot delete another user's draft
-- ============================================================
select set_config('request.jwt.claims', '{"sub": "aa000001-0000-0000-0000-000000000000"}', true);

select throws_ok(
    $$ select public.delete_task('aa100004-0000-0000-0000-000000000000') $$,
    'P0001',
    'Not authorized to delete this task',
    'Test 5: non-owner deletion raises authorization error'
);

-- Test 6: row was NOT removed (sanity check on Test 5)
select is(
    (select count(*) from public.tasks where id = 'aa100004-0000-0000-0000-000000000000'),
    1::bigint,
    'Test 6: non-owner attempt did not delete the row'
);

-- ============================================================
-- Test 7: non-existent task ID raises "Task not found"
-- ============================================================
select set_config('request.jwt.claims', '{"sub": "aa000001-0000-0000-0000-000000000000"}', true);

select throws_ok(
    $$ select public.delete_task('aa999999-9999-9999-9999-999999999999') $$,
    'P0001',
    'Task not found',
    'Test 7: non-existent task ID raises Task not found'
);

-- ============================================================
-- Test 8: FK CASCADE — deleting draft cascades to any task_referee_requests
-- (drafts normally have no requests, but the cascade is a safety net)
-- ============================================================
insert into public.tasks (id, tasker_id, title, status, due_date)
values ('aa100005-0000-0000-0000-000000000000', 'aa000001-0000-0000-0000-000000000000', 'Draft With Request', 'draft', null);

insert into public.task_referee_requests (id, task_id, matching_strategy, status)
values ('aa200001-0000-0000-0000-000000000000', 'aa100005-0000-0000-0000-000000000000', 'standard', 'pending');

select set_config('request.jwt.claims', '{"sub": "aa000001-0000-0000-0000-000000000000"}', true);

select public.delete_task('aa100005-0000-0000-0000-000000000000');

select is(
    (select count(*) from public.task_referee_requests where id = 'aa200001-0000-0000-0000-000000000000'),
    0::bigint,
    'Test 8: deleting task cascades to task_referee_requests'
);

select * from finish();
rollback;
