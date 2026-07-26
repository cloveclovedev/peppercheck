#!/usr/bin/env bash
# Step 20: BWS project/token manual gates (same gate as step 10, repeated
# here for consistency since --only/--from may skip step 10 entirely),
# install the runtime read-only BWS token as the GitHub Environment secret
# `BWS_TOKEN` (the exact name deploy-vps.yml reads via `secrets.BWS_TOKEN`
# -- do not rename), and populate the restore-scoped project's
# operator-provided Firebase test credentials that
# backend/scripts/restore-drill.sh reads (restore-drill.sh:108-110). B2 read
# credentials for the restore project are handled by step 40 (B2), not here.
set -euo pipefail

# ensure_restore_secret NAME VALUE PROJECT_ID
# Idempotent: put only if absent, so a re-run never clobbers a value an
# operator may have rotated directly in the vault after the fact.
ensure_restore_secret() {
  local name="$1" value="$2" project_id="$3"
  if bws_secret_exists "$name" "$project_id"; then
    log_info "secret already present, skipping: ${name}"
    return 0
  fi
  run_mutation "put ${name}" bws_put_secret "$name" "$value" "$project_id"
}

reconcile_bws() {
  local missing=() bws_write_token="" project_id="" restore_project_id=""
  bws_write_token="$(require_cfg BWS_WRITE_TOKEN)" || missing+=(BWS_WRITE_TOKEN)
  project_id="$(require_cfg BWS_PROJECT_ID)" || missing+=(BWS_PROJECT_ID)
  restore_project_id="$(require_cfg BWS_RESTORE_PROJECT_ID)" || missing+=(BWS_RESTORE_PROJECT_ID)
  if [ "${#missing[@]}" -gt 0 ]; then
    need_manual "${missing[*]}" \
      "Create the ${ENV_NAME:-target} + restore-scoped BWS projects and a read-write machine-account token in the Bitwarden web vault." \
      || return $?
  fi

  export BWS_ACCESS_TOKEN="$bws_write_token"
  bws_project_exists "$project_id" || {
    log_err "BWS project ${project_id} is not reachable with the configured write token"
    return 1
  }

  local bws_runtime_token=""
  if ! bws_runtime_token="$(require_cfg BWS_RUNTIME_TOKEN)"; then
    need_manual BWS_RUNTIME_TOKEN \
      "Create a READ-ONLY BWS machine-account token scoped to the ${ENV_NAME:-target} project"
    return $?
  fi

  run_mutation "set GH secret BWS_TOKEN" gh_secret_set BWS_TOKEN "$bws_runtime_token"

  local fb_missing=() fb_key="" fb_email="" fb_password=""
  fb_key="$(require_cfg FIREBASE_TEST_API_KEY)" || fb_missing+=(FIREBASE_TEST_API_KEY)
  fb_email="$(require_cfg FIREBASE_TEST_EMAIL)" || fb_missing+=(FIREBASE_TEST_EMAIL)
  fb_password="$(require_cfg FIREBASE_TEST_PASSWORD)" || fb_missing+=(FIREBASE_TEST_PASSWORD)
  if [ "${#fb_missing[@]}" -gt 0 ]; then
    need_manual "${fb_missing[*]}" \
      "Create a dedicated low-privilege Firebase test account for the restore drill." \
      || return $?
  fi

  ensure_restore_secret firebase_test_api_key "$fb_key" "$restore_project_id"
  ensure_restore_secret firebase_test_email "$fb_email" "$restore_project_id"
  ensure_restore_secret firebase_test_password "$fb_password" "$restore_project_id"
}
