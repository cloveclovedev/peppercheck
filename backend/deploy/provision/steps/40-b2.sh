#!/usr/bin/env bash
# Step 40: reconcile the private B2 backup bucket (governance Object Lock +
# a hidden/orphan-cleanup lifecycle rule) and mint TWO restricted B2
# application keys:
#   - a runtime read/write key, stored in the env BWS project (BWS_PROJECT_ID)
#     as `b2_key_id`/`b2_key_secret` — the 9th/10th of the env project's 10
#     secrets ship-deployment.sh renders (7 from step 10 + ghcr_token from
#     step 20 + these 2);
#   - a READ-ONLY key, stored in the restore-scoped BWS project
#     (BWS_RESTORE_PROJECT_ID) under the SAME secret names — this is exactly
#     what backend/scripts/restore-drill.sh:104-105 reads
#     (`b2_key_id`/`b2_key_secret`, documented there as "a READ-ONLY B2 key").
#
# Docs consulted (B2 CLI v4, https://b2-command-line-tool.readthedocs.io/en/master/):
#   - subcommands/account_authorize.html — `b2 account authorize <keyId> <key>`
#     (v3 name was `authorize-account`; v4 groups verbs under `account`).
#   - subcommands/bucket_create.html — `b2 bucket create [--file-lock-enabled]
#     bucketName {allPrivate|allPublic}` (v3: `create-bucket`); file lock
#     can only be enabled AT creation time, never added later.
#   - subcommands/bucket_get.html — `b2 bucket get bucketName`; non-zero exit
#     when the bucket does not exist (used here purely as an existence probe).
#   - subcommands/bucket_update.html — `--default-retention-mode
#     {compliance,governance,none}`, `--default-retention-period "<n> days"`,
#     `--lifecycle-rule '<json>'` (v3: `update-bucket`). Each `bucket update`
#     call replaces the FULL rule set, so this step only ever asserts the one
#     rule it owns (no age-based delete — see ensure_b2_bucket for why).
#   - subcommands/key_create.html — `b2 key create [--bucket B] keyName
#     capability,list,csv` (v3: `create-key`); prints the new
#     applicationKeyId on the first line and the applicationKey on the second
#     — the key material is NOT re-readable afterwards.
#   - https://www.backblaze.com/docs/cloud-storage-application-key-capabilities
#     confirms listBuckets/listFiles/readFiles/writeFiles/deleteFiles/
#     bypassGovernance are all valid capability names.
#
# Because a B2 key's secret can't be re-read after creation, idempotency for
# the two mint operations lives at the BWS layer (skip if `b2_key_id` is
# already stored in the target project), not by asking B2 whether a
# same-named key exists. A re-run therefore reuses whatever is already in
# BWS; to rotate a key, delete its `b2_key_id`/`b2_key_secret` pair from BWS
# first (this also orphans the old B2-side key — revoke it separately via
# `b2 key delete` if desired) and re-run this step.
set -euo pipefail

# --- Provider wrapper — overridden by bats tests, never called directly. ---
b2_cli() { command b2 "$@"; }

# b2_bucket_exists BUCKET — existence probe only; discards `bucket get`'s
# output (bucket info/CORS/lifecycle detail we don't need here) and relies
# purely on its exit status.
b2_bucket_exists() {
  b2_cli bucket get "$1" >/dev/null 2>&1
}

# ensure_b2_bucket BUCKET — idempotent create, then unconditionally (re-)set
# governance retention + the one lifecycle rule this setup owns.
#
# The lifecycle rule ONLY prunes hidden/orphan file versions
# (daysFromHidingToDeleting=1, no daysFromUploadingToHiding) — it never
# age-deletes a live version, so it can NEVER remove a full backup or WAL
# segment that pgBackRest's own retention still needs; pgBackRest, not this
# bucket-level rule, owns backup retention (see the project's global backup
# policy: pgBackRest owns retention, keep object-lock shorter than it).
ensure_b2_bucket() {
  local bucket="$1"
  if b2_bucket_exists "$bucket"; then
    log_info "B2 bucket already exists, skipping create: ${bucket}"
    # A bucket created WITHOUT --file-lock-enabled can never be governance-
    # locked afterward (B2 cannot enable file lock post-creation), so the
    # bucket update below would set retention flags onto an unlockable bucket
    # and report success — a false sense of backup immutability. We can't
    # cheaply read the file-lock state back here, so surface the risk and
    # keep going (don't hard-stop): the operator must confirm this bucket was
    # created with file lock, or recreate it.
    log_warn "pre-existing bucket ${bucket}: Object Lock CANNOT be enabled retroactively — confirm it was created with --file-lock-enabled, or recreate it"
  else
    run_mutation "create B2 bucket ${bucket} (allPrivate, file-lock-enabled)" \
      b2_cli bucket create "$bucket" allPrivate --file-lock-enabled
  fi
  run_mutation "set governance retention + lifecycle rule on ${bucket}" \
    b2_cli bucket update "$bucket" \
      --default-retention-mode governance \
      --default-retention-period "7 days" \
      --lifecycle-rule '{"daysFromHidingToDeleting":1,"fileNamePrefix":""}'
}

# ensure_b2_key KEY_NAME CAPABILITIES BUCKET PROJECT_ID
# Idempotent at the BWS layer only (see file header). Never passes
# `bypassGovernance` — callers pass an explicit, minimal capability list.
ensure_b2_key() {
  local key_name="$1" capabilities="$2" bucket="$3" project_id="$4"
  if bws_secret_exists b2_key_id "$project_id"; then
    log_info "b2_key_id already present in BWS project ${project_id}, skipping key create: ${key_name}"
    return 0
  fi

  local output=""
  output="$(run_mutation "create B2 key ${key_name} (${capabilities})" \
    b2_cli key create --bucket "$bucket" "$key_name" "$capabilities")"
  is_dry_run && return 0

  local key_id="" key_secret=""
  { read -r key_id; read -r key_secret; } <<<"$output"
  if [ -z "$key_id" ] || [ -z "$key_secret" ]; then
    log_err "B2 key create for ${key_name} returned unexpected output (not logging it)"
    return 1
  fi

  bws_put_secret b2_key_id "$key_id" "$project_id"
  bws_put_secret b2_key_secret "$key_secret" "$project_id"
  log_ok "minted B2 key ${key_name}; stored b2_key_id/b2_key_secret in BWS project ${project_id} (values not logged)"
}

reconcile_b2() {
  local missing=() app_key_id="" app_key="" bucket="" write_token="" project_id="" restore_project_id=""
  app_key_id="$(require_cfg B2_APPLICATION_KEY_ID)" || missing+=(B2_APPLICATION_KEY_ID)
  app_key="$(require_cfg B2_APPLICATION_KEY)" || missing+=(B2_APPLICATION_KEY)
  bucket="$(require_cfg B2_BUCKET)" || missing+=(B2_BUCKET)
  write_token="$(require_cfg BWS_WRITE_TOKEN)" || missing+=(BWS_WRITE_TOKEN)
  project_id="$(require_cfg BWS_PROJECT_ID)" || missing+=(BWS_PROJECT_ID)
  restore_project_id="$(require_cfg BWS_RESTORE_PROJECT_ID)" || missing+=(BWS_RESTORE_PROJECT_ID)
  if [ "${#missing[@]}" -gt 0 ]; then
    need_manual "${missing[*]}" \
      "Create a Backblaze B2 account application key with bucket-create/key-create capability in the B2 dashboard." \
      || return $?
  fi

  export BWS_ACCESS_TOKEN="$write_token"

  # Authorize directly (not via run_mutation): this is a local CLI login, not
  # a mutation against B2/BWS state, so it must happen even under --dry-run
  # (a dry run still needs to query `bucket get` to report what it WOULD do).
  # Never echo the key material.
  b2_cli account authorize "$app_key_id" "$app_key" >/dev/null

  ensure_b2_bucket "$bucket"

  # Fail closed rather than fall back: env is part of a REAL resource name
  # (pc-<env>-backup/-restore), so an empty ENV_NAME would mint a mis-named
  # B2 key. The orchestrator always exports ENV_NAME, so this only catches a
  # direct-invocation misuse.
  local env="${ENV_NAME:-}"
  if [ -z "$env" ]; then
    log_err "ENV_NAME is empty — refusing to mint B2 keys with an unnamed environment"
    return 1
  fi
  # Runtime key: read/write, no bypassGovernance — the running app/backup
  # container should never be able to delete a governance-locked version.
  ensure_b2_key "pc-${env}-backup" "listBuckets,listFiles,readFiles,writeFiles,deleteFiles" \
    "$bucket" "$project_id"
  # Restore key: read-only — restore-drill.sh only ever needs to fetch
  # existing backups/WAL, never write or delete.
  ensure_b2_key "pc-${env}-restore" "listBuckets,listFiles,readFiles" \
    "$bucket" "$restore_project_id"
}
