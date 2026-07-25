#!/usr/bin/env bash
# firebase-test-token.sh
#
# Exchanges a restore-scoped Firebase test account's email/password for a
# short-lived ID token, via the Firebase Auth REST API's "sign in with
# email/password" endpoint (Task 16, Phase 7-A infra/ops foundation --
# design doc §8.4: "obtain a Firebase ID token (test account / staging
# Firebase) -> authenticated smoke"). Used by restore-drill.sh to
# authenticate against the restored API's /api/v1/me -- never against
# production, and never with a real user's credentials.
#
# Endpoint per the official reference (consulted before writing this,
# per the docs-first policy):
#   https://firebase.google.com/docs/reference/rest/auth#section-sign-in-email-password
# which documents the same Google Identity Platform backend also described at
#   https://cloud.google.com/identity-platform/docs/reference/rest/v1/accounts/signInWithPassword
#
#   POST https://identitytoolkit.googleapis.com/v1/accounts:signInWithPassword?key=<API_KEY>
#   body:     {"email": "...", "password": "...", "returnSecureToken": true}
#   response: {"idToken": "...", "refreshToken": "...", "localId": "...", "expiresIn": "...", ...}
#
# Inputs (env vars), all sourced from the RESTORE-SCOPED BWS project (never
# production/staging deploy secrets -- see
# backend/deploy/provision/RUNBOOK.md §1.2):
#   firebase_test_api_key  -- the target Firebase project's Web API key
#   firebase_test_email    -- a dedicated, low-privilege test account's email
#   firebase_test_password -- that test account's password
#
# Emits the ID token, and ONLY the ID token, on stdout. Deliberately never
# logs the request body, the response body, or any of the three inputs
# above: the response also carries a long-lived refreshToken, and an error
# response can echo back part of the request -- so even failure paths below
# report a fixed message, never the response content.
set -euo pipefail

: "${firebase_test_api_key:?firebase_test_api_key is required (restore-scoped BWS secret)}"
: "${firebase_test_email:?firebase_test_email is required (restore-scoped BWS secret)}"
: "${firebase_test_password:?firebase_test_password is required (restore-scoped BWS secret)}"

request_body="$(jq -n \
  --arg email "$firebase_test_email" \
  --arg password "$firebase_test_password" \
  '{email: $email, password: $password, returnSecureToken: true}')"

if ! response="$(curl -fsS --max-time 15 \
  "https://identitytoolkit.googleapis.com/v1/accounts:signInWithPassword?key=${firebase_test_api_key}" \
  -H 'Content-Type: application/json' \
  -d "$request_body")"; then
  echo "firebase-test-token: signInWithPassword request failed" >&2
  exit 1
fi
unset request_body

id_token="$(printf '%s' "$response" | jq -r '.idToken // empty')"
unset response
if [ -z "$id_token" ]; then
  echo "firebase-test-token: response did not include an idToken" >&2
  exit 1
fi

printf '%s\n' "$id_token"
