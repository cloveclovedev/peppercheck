#!/usr/bin/env bash
# Idempotently register the Android and iOS Firebase apps for a given env,
# and download both google-services.json and GoogleService-Info-<Env>.plist
# into their per-flavor repo paths (gitignored).
#
# Usage: scripts/setup/register-firebase-apps.sh {dev|staging|production}
# Pre-req: `firebase login`, `jq` on PATH, and (for dev/staging) the projects
# created by bootstrap-firebase-projects.sh.
#
# The Firebase projectId is resolved from the project's displayName at runtime,
# so this script does not hardcode the production project's auto-suffixed ID.
#
# For production, the Firebase project and both Android/iOS app entries pre-exist;
# the script will skip apps:create and only re-download configs (useful for
# re-onboarding a workstation).

set -euo pipefail

command -v firebase >/dev/null || { echo "ERROR: firebase CLI not installed" >&2; exit 1; }
command -v jq >/dev/null || { echo "ERROR: jq not installed" >&2; exit 1; }

env="${1:-}"
case "$env" in
  dev)        project_display="peppercheck-dev";     suffix=".dev";     cap_env="Dev" ;;
  staging)    project_display="peppercheck-staging"; suffix=".staging"; cap_env="Staging" ;;
  production) project_display="peppercheck";         suffix="";         cap_env="Production" ;;
  *) echo "Usage: $0 {dev|staging|production}" >&2; exit 1 ;;
esac

base_bundle="dev.cloveclove.peppercheck"
bundle_id="${base_bundle}${suffix}"

# Resolve the Firebase projectId from its displayName at runtime so the script
# stays portable across operators / re-created projects and avoids committing
# the auto-suffixed production projectId to a public repo.
project_id="$(firebase projects:list --json | jq -r ".result[] | select(.displayName == \"$project_display\") | .projectId" | head -n1)"
if [[ -z "$project_id" ]]; then
  echo "ERROR: no Firebase project found with displayName '$project_display'" >&2
  echo "       Run scripts/setup/bootstrap-firebase-projects.sh first, or rename the project to match." >&2
  exit 1
fi

repo_root="$(git rev-parse --show-toplevel)"
android_dest="$repo_root/peppercheck_flutter/android/app/src/${env}/google-services.json"
ios_dest="$repo_root/peppercheck_flutter/ios/Runner/Firebase/GoogleService-Info-${cap_env}.plist"

mkdir -p "$(dirname "$android_dest")"
mkdir -p "$(dirname "$ios_dest")"

apps_json="$(firebase apps:list --project "$project_id" --json)"

# --- Android ---
android_app_id="$(echo "$apps_json" | jq -r ".result[] | select(.platform == \"ANDROID\" and (.namespace // \"\") == \"$bundle_id\") | .appId" | head -n1)"
if [[ -z "$android_app_id" ]]; then
  echo "[create-android] $bundle_id in $project_id"
  firebase apps:create ANDROID "PepperCheck $cap_env (Android)" --package-name "$bundle_id" --project "$project_id"
  apps_json="$(firebase apps:list --project "$project_id" --json)"
  android_app_id="$(echo "$apps_json" | jq -r ".result[] | select(.platform == \"ANDROID\" and (.namespace // \"\") == \"$bundle_id\") | .appId" | head -n1)"
else
  echo "[skip-android] $bundle_id app already exists in $project_id"
fi
rm -f "$android_dest"
firebase apps:sdkconfig ANDROID "$android_app_id" --project "$project_id" --out "$android_dest"
echo "[ok] wrote $android_dest"

# --- iOS ---
ios_app_id="$(echo "$apps_json" | jq -r ".result[] | select(.platform == \"IOS\" and (.namespace // \"\") == \"$bundle_id\") | .appId" | head -n1)"
if [[ -z "$ios_app_id" ]]; then
  echo "[create-ios] $bundle_id in $project_id"
  firebase apps:create IOS "PepperCheck $cap_env (iOS)" --bundle-id "$bundle_id" --project "$project_id"
  apps_json="$(firebase apps:list --project "$project_id" --json)"
  ios_app_id="$(echo "$apps_json" | jq -r ".result[] | select(.platform == \"IOS\" and (.namespace // \"\") == \"$bundle_id\") | .appId" | head -n1)"
else
  echo "[skip-ios] $bundle_id app already exists in $project_id"
fi
rm -f "$ios_dest"
firebase apps:sdkconfig IOS "$ios_app_id" --project "$project_id" --out "$ios_dest"
echo "[ok] wrote $ios_dest"
