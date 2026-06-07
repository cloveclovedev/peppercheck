#!/usr/bin/env bash
# Set the BETA_* / PROD_* GitHub Secrets needed by deploy-beta.yml and
# deploy-production.yml after the Phase 1 multi-environment setup
# (issue #423 / spec 2026-06-05-android-flavor-split-design.md).
#
# Usage: scripts/setup/setup-deploy-secrets.sh <path-to-peppercheck-staging-sa.json>
#
# The argument is normally the file written by
# bootstrap-peppercheck-staging-sa.sh
# (~/.config/peppercheck-secrets/peppercheck-staging-sa.json).
#
# Pre-req:
# - gh CLI logged in with repo write access to cloveclovedev/peppercheck.
# - firebase CLI logged in and able to query peppercheck-staging.
# - Staging and production google-services.json already downloaded to
#   peppercheck_flutter/android/app/src/{staging,production}/ via
#   scripts/setup/register-firebase-apps.sh.
#
# Sets four GitHub Secrets:
#   BETA_FIREBASE_SERVICE_ACCOUNT_JSON  (verbatim contents of the SA JSON)
#   BETA_FIREBASE_APP_ID                (the staging Android FAD app ID)
#   BETA_GOOGLE_SERVICES_JSON           (verbatim google-services.json for staging)
#   PROD_GOOGLE_SERVICES_JSON           (verbatim google-services.json for production)
#
# All secret values are passed via STDIN redirect (or short non-secret
# arguments) so credentials never appear in the command line, process
# list, or terminal output.

set -euo pipefail

command -v gh >/dev/null || { echo "ERROR: gh CLI not installed" >&2; exit 1; }
command -v firebase >/dev/null || { echo "ERROR: firebase CLI not installed" >&2; exit 1; }
command -v jq >/dev/null || { echo "ERROR: jq not installed" >&2; exit 1; }

sa_json="${1:-}"
if [[ -z "$sa_json" ]]; then
  echo "Usage: $0 <path-to-peppercheck-staging-sa.json>" >&2
  exit 1
fi
if [[ ! -f "$sa_json" ]]; then
  echo "ERROR: service account JSON not found at: $sa_json" >&2
  exit 1
fi

repo="cloveclovedev/peppercheck"
repo_root="$(git rev-parse --show-toplevel)"
staging_gs="${repo_root}/peppercheck_flutter/android/app/src/staging/google-services.json"
prod_gs="${repo_root}/peppercheck_flutter/android/app/src/production/google-services.json"

[[ -f "$staging_gs" ]] || {
  echo "ERROR: staging google-services.json missing at ${staging_gs}" >&2
  echo "       Run: scripts/setup/register-firebase-apps.sh staging" >&2
  exit 1
}
[[ -f "$prod_gs" ]] || {
  echo "ERROR: production google-services.json missing at ${prod_gs}" >&2
  echo "       Run: scripts/setup/register-firebase-apps.sh production" >&2
  exit 1
}

# Resolve the staging Android FAD App ID from Firebase API. Note that
# this value is an identifier (it appears verbatim in the published
# google-services.json shipped with the APK) so it is not credential-tier.
fad_app_id="$(firebase apps:list --project peppercheck-staging --json \
  | jq -r '.result[] | select(.platform == "ANDROID") | .appId' \
  | head -n1)"
if [[ -z "$fad_app_id" ]]; then
  echo "ERROR: could not resolve a staging Android app in peppercheck-staging." >&2
  echo "       Run scripts/setup/register-firebase-apps.sh staging first." >&2
  exit 1
fi

# Each gh secret set call streams the value via STDIN (no `--body` for
# credentials) so it never appears on the command line or in process
# listings. Output is redirected to /dev/null as defense-in-depth; gh's
# success message normally echoes only the secret name.
#
# BETA_FIREBASE_SERVICE_ACCOUNT_JSON MUST be a flat single-line JSON.
# deploy-beta.yml writes it into a Supabase env file
# (`printf "FIREBASE_SERVICE_ACCOUNT_JSON='%s'\n" ...`), and the env-file
# parser only accepts one-line-per-variable. A multi-line value silently
# breaks send-notification's JSON.parse at Edge Function runtime.
# See scripts/github-secrets.example for the same constraint on
# PROD_FIREBASE_SERVICE_ACCOUNT_JSON / *_GOOGLE_PLAY_SERVICE_ACCOUNT_JSON.

jq -c . < "$sa_json" | gh secret set BETA_FIREBASE_SERVICE_ACCOUNT_JSON --repo "$repo" >/dev/null
echo "[ok] BETA_FIREBASE_SERVICE_ACCOUNT_JSON"

# FAD App ID is identifier-tier (it appears in the published APK's
# google-services.json). --body is acceptable here.
gh secret set BETA_FIREBASE_APP_ID --repo "$repo" --body "$fad_app_id" >/dev/null
echo "[ok] BETA_FIREBASE_APP_ID"

# google-services.json secrets are written into a plain JSON file by the
# workflow (`echo '${{ secrets.X }}' > .../google-services.json`), not
# into an env file, so multi-line raw is acceptable. STDIN redirect keeps
# the value off the command line.
gh secret set BETA_GOOGLE_SERVICES_JSON --repo "$repo" < "$staging_gs" >/dev/null
echo "[ok] BETA_GOOGLE_SERVICES_JSON"

gh secret set PROD_GOOGLE_SERVICES_JSON --repo "$repo" < "$prod_gs" >/dev/null
echo "[ok] PROD_GOOGLE_SERVICES_JSON"

echo
echo "Verify with:"
echo "  gh secret list --repo ${repo} | grep -E '^(BETA|PROD)_'"
