begin;
create extension if not exists pgtap with schema extensions;
select plan(4);

SELECT has_column(
    'public', 'user_subscriptions', 'apple_original_transaction_id',
    'apple_original_transaction_id column exists on user_subscriptions'
);

SELECT col_type_is(
    'public', 'user_subscriptions', 'apple_original_transaction_id', 'text',
    'apple_original_transaction_id is type text'
);

SELECT col_is_null(
    'public', 'user_subscriptions', 'apple_original_transaction_id',
    'apple_original_transaction_id is nullable'
);

SELECT has_index(
    'public', 'user_subscriptions', 'idx_user_subscriptions_apple_id',
    ARRAY['apple_original_transaction_id'],
    'idx_user_subscriptions_apple_id index exists'
);

select * from finish();
rollback;
