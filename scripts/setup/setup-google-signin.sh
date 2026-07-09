#!/usr/bin/env bash
# Per-environment Google Sign-In setup — idempotent and declarative.
#
# Converges the current state toward "fully configured" and prints, on every
# run, the current state and the next action. There is no "first run vs later
# run" mode: rerunning is always safe and just skips whatever is already done.
#
# Pipeline:
#   1. Register the app signing SHA-1 (the Android OAuth client is keyed on it).
#   2. Re-download google-services.json + GoogleService-Info-<Env>.plist.
#   3. Verify the OAuth clients (Web/Android/iOS) exist in those configs.
#      They are created by a ONE-TIME MANUAL prerequisite, done once per env in
#      the Firebase/Cloud Console (intentionally NOT scripted):
#        a. Create the OAuth consent screen (branding).
#        b. Enable the Google provider in Firebase Authentication.
#      Enabling the Google provider auto-creates the Web/Android/iOS clients and
#      writes them into the config files. If they are absent, this script prints
#      that checkpoint and stops.
#   4. Reflect the iOS redirect scheme into the gitignored xcconfig.       [Task 3]
#   5. Configure the Supabase Google provider (both client IDs, Web first). [Task 4]
#
# Usage: scripts/setup/setup-google-signin.sh {dev|staging|production}
# Pre-req: `firebase login`; `jq`; PlistBuddy (macOS). For dev, the release
# keystore and peppercheck_flutter/android/key.properties are read at runtime to
# derive the SHA-1 (their secret values are never printed).
set -euo pipefail

command -v firebase >/dev/null || { echo "ERROR: firebase CLI not installed" >&2; exit 1; }
command -v jq >/dev/null       || { echo "ERROR: jq not installed" >&2; exit 1; }

env="${1:-}"
case "$env" in
  dev)        project_display="peppercheck-dev";     suffix=".dev";     cap_env="Dev" ;;
  staging)    project_display="peppercheck-staging"; suffix=".staging"; cap_env="Staging" ;;
  production) project_display="peppercheck";         suffix="";         cap_env="Production" ;;
  *) echo "Usage: $0 {dev|staging|production}" >&2; exit 1 ;;
esac

base_bundle="dev.cloveclove.peppercheck"
bundle_id="${base_bundle}${suffix}"
repo_root="$(git rev-parse --show-toplevel)"
android_dest="$repo_root/peppercheck_flutter/android/app/src/${env}/google-services.json"
ios_dest="$repo_root/peppercheck_flutter/ios/Runner/Firebase/GoogleService-Info-${cap_env}.plist"

# Resolve the Firebase projectId from its displayName at runtime (same approach
# as register-firebase-apps.sh) so nothing env-specific is hardcoded.
project_id="$(firebase projects:list --json | jq -r ".result[] | select(.displayName == \"$project_display\") | .projectId" | head -n1)"
[[ -n "$project_id" ]] || { echo "ERROR: no Firebase project with displayName '$project_display'" >&2; exit 1; }

# --- 1. Determine the signing SHA-1 ---------------------------------------
# dev debug builds (flutter run / --debug) sign with the standard Android debug
# keystore, so register ITS SHA-1 — NOT the release peppercheck.jks, which is a
# legacy pre-Play-App-Signing production key. staging/production sign via Google
# Play App Signing; that SHA lives in the Play Console and is passed via SHA1=
# (optional — omit it to only reconcile configs/provider for an additive change).
sha1=""
if [[ "$env" == "dev" ]]; then
  # Resolve the debug keystore across the common ANDROID_USER_HOME /
  # ANDROID_SDK_HOME / ~/.android layouts (alias + password are the fixed Android
  # defaults: androiddebugkey / "android").
  debug_keystore=""
  for cand in \
    "${ANDROID_USER_HOME:-}/debug.keystore" \
    "${ANDROID_SDK_HOME:-}/.android/debug.keystore" \
    "$HOME/.config/.android/debug.keystore" \
    "$HOME/.android/debug.keystore"; do
    if [[ -n "$cand" && -f "$cand" ]]; then debug_keystore="$cand"; break; fi
  done
  [[ -n "$debug_keystore" ]] || { echo "ERROR: debug.keystore not found (build a dev debug APK once to generate it)" >&2; exit 1; }
  sha1="$(keytool -list -v -keystore "$debug_keystore" -alias androiddebugkey -storepass android 2>/dev/null \
          | awk -F': ' '/SHA1:/ {print $2; exit}')"
  [[ -n "$sha1" ]] || { echo "ERROR: could not read SHA-1 from $debug_keystore" >&2; exit 1; }
else
  sha1="${SHA1:-}"
fi

# --- 2. Register the SHA-1 idempotently -----------------------------------
android_app_id="$(firebase apps:list --project "$project_id" --json \
  | jq -r ".result[] | select(.platform == \"ANDROID\" and (.namespace // \"\") == \"$bundle_id\") | .appId" | head -n1)"
[[ -n "$android_app_id" ]] || { echo "ERROR: no Android app for $bundle_id — run register-firebase-apps.sh $env first" >&2; exit 1; }

sha_state="none"
if [[ -n "$sha1" ]]; then
  sha_norm="$(echo "$sha1" | tr -d ':' | tr 'A-F' 'a-f')"
  if firebase apps:android:sha:list "$android_app_id" --project "$project_id" 2>/dev/null | tr 'A-F' 'a-f' | grep -qF "$sha_norm"; then
    sha_state="registered (already)"
  else
    firebase apps:android:sha:create "$android_app_id" "$sha1" --project "$project_id" >/dev/null
    sha_state="registered (new)"
  fi
else
  sha_state="skipped (no SHA1 provided for $env)"
fi

# --- 3. Re-download the config files --------------------------------------
mkdir -p "$(dirname "$android_dest")" "$(dirname "$ios_dest")"
rm -f "$android_dest"; firebase apps:sdkconfig ANDROID "$android_app_id" --project "$project_id" --out "$android_dest"
ios_app_id="$(firebase apps:list --project "$project_id" --json \
  | jq -r ".result[] | select(.platform == \"IOS\" and (.namespace // \"\") == \"$bundle_id\") | .appId" | head -n1)"
[[ -n "$ios_app_id" ]] || { echo "ERROR: no iOS app for $bundle_id — run register-firebase-apps.sh $env first" >&2; exit 1; }
rm -f "$ios_dest"; firebase apps:sdkconfig IOS "$ios_app_id" --project "$project_id" --out "$ios_dest"

# --- 4. Inspect the OAuth clients -----------------------------------------
web_client_id="$(jq -r '.client[0].oauth_client[]? | select(.client_type==3) | .client_id' "$android_dest" | head -n1)"
android_client_id="$(jq -r '.client[0].oauth_client[]? | select(.client_type==1) | .client_id' "$android_dest" | head -n1)"
ios_client_id="$(/usr/libexec/PlistBuddy -c 'Print :CLIENT_ID' "$ios_dest" 2>/dev/null || true)"

present() { [[ -n "$1" ]] && echo "present" || echo "MISSING"; }
echo ""
echo "[state] env=$env project=$project_id bundle=$bundle_id"
echo "        SHA-1:          $sha_state"
echo "        web client:     $(present "$web_client_id")"
echo "        android client: $(present "$android_client_id")"
echo "        ios client:     $(present "$ios_client_id")"

if [[ -z "$web_client_id" || -z "$android_client_id" || -z "$ios_client_id" ]]; then
  cat >&2 <<EOF

[next] OAuth clients are not fully present yet. Complete the one-time manual
       prerequisite in the Console for '$project_display', then re-run:
         1. Create the OAuth consent screen (branding): External + Testing is fine.
         2. Firebase Auth -> Sign-in method -> enable Google.
       Enabling the Google provider auto-creates the Web/Android/iOS clients and
       writes them into the config files this script just downloaded.
EOF
  exit 0
fi

# --- 5. Reflect the iOS redirect scheme into the (gitignored) xcconfig -----
# Replaces bootstrap-ios-secrets.sh's "production client ID to all three flavors":
# each env now writes its own iOS client into its own flavor xcconfig.
ios_reversed="$(/usr/libexec/PlistBuddy -c 'Print :REVERSED_CLIENT_ID' "$ios_dest" 2>/dev/null || true)"
xcconfig="$repo_root/peppercheck_flutter/ios/Flutter/Secrets/${cap_env}.secrets.xcconfig"
mkdir -p "$(dirname "$xcconfig")"
cat > "$xcconfig" <<EOF
GID_CLIENT_ID = $ios_client_id
GID_REVERSED_CLIENT_ID = $ios_reversed
EOF
echo "[ok] wrote $xcconfig"

# --- 6. Configure the Supabase Google provider (both client IDs, Web first) ---
# config.toml already sets client_id = env(GOOGLE_CLIENT_ID) with
# skip_nonce_check = true, so there is no structural change — only the value.
if [[ "$env" == "dev" ]]; then
  supabase_env="$repo_root/supabase/.env"
  [[ -f "$supabase_env" ]] || cp "$repo_root/supabase/.env.example" "$supabase_env"
  tmp="$(mktemp)"; grep -v '^GOOGLE_CLIENT_ID=' "$supabase_env" > "$tmp" || true
  printf 'GOOGLE_CLIENT_ID=%s,%s\n' "$web_client_id" "$ios_client_id" >> "$tmp"
  mv "$tmp" "$supabase_env"
  echo "[ok] set GOOGLE_CLIENT_ID=<web>,<ios> in supabase/.env (local container)"
  echo "     GOOGLE_CLIENT_SECRET stays optional for native #427 — set it only to"
  echo "     also exercise the webapp browser OAuth flow against local Supabase."
else
  # hosted (staging/production): VERIFY FIRST — never change production blindly.
  # GET the current authorized client IDs; only PATCH when the operator passes
  # APPLY=1. The secret is never sent.
  : "${SUPABASE_ACCESS_TOKEN:?export SUPABASE_ACCESS_TOKEN (Management API PAT) for $env}"
  : "${SUPABASE_PROJECT_REF:?export SUPABASE_PROJECT_REF for the $env project}"
  current="$(curl -s -H "Authorization: Bearer $SUPABASE_ACCESS_TOKEN" \
    "https://api.supabase.com/v1/projects/$SUPABASE_PROJECT_REF/config/auth" \
    | jq -r '.external_google_client_id // ""')"
  if [[ "$current" == *"$ios_client_id"* && "$current" == *"$web_client_id"* ]]; then
    echo "[ok] $env Supabase already authorizes the web+ios clients — NO change needed"
  elif [[ "${APPLY:-0}" != "1" ]]; then
    echo "[would-change] $env Supabase external_google_client_id='$current'" >&2
    echo "               Re-run with APPLY=1 to set it to '$web_client_id,$ios_client_id' (secret untouched)." >&2
  else
    echo "[patch] $env Supabase external_google_client_id -> web,ios"
    curl -s -X PATCH \
      -H "Authorization: Bearer $SUPABASE_ACCESS_TOKEN" -H "Content-Type: application/json" \
      "https://api.supabase.com/v1/projects/$SUPABASE_PROJECT_REF/config/auth" \
      -d "{\"external_google_enabled\":true,\"external_google_client_id\":\"$web_client_id,$ios_client_id\"}" \
      | jq '{external_google_client_id}'
  fi
fi

echo ""
echo "[done] Google Sign-In configured for $env (SHA + OAuth clients + iOS xcconfig + Supabase provider)."
