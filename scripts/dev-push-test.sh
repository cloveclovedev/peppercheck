#!/usr/bin/env bash
# dev push e2e test: (re)seed the vault secrets that notify_event reads, then fire
# a notification to a signed-in user so you can confirm the push arrives on the
# device. Reuses the production notify_event + an existing template key (no
# debug-only schema/i18n added).
#
# Prereqs:
#   1. Local Supabase running (supabase start).
#   2. In a separate terminal, the Edge Function served with the dev FCM SA:
#        supabase functions serve send-notification --env-file supabase/functions/.env
#   3. The user signed in on a dev build, so their FCM token is registered.
#
# Usage:
#   scripts/dev-push-test.sh <user-uuid|email> [template_key] [arg ...]
# Defaults: template_key=notification_request_matched_tasker, args=['Test'].
set -euo pipefail
command -v jq >/dev/null || { echo "ERROR: jq not installed" >&2; exit 1; }

who="${1:?usage: $0 <user-uuid|email> [template_key] [args...]}"; shift
template_key="${1:-notification_request_matched_tasker}"; [[ $# -gt 0 ]] && shift || true

# Remaining args -> a Postgres text[] literal (default a single dummy arg).
if [[ $# -gt 0 ]]; then
  args_sql="ARRAY["
  for a in "$@"; do args_sql+="'${a//\'/\'\'}',"; done
  args_sql="${args_sql%,}]::text[]"
else
  args_sql="ARRAY['Test']::text[]"
fi

# Resolve the user: a UUID is used as-is; anything containing '@' is looked up by email.
if [[ "$who" == *"@"* ]]; then
  user_sql="(select id from auth.users where email = '${who//\'/\'\'}' order by created_at desc limit 1)"
else
  user_sql="'${who}'::uuid"
fi

srk="$(supabase status -o json 2>/dev/null | jq -r '.SERVICE_ROLE_KEY // empty')"
[[ -n "$srk" ]] || { echo "ERROR: could not read SERVICE_ROLE_KEY from 'supabase status'" >&2; exit 1; }

docker exec -i supabase_db_supabase psql -U postgres -v ON_ERROR_STOP=1 <<SQL
-- (re)seed, idempotently, the two secrets notify_event reads
delete from vault.secrets where name in ('send_notification_url','service_role_key');
select vault.create_secret('http://host.docker.internal:54321/functions/v1/send-notification','send_notification_url');
select vault.create_secret('${srk}','service_role_key');
-- fire the notification
select public.notify_event(${user_sql}, '${template_key}', ${args_sql});
SQL
echo "[ok] notify_event('${who}', '${template_key}') fired — check the device for the push."
