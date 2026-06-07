#!/usr/bin/env bash
# Creates a peppercheck-staging deploy service account with FCM + FAD
# admin roles and downloads its JSON key.
#
# Usage: scripts/setup/bootstrap-peppercheck-staging-sa.sh
# Pre-req: gcloud installed and authenticated against an account with
# resourcemanager.projects.setIamPolicy on peppercheck-staging.
#
# Idempotent: re-running detects an existing SA + role bindings and only
# adds a new JSON key. Previous keys are NOT auto-revoked; rotate
# manually via `gcloud iam service-accounts keys delete` when needed.
#
# Output:
#   ~/.config/peppercheck/peppercheck-staging-sa.json (mode 0600)
#
# Next step:
#   scripts/setup/setup-deploy-secrets.sh \
#     ~/.config/peppercheck/peppercheck-staging-sa.json

set -euo pipefail

command -v gcloud >/dev/null || { echo "ERROR: gcloud CLI not installed" >&2; exit 1; }

project="peppercheck-staging"
sa_name="github-actions-deploy"
sa_email="${sa_name}@${project}.iam.gserviceaccount.com"
output_dir="${HOME}/.config/peppercheck"
output_key="${output_dir}/peppercheck-staging-sa.json"

# Auto-detect which authenticated gcloud account has access to the
# project. Avoids the "wrong active account" footgun on workstations
# with multiple gcloud identities.
active_account=""
for acct in $(gcloud auth list --filter=-status:revoked --format="value(account)" 2>/dev/null); do
  if gcloud projects describe "$project" --account="$acct" --quiet >/dev/null 2>&1; then
    active_account="$acct"
    break
  fi
done

if [[ -z "$active_account" ]]; then
  echo "ERROR: no authenticated gcloud account can access project '$project'." >&2
  echo "       Authenticated accounts:" >&2
  gcloud auth list --filter=-status:revoked --format="value(account)" 2>/dev/null | sed 's/^/         /' >&2
  echo "" >&2
  echo "       If one of these SHOULD have access, the token may be expired." >&2
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
    --display-name="GitHub Actions deploy" \
    --project "$project" --account="$active_account" --quiet >/dev/null
fi

for role in \
  "roles/firebasecloudmessaging.admin" \
  "roles/firebaseappdistro.admin"; do
  echo "[grant] ${role}"
  gcloud projects add-iam-policy-binding "$project" \
    --member="serviceAccount:${sa_email}" \
    --role="${role}" \
    --quiet >/dev/null
done

echo "[key-create] writing to ${output_key}"
gcloud iam service-accounts keys create "$output_key" \
  --iam-account="$sa_email" \
  --project "$project" \
  --quiet >/dev/null

chmod 600 "$output_key"

echo
echo "Done. SA key saved to: ${output_key}"
echo "Next: scripts/setup/setup-deploy-secrets.sh \"${output_key}\""
