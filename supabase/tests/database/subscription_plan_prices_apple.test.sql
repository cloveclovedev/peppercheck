begin;
create extension if not exists pgtap with schema extensions;
select plan(4);

SELECT is(
    (SELECT amount_minor FROM public.subscription_plan_prices
     WHERE plan_id = 'light' AND provider = 'apple' AND currency_code = 'JPY'),
    650,
    'Apple light plan is JPY 650'
);

SELECT is(
    (SELECT amount_minor FROM public.subscription_plan_prices
     WHERE plan_id = 'standard' AND provider = 'apple' AND currency_code = 'JPY'),
    1280,
    'Apple standard plan is JPY 1280'
);

SELECT is(
    (SELECT amount_minor FROM public.subscription_plan_prices
     WHERE plan_id = 'premium' AND provider = 'apple' AND currency_code = 'JPY'),
    2480,
    'Apple premium plan is JPY 2480'
);

SELECT is(
    (SELECT amount_minor FROM public.subscription_plan_prices
     WHERE plan_id = 'premium' AND provider = 'google' AND currency_code = 'JPY'),
    2480,
    'Google premium plan aligned to JPY 2480 (Issue #411)'
);

select * from finish();
rollback;
