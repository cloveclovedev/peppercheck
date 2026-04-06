begin;
create extension if not exists pgtap with schema extensions;
select plan(4);

-- ============================================================
-- Setup: create two test users
-- ============================================================
INSERT INTO auth.users (id, email) VALUES
    ('a1111111-1111-1111-1111-111111111111', 'reporter@test.com'),
    ('b2222222-2222-2222-2222-222222222222', 'other@test.com');

-- Create a task owned by 'other' user
INSERT INTO public.tasks (id, tasker_id, title, due_date, status) VALUES
    ('c3333333-3333-3333-3333-333333333333',
     'b2222222-2222-2222-2222-222222222222',
     'Test Task',
     NOW() + INTERVAL '1 day',
     'open');

-- ============================================================
-- Test 1: Can insert a report
-- ============================================================
SELECT lives_ok(
    $$
    INSERT INTO public.reports (reporter_id, task_id, reporter_role, content_type, reason, detail)
    VALUES (
        'a1111111-1111-1111-1111-111111111111',
        'c3333333-3333-3333-3333-333333333333',
        'referee',
        'task_description',
        'inappropriate_content',
        'Test report detail'
    )
    $$,
    'Can insert a report'
);

-- ============================================================
-- Test 2: Status defaults to pending
-- ============================================================
SELECT is(
    (SELECT status::text FROM public.reports
     WHERE reporter_id = 'a1111111-1111-1111-1111-111111111111'
       AND task_id = 'c3333333-3333-3333-3333-333333333333'),
    'pending',
    'Report status defaults to pending'
);

-- ============================================================
-- Test 3: Unique constraint prevents duplicate report (same reporter + task)
-- ============================================================
SELECT throws_ok(
    $$
    INSERT INTO public.reports (reporter_id, task_id, reporter_role, content_type, reason)
    VALUES (
        'a1111111-1111-1111-1111-111111111111',
        'c3333333-3333-3333-3333-333333333333',
        'referee',
        'evidence',
        'spam'
    )
    $$,
    '23505',
    NULL,
    'Duplicate report (same reporter + task) raises unique violation'
);

-- ============================================================
-- Test 4: Different user can report the same task
-- ============================================================
SELECT lives_ok(
    $$
    INSERT INTO public.reports (reporter_id, task_id, reporter_role, content_type, reason)
    VALUES (
        'b2222222-2222-2222-2222-222222222222',
        'c3333333-3333-3333-3333-333333333333',
        'tasker',
        'judgement',
        'harassment'
    )
    $$,
    'Different user can report the same task'
);

select * from finish();
rollback;
