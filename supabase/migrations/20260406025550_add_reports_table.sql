create type "public"."report_content_type" as enum ('task_description', 'evidence', 'judgement');

create type "public"."report_reason" as enum ('inappropriate_content', 'harassment', 'spam', 'other');

create type "public"."report_status" as enum ('pending', 'reviewing', 'resolved', 'dismissed');

create type "public"."reporter_role" as enum ('tasker', 'referee');


  create table "public"."reports" (
    "id" uuid not null default gen_random_uuid(),
    "reporter_id" uuid not null,
    "task_id" uuid not null,
    "reporter_role" public.reporter_role not null,
    "content_type" public.report_content_type not null,
    "content_id" uuid,
    "reason" public.report_reason not null,
    "detail" text,
    "status" public.report_status not null default 'pending'::public.report_status,
    "admin_note" text,
    "resolved_at" timestamp with time zone,
    "created_at" timestamp with time zone not null default now(),
    "updated_at" timestamp with time zone not null default now()
      );


alter table "public"."reports" enable row level security;

CREATE INDEX idx_reports_created_at ON public.reports USING btree (created_at);

CREATE INDEX idx_reports_status ON public.reports USING btree (status);

CREATE INDEX idx_reports_task_id ON public.reports USING btree (task_id);

CREATE UNIQUE INDEX reports_pkey ON public.reports USING btree (id);

CREATE UNIQUE INDEX reports_unique_per_user_task ON public.reports USING btree (reporter_id, task_id);

alter table "public"."reports" add constraint "reports_pkey" PRIMARY KEY using index "reports_pkey";

alter table "public"."reports" add constraint "reports_reporter_id_fkey" FOREIGN KEY (reporter_id) REFERENCES auth.users(id) ON DELETE CASCADE not valid;

alter table "public"."reports" validate constraint "reports_reporter_id_fkey";

alter table "public"."reports" add constraint "reports_task_id_fkey" FOREIGN KEY (task_id) REFERENCES public.tasks(id) ON DELETE CASCADE not valid;

alter table "public"."reports" validate constraint "reports_task_id_fkey";

alter table "public"."reports" add constraint "reports_unique_per_user_task" UNIQUE using index "reports_unique_per_user_task";

grant delete on table "public"."reports" to "anon";

grant insert on table "public"."reports" to "anon";

grant references on table "public"."reports" to "anon";

grant select on table "public"."reports" to "anon";

grant trigger on table "public"."reports" to "anon";

grant truncate on table "public"."reports" to "anon";

grant update on table "public"."reports" to "anon";

grant delete on table "public"."reports" to "authenticated";

grant insert on table "public"."reports" to "authenticated";

grant references on table "public"."reports" to "authenticated";

grant select on table "public"."reports" to "authenticated";

grant trigger on table "public"."reports" to "authenticated";

grant truncate on table "public"."reports" to "authenticated";

grant update on table "public"."reports" to "authenticated";

grant delete on table "public"."reports" to "service_role";

grant insert on table "public"."reports" to "service_role";

grant references on table "public"."reports" to "service_role";

grant select on table "public"."reports" to "service_role";

grant trigger on table "public"."reports" to "service_role";

grant truncate on table "public"."reports" to "service_role";

grant update on table "public"."reports" to "service_role";


  create policy "reports: insert own"
  on "public"."reports"
  as permissive
  for insert
  to public
with check ((reporter_id = ( SELECT auth.uid() AS uid)));



  create policy "reports: select own"
  on "public"."reports"
  as permissive
  for select
  to public
using ((reporter_id = ( SELECT auth.uid() AS uid)));


CREATE TRIGGER on_reports_update_set_updated_at BEFORE UPDATE ON public.reports FOR EACH ROW EXECUTE FUNCTION public.handle_updated_at();


