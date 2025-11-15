alter table "public"."stripe_accounts" add column "charges_enabled" boolean default false;

alter table "public"."stripe_accounts" add column "connect_requirements" jsonb;

alter table "public"."stripe_accounts" add column "payouts_enabled" boolean default false;

alter table "public"."stripe_accounts" add column "stripe_connect_account_id" text;

CREATE UNIQUE INDEX stripe_accounts_stripe_connect_account_id_key ON public.stripe_accounts USING btree (stripe_connect_account_id);

alter table "public"."stripe_accounts" add constraint "stripe_accounts_stripe_connect_account_id_key" UNIQUE using index "stripe_accounts_stripe_connect_account_id_key";


