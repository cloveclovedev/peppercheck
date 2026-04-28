begin;
create extension if not exists pgtap with schema extensions;
select plan(7);

-- Cleanup any prior test users
delete from auth.users where email like 'username_test_%@test.com';

-- Test 1: handle_new_user generates a username matching the expected pattern
insert into auth.users (id, email, instance_id, aud, role, encrypted_password, email_confirmed_at, created_at, updated_at)
values ('aa000001-0000-0000-0000-000000000000', 'username_test_1@test.com', '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated', crypt('password123', gen_salt('bf')), now(), now(), now());

select matches(
  (select username from public.profiles where id = 'aa000001-0000-0000-0000-000000000000'),
  '^user_[0-9a-f]{8}$',
  'Test 1: handle_new_user generates user_<8hex> username'
);

-- Test 2: a second new user gets a different username
insert into auth.users (id, email, instance_id, aud, role, encrypted_password, email_confirmed_at, created_at, updated_at)
values ('aa000002-0000-0000-0000-000000000000', 'username_test_2@test.com', '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated', crypt('password123', gen_salt('bf')), now(), now(), now());

select isnt(
  (select username from public.profiles where id = 'aa000001-0000-0000-0000-000000000000'),
  (select username from public.profiles where id = 'aa000002-0000-0000-0000-000000000000'),
  'Test 2: distinct users get distinct usernames'
);

-- Test 3: NULL username is rejected by NOT NULL
select throws_ok(
  $$ insert into public.profiles (id, username) values ('aa000003-0000-0000-0000-000000000000', NULL) $$,
  '23502',
  null,
  'Test 3: NULL username raises NOT NULL violation'
);

-- Test 4: 1-character username is rejected by CHECK
select throws_ok(
  $$ update public.profiles set username = 'a' where id = 'aa000001-0000-0000-0000-000000000000' $$,
  '23514',
  null,
  'Test 4: 1-char username raises CHECK violation'
);

-- Test 5: 21-character username is rejected by CHECK
select throws_ok(
  $$ update public.profiles set username = 'aaaaaaaaaaaaaaaaaaaaa' where id = 'aa000001-0000-0000-0000-000000000000' $$,
  '23514',
  null,
  'Test 5: 21-char username raises CHECK violation'
);

-- Test 6: 2-character username is accepted
select lives_ok(
  $$ update public.profiles set username = 'ab' where id = 'aa000001-0000-0000-0000-000000000000' $$,
  'Test 6: 2-char username is accepted'
);

-- Test 7: 20-character username is accepted (different value to avoid UNIQUE collision with prior test)
select lives_ok(
  $$ update public.profiles set username = 'abcdefghij1234567890' where id = 'aa000001-0000-0000-0000-000000000000' $$,
  'Test 7: 20-char username is accepted'
);

select * from finish();
rollback;
