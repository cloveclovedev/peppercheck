#!/usr/bin/env bash
# READ-ONLY preflight for the Firebase auth operator checklist.
# For each Firebase project it reports what is ALREADY configured vs missing:
#   - Google / Apple sign-in providers enabled
#   - "one account per email" (allowDuplicateEmails = false)
#   - Android apps + registered SHA certificates (SHA-1 / SHA-256)
#   - iOS apps + bundle IDs
# so you don't blindly re-do steps that #427/#425 already completed.
#
# Nothing is modified. Requires: gcloud (authenticated as a project owner/editor),
# firebase CLI (only for auto-listing projects), python3, curl.
#
# Usage:
#   scripts/phase2-auth-preflight.sh                 # auto-list your projects, then check peppercheck*
#   scripts/phase2-auth-preflight.sh PROJECT_ID ...  # check exactly these project IDs
set -euo pipefail

command -v gcloud  >/dev/null || { echo "need gcloud (brew install --cask gcloud-cli / google-cloud-sdk)"; exit 1; }
command -v python3 >/dev/null || { echo "need python3"; exit 1; }
command -v curl    >/dev/null || { echo "need curl"; exit 1; }

TOKEN="$(gcloud auth print-access-token 2>/dev/null)" || {
  echo "Could not get an access token. Run: gcloud auth login"; exit 1; }

PROJECTS=("$@")
if [ ${#PROJECTS[@]} -eq 0 ]; then
  echo "No project IDs given. Discovering with 'firebase projects:list'..."
  if command -v firebase >/dev/null; then
    firebase projects:list 2>/dev/null || true
    echo
    echo "Re-run with the exact project IDs, e.g.:"
    echo "  $0 peppercheck-dev peppercheck-staging peppercheck-XXXXXX"
  else
    echo "firebase CLI not found; pass project IDs explicitly."
  fi
  exit 0
fi

# curl a GET endpoint; append the HTTP status as a trailing line.
# User credentials need a quota project for these APIs (X-Goog-User-Project);
# QUOTA_PROJECT is set to the project under inspection in the loop below.
QUOTA_PROJECT=""
api_get() {
  curl -sS -w '\n%{http_code}' \
    -H "Authorization: Bearer $TOKEN" \
    -H "X-Goog-User-Project: $QUOTA_PROJECT" \
    "$1"
}

parse() { python3 "$(dirname "$0")/.phase2_preflight_parse.py" "$@"; }

for P in "${PROJECTS[@]}"; do
  echo "============================================================"
  echo "PROJECT: $P"
  echo "============================================================"
  QUOTA_PROJECT="$P"

  idp="$(api_get "https://identitytoolkit.googleapis.com/admin/v2/projects/$P/defaultSupportedIdpConfigs")"
  echo "$idp" | parse idp

  cfg="$(api_get "https://identitytoolkit.googleapis.com/admin/v2/projects/$P/config")"
  echo "$cfg" | parse config

  andro="$(api_get "https://firebase.googleapis.com/v1beta1/projects/$P/androidApps")"
  app_ids="$(echo "$andro" | parse android_apps_ids)"
  echo "$andro" | parse android_apps_header
  if [ -n "$app_ids" ]; then
    while IFS= read -r appid; do
      [ -z "$appid" ] && continue
      sha="$(api_get "https://firebase.googleapis.com/v1beta1/projects/$P/androidApps/$appid/sha")"
      echo "$sha" | parse sha "$appid"
    done <<< "$app_ids"
  fi

  ios="$(api_get "https://firebase.googleapis.com/v1beta1/projects/$P/iosApps")"
  echo "$ios" | parse ios_apps
  echo
done

echo "Legend: [OK] done   [--] missing/needs action   [??] could not read (API disabled or no permission)"
