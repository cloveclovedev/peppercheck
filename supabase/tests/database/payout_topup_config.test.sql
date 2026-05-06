begin;
create extension if not exists pgtap with schema extensions;
select plan(4);

-- ============================================================
-- Test 1: Default singleton row exists with default buffer_multiplier
-- ============================================================
SELECT is(
    (SELECT buffer_multiplier FROM public.payout_topup_config WHERE id = true),
    1.3::numeric,
    'Default buffer_multiplier is 1.3'
);

-- ============================================================
-- Test 2: Cannot insert a second row (PK uniqueness)
-- ============================================================
SELECT throws_ok(
    $$INSERT INTO public.payout_topup_config (id, buffer_multiplier) VALUES (true, 2.0)$$,
    '23505',  -- unique_violation
    NULL,
    'Second row insert violates primary key'
);

-- ============================================================
-- Test 3: Cannot insert with id=false (singleton CHECK)
-- ============================================================
-- First delete the existing row so PK does not block
DELETE FROM public.payout_topup_config;
SELECT throws_ok(
    $$INSERT INTO public.payout_topup_config (id, buffer_multiplier) VALUES (false, 1.5)$$,
    '23514',  -- check_violation
    NULL,
    'id=false violates singleton CHECK'
);

-- ============================================================
-- Test 4: buffer_multiplier < 1.0 is rejected
-- ============================================================
-- Defensive delete so Test 4 does not depend on Test 3's side effect
DELETE FROM public.payout_topup_config;
SELECT throws_ok(
    $$INSERT INTO public.payout_topup_config (id, buffer_multiplier) VALUES (true, 0.5)$$,
    '23514',  -- check_violation
    NULL,
    'buffer_multiplier < 1.0 violates buffer_multiplier_min CHECK'
);

select * from finish();
rollback;
