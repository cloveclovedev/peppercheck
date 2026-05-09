alter table "public"."user_subscriptions" add column "apple_original_transaction_id" text;

CREATE INDEX idx_user_subscriptions_apple_id ON public.user_subscriptions USING btree (apple_original_transaction_id);


