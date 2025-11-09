
  create table "public"."stripe_accounts" (
    "profile_id" uuid not null,
    "stripe_customer_id" text,
    "default_payment_method_id" text,
    "pm_brand" text,
    "pm_last4" text,
    "pm_exp_month" integer,
    "pm_exp_year" integer,
    "created_at" timestamp with time zone not null default now(),
    "updated_at" timestamp with time zone not null default now()
      );


alter table "public"."stripe_accounts" enable row level security;

CREATE UNIQUE INDEX stripe_accounts_pkey ON public.stripe_accounts USING btree (profile_id);

CREATE UNIQUE INDEX stripe_accounts_stripe_customer_id_key ON public.stripe_accounts USING btree (stripe_customer_id);

alter table "public"."stripe_accounts" add constraint "stripe_accounts_pkey" PRIMARY KEY using index "stripe_accounts_pkey";

alter table "public"."stripe_accounts" add constraint "stripe_accounts_profile_id_fkey" FOREIGN KEY (profile_id) REFERENCES public.profiles(id) ON DELETE CASCADE not valid;

alter table "public"."stripe_accounts" validate constraint "stripe_accounts_profile_id_fkey";

alter table "public"."stripe_accounts" add constraint "stripe_accounts_stripe_customer_id_key" UNIQUE using index "stripe_accounts_stripe_customer_id_key";

grant delete on table "public"."stripe_accounts" to "anon";

grant insert on table "public"."stripe_accounts" to "anon";

grant references on table "public"."stripe_accounts" to "anon";

grant select on table "public"."stripe_accounts" to "anon";

grant trigger on table "public"."stripe_accounts" to "anon";

grant truncate on table "public"."stripe_accounts" to "anon";

grant update on table "public"."stripe_accounts" to "anon";

grant delete on table "public"."stripe_accounts" to "authenticated";

grant insert on table "public"."stripe_accounts" to "authenticated";

grant references on table "public"."stripe_accounts" to "authenticated";

grant select on table "public"."stripe_accounts" to "authenticated";

grant trigger on table "public"."stripe_accounts" to "authenticated";

grant truncate on table "public"."stripe_accounts" to "authenticated";

grant update on table "public"."stripe_accounts" to "authenticated";

grant delete on table "public"."stripe_accounts" to "service_role";

grant insert on table "public"."stripe_accounts" to "service_role";

grant references on table "public"."stripe_accounts" to "service_role";

grant select on table "public"."stripe_accounts" to "service_role";

grant trigger on table "public"."stripe_accounts" to "service_role";

grant truncate on table "public"."stripe_accounts" to "service_role";

grant update on table "public"."stripe_accounts" to "service_role";


  create policy "stripe_accounts: select if self"
  on "public"."stripe_accounts"
  as permissive
  for select
  to public
using ((profile_id = ( SELECT auth.uid() AS uid)));


CREATE TRIGGER set_stripe_accounts_updated_at BEFORE UPDATE ON public.stripe_accounts FOR EACH ROW EXECUTE FUNCTION public.handle_updated_at();


