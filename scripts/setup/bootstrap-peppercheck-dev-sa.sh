#!/usr/bin/env bash
# Creates a peppercheck-dev service account with the FCM admin role, downloads
# its JSON key, and wires it into supabase/functions/.env as
# FIREBASE_SERVICE_ACCOUNT_JSON so the LOCAL send-notification Edge Function can
# deliver pushes to the dev Firebase project (FCM tokens are project-scoped, so
# the local function must authenticate against peppercheck-dev, not staging).
#
# Usage: scripts/setup/bootstrap-peppercheck-dev-sa.sh
# Pre-req: gcloud installed and authenticated against an account with
# resourcemanager.projects.setIamPolicy on peppercheck-dev; jq on PATH.
#
# Idempotent: re-running detects an existing SA + role binding and only adds a
# new JSON key. Previous keys are NOT auto-revoked; rotate manually via
# `gcloud iam service-accounts keys delete` when needed.
#
# Output:
#   ~/.config/peppercheck/peppercheck-dev-sa.json (mode 0600)
#   supabase/functions/.env  (FIREBASE_SERVICE_ACCOUNT_JSON = raw minified JSON)

set -euo pipefail

command -v gcloud >/dev/null || { echo "ERROR: gcloud CLI not installed" >&2; exit 1; }
command -v jq >/dev/null     || { echo "ERROR: jq not installed" >&2; exit 1; }

project="peppercheck-dev"
sa_name="local-edge-fcm"
sa_email="${sa_name}@${project}.iam.gserviceaccount.com"
output_dir="${HOME}/.config/peppercheck"
output_key="${output_dir}/peppercheck-dev-sa.json"
repo_root="$(git rev-parse --show-toplevel)"
env_file="${repo_root}/supabase/functions/.env"
env_example="${repo_root}/supabase/functions/.env.example"

# Auto-detect which authenticated gcloud account can access the project (avoids
# the "wrong active account" footgun on workstations with multiple identities).
active_account=""
for acct in $(gcloud auth list --filter=-status:revoked --format="value(account)" 2>/dev/null); do
  if gcloud projects describe "$project" --account="$acct" --quiet >/dev/null 2>&1; then
    active_account="$acct"
    break
  fi
done
if [[ -z "$active_account" ]]; then
  echo "ERROR: no authenticated gcloud account can access project '$project'." >&2
  echo "       Re-authenticate with: gcloud auth login <email>" >&2
  exit 1
fi
echo "[account] using ${active_account}"

mkdir -p "$output_dir"
chmod 700 "$output_dir"

if gcloud iam service-accounts describe "$sa_email" --project "$project" --account="$active_account" --quiet >/dev/null 2>&1; then
  echo "[skip] service account ${sa_email} already exists"
else
  echo "[create] service account ${sa_email}"
  gcloud iam service-accounts create "$sa_name" \
    --display-name="Local Edge Function FCM sender" \
    --project "$project" --account="$active_account" --quiet >/dev/null
fi

echo "[grant] roles/firebasecloudmessaging.admin"
gcloud projects add-iam-policy-binding "$project" \
  --member="serviceAccount:${sa_email}" \
  --role="roles/firebasecloudmessaging.admin" \
  --account="$active_account" --quiet >/dev/null

echo "[key-create] writing to ${output_key}"
gcloud iam service-accounts keys create "$output_key" \
  --iam-account="$sa_email" \
  --project "$project" \
  --account="$active_account" --quiet >/dev/null
chmod 600 "$output_key"

# Wire into supabase/functions/.env as RAW minified JSON — no wrapping quotes.
# Wrap-quoting the value breaks JSON.parse in the send-notification function.
[[ -f "$env_file" ]] || cp "$env_example" "$env_file"
minified="$(jq -c . "$output_key")"
tmp="$(mktemp)"
grep -v '^FIREBASE_SERVICE_ACCOUNT_JSON=' "$env_file" > "$tmp" || true
printf 'FIREBASE_SERVICE_ACCOUNT_JSON=%s\n' "$minified" >> "$tmp"
mv "$tmp" "$env_file"
echo "[ok] wired FIREBASE_SERVICE_ACCOUNT_JSON (peppercheck-dev) into $env_file"

# Self-check: the written value must parse back as JSON (no wrapping quotes) with
# the expected project_id — send-notification does JSON.parse on it, and
# wrap-quoting the value would break that parse.
written="$(grep '^FIREBASE_SERVICE_ACCOUNT_JSON=' "$env_file" | sed 's/^FIREBASE_SERVICE_ACCOUNT_JSON=//')"
if echo "$written" | jq -e '.project_id' >/dev/null 2>&1; then
  echo "[verify] value parses as JSON; project_id=$(echo "$written" | jq -r .project_id)"
else
  echo "[warn] written value does not parse as JSON — check for wrapping quotes" >&2
fi
