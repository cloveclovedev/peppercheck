begin;
create extension if not exists pgtap with schema extensions;
select plan(13);

-- [Setup] Create test users
delete from auth.users where id in (
  'dd000001-0000-0000-0000-000000000000',
  'dd000002-0000-0000-0000-000000000000',
  'dd000003-0000-0000-0000-000000000000'
);

insert into auth.users (id, email, instance_id, aud, role, encrypted_password, email_confirmed_at, created_at, updated_at)
values
  ('dd000001-0000-0000-0000-000000000000', 'delete_me@test.com', '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated', crypt('password123', gen_salt('bf')), now(), now(), now()),
  ('dd000002-0000-0000-0000-000000000000', 'other_user@test.com', '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated', crypt('password123', gen_salt('bf')), now(), now(), now());

-- Test 1: check_account_deletable returns deletable when no blockers
select set_config('request.jwt.claims', '{"sub": "dd000001-0000-0000-0000-000000000000"}', true);

select is(
  (public.check_account_deletable()->>'deletable')::boolean,
  true,
  'Test 1: deletable with no blockers'
);

-- Test 2: check_account_deletable blocks on open tasks
insert into public.tasks (id, tasker_id, title, status, due_date)
values ('dd100001-0000-0000-0000-000000000000', 'dd000001-0000-0000-0000-000000000000', 'Test Task', 'open', now() + interval '1 day');

select set_config('request.jwt.claims', '{"sub": "dd000001-0000-0000-0000-000000000000"}', true);

select is(
  (public.check_account_deletable()->>'deletable')::boolean,
  false,
  'Test 2: blocked by open tasks'
);

select ok(
  public.check_account_deletable()->'reasons' ? 'open_tasks',
  'Test 2: reasons includes open_tasks'
);

-- Close the task so it no longer blocks
update public.tasks set status = 'closed' where id = 'dd100001-0000-0000-0000-000000000000';

-- Test 3: check_account_deletable blocks on active referee requests
insert into public.tasks (id, tasker_id, title, status, due_date)
values ('dd100002-0000-0000-0000-000000000000', 'dd000002-0000-0000-0000-000000000000', 'Other Task', 'open', now() + interval '1 day');

insert into public.task_referee_requests (id, task_id, matching_strategy, matched_referee_id, status)
values ('dd200001-0000-0000-0000-000000000000', 'dd100002-0000-0000-0000-000000000000', 'standard', 'dd000001-0000-0000-0000-000000000000', 'accepted');

select set_config('request.jwt.claims', '{"sub": "dd000001-0000-0000-0000-000000000000"}', true);

select is(
  (public.check_account_deletable()->>'deletable')::boolean,
  false,
  'Test 3: blocked by active referee request'
);

select ok(
  public.check_account_deletable()->'reasons' ? 'active_referee_requests',
  'Test 3: reasons includes active_referee_requests'
);

-- Close the request so it no longer blocks
update public.task_referee_requests set status = 'closed' where id = 'dd200001-0000-0000-0000-000000000000';

-- [Setup for deletion tests] Create a judgement so we can test rating_histories
insert into public.judgements (id, status, comment, reopen_count)
values ('dd200001-0000-0000-0000-000000000000', 'approved', 'Good', 0);

insert into public.rating_histories (id, judgement_id, rater_id, ratee_id, rating_type, is_positive)
values ('dd400001-0000-0000-0000-000000000000', 'dd200001-0000-0000-0000-000000000000', 'dd000001-0000-0000-0000-000000000000', 'dd000002-0000-0000-0000-000000000000', 'tasker', true);

insert into public.judgement_threads (id, judgement_id, sender_id, message)
values ('dd500001-0000-0000-0000-000000000000', 'dd200001-0000-0000-0000-000000000000', 'dd000001-0000-0000-0000-000000000000', 'Test message');

-- Test 4: CASCADE — deleting auth user cascades to profile and wallets
select ok(
  (select count(*) from public.profiles where id = 'dd000001-0000-0000-0000-000000000000') = 1,
  'Test 4 pre: profile exists before deletion'
);

delete from auth.users where id = 'dd000001-0000-0000-0000-000000000000';

select ok(
  (select count(*) from public.profiles where id = 'dd000001-0000-0000-0000-000000000000') = 0,
  'Test 4: profile cascaded on auth user deletion'
);

select ok(
  (select count(*) from public.point_wallets where user_id = 'dd000001-0000-0000-0000-000000000000') = 0,
  'Test 4: point wallet cascaded on auth user deletion'
);

-- Test 5: SET NULL — tasks.tasker_id and task_referee_requests.matched_referee_id
select is(
  (select tasker_id from public.tasks where id = 'dd100001-0000-0000-0000-000000000000'),
  null::uuid,
  'Test 5: tasker_id set to NULL after user deletion'
);

select is(
  (select matched_referee_id from public.task_referee_requests where id = 'dd200001-0000-0000-0000-000000000000'),
  null::uuid,
  'Test 5: matched_referee_id set to NULL after user deletion'
);

-- Test 6: SET NULL — rating_histories.rater_id
select is(
  (select rater_id from public.rating_histories where id = 'dd400001-0000-0000-0000-000000000000'),
  null::uuid,
  'Test 6: rating_histories.rater_id set to NULL after user deletion'
);

-- Test 7: SET NULL — judgement_threads.sender_id
select is(
  (select sender_id from public.judgement_threads where id = 'dd500001-0000-0000-0000-000000000000'),
  null::uuid,
  'Test 7: judgement_threads.sender_id set to NULL after user deletion'
);

-- Test 8: SET NULL — reward_payouts.user_id
insert into auth.users (id, email, instance_id, aud, role, encrypted_password, email_confirmed_at, created_at, updated_at)
values ('dd000003-0000-0000-0000-000000000000', 'payout_test@test.com', '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated', crypt('password123', gen_salt('bf')), now(), now(), now());

insert into public.reward_payouts (id, user_id, points_amount, currency, currency_amount, rate_per_point, status, batch_date)
values ('dd300001-0000-0000-0000-000000000000', 'dd000003-0000-0000-0000-000000000000', 100, 'JPY', 1000, 10, 'success', current_date);

delete from auth.users where id = 'dd000003-0000-0000-0000-000000000000';

select is(
  (select user_id from public.reward_payouts where id = 'dd300001-0000-0000-0000-000000000000'),
  null::uuid,
  'Test 8: reward_payouts.user_id set to NULL, record retained'
);

select * from finish();
rollback;
