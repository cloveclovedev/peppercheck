#!/usr/bin/env bash
# Seed vault.secrets for local Supabase after `supabase start` / `supabase db reset`.
# 前提: supabase start 済みで `supabase status` から Service role key を取れること。
# - billing_worker_url / payout_worker_url はローカル固定値 (kong:8000) をセット
# - service_role_key は supabase status の出力のみから取得（env や .env は見ない）
#
# Optional:
#   SUPABASE_DB_URL (default: postgres://postgres:postgres@localhost:54322/postgres)
#
# Usage:
#   ./scripts/seed_vault_local.sh

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
DB_URL="${SUPABASE_DB_URL:-postgresql://postgres:postgres@localhost:54322/postgres}"

# Local defaults for functions when using `supabase start`
BILLING_WORKER_URL="${BILLING_WORKER_URL:-http://kong:8000/functions/v1/billing-worker}"
PAYOUT_WORKER_URL="${PAYOUT_WORKER_URL:-http://kong:8000/functions/v1/payout-worker}"

get_service_role_key() {
  # supabase status（ローカル起動後）から取得
  if command -v supabase >/dev/null 2>&1; then
    local val
    val=$(supabase status 2>/dev/null | grep -i "^ *Secret key" | awk -F': ' '{print $2}' | head -n1)
    if [[ -n "$val" ]]; then
      printf "%s" "$val"
      return
    fi
  fi
  return 1
}

SERVICE_ROLE_KEY="$(get_service_role_key || true)"
if [[ -z "$SERVICE_ROLE_KEY" ]]; then
  echo "SERVICE_ROLE_KEY not found. Run 'supabase start' first so 'supabase status' exposes it." >&2
  exit 1
fi

escape_sql() {
  printf "%s" "$1" | sed "s/'/''/g"
}

billing_url_esc=$(escape_sql "$BILLING_WORKER_URL")
payout_url_esc=$(escape_sql "$PAYOUT_WORKER_URL")
service_role_key_esc=$(escape_sql "$SERVICE_ROLE_KEY")

cat <<SQL | psql "$DB_URL" >/dev/null
DO \$\$
BEGIN
  -- billing_worker_url
  BEGIN
    PERFORM vault.create_secret(secret := '$billing_url_esc', name := 'billing_worker_url', description := 'local dev billing worker url');
  EXCEPTION WHEN unique_violation THEN
    UPDATE vault.secrets SET secret = '$billing_url_esc', description = 'local dev billing worker url' WHERE name = 'billing_worker_url';
  END;

  -- payout_worker_url
  BEGIN
    PERFORM vault.create_secret(secret := '$payout_url_esc', name := 'payout_worker_url', description := 'local dev payout worker url');
  EXCEPTION WHEN unique_violation THEN
    UPDATE vault.secrets SET secret = '$payout_url_esc', description = 'local dev payout worker url' WHERE name = 'payout_worker_url';
  END;

  -- service_role_key
  BEGIN
    PERFORM vault.create_secret(secret := '$service_role_key_esc', name := 'service_role_key', description := 'local dev service role key');
  EXCEPTION WHEN unique_violation THEN
    UPDATE vault.secrets SET secret = '$service_role_key_esc', description = 'local dev service role key' WHERE name = 'service_role_key';
  END;
END
$$;
SQL

echo "Seeded vault.secrets into $DB_URL"

