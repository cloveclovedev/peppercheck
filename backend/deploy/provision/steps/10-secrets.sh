#!/usr/bin/env bash
# Step 10: generate the 7 generatable application secrets — the 4 Postgres
# role passwords, the pgBackRest cipher passphrase, and the two composed
# connection strings that must carry the matching Postgres password — plus
# the restore-drill age keypair, and push them into Bitwarden Secrets
# Manager (BWS). The remaining 3 names in the 10-secret env-project
# allowlist (`b2_key_id`/`b2_key_secret` from step 40-b2, `ghcr_token` a
# manual PAT gated in steps 20/50) are NOT this step's job — see
# RUNBOOK.md §1.2 for the full inventory.
#
# Idempotent: every secret is checked via bws_secret_exists before writing,
# so a re-run never regenerates an already-stored password — regenerating
# postgres_app_pw/postgres_migrator_pw after the fact would desync them from
# the already-stored database_url/migrator_database_url. AGE_RECIPIENT (the
# age public key, not itself a secret) is always exported so step 50 can set
# it as a GitHub Environment variable, even on a re-run where the private
# key already exists in the restore-scoped project.
set -euo pipefail

# --- Provider wrappers — overridden by bats tests, never called directly. ---
# bws_cli/bws_secret_exists/bws_put_secret/bws_get_secret_value now live in
# lib.sh (shared across steps; see its "Shared provider wrappers" section).
age_keygen() { command age-keygen "$@"; }

# gen_password — 32-char, URL-safe, no shell-unsafe characters. Reads
# /dev/urandom directly through coreutils base64 rather than `openssl rand`
# so this one helper carries no dependency on openssl being installed.
gen_password() {
  head -c 24 /dev/urandom | base64 | tr '+/' '-_' | tr -d '=\n'
}

# ensure_password NAME PROJECT_ID
# Generates + stores NAME if absent, echoing the fresh value on stdout so a
# caller can compose a dependent secret from it. If NAME already exists this
# is a no-op and nothing is echoed: database_url/migrator_database_url are
# always (re)created in the same reconcile_secrets run as the password they
# embed, so when the password already exists its dependent is expected to
# already exist too (see ensure_composed_url's own existence check).
ensure_password() {
  local name="$1" project_id="$2" value
  if bws_secret_exists "$name" "$project_id"; then
    log_info "secret already present, skipping: ${name}"
    return 0
  fi
  value="$(gen_password)"
  # Redirect run_mutation's own stdout (its "[dry-run] ..." notice) to
  # stderr: this function's stdout is captured via command substitution by
  # its caller to obtain $value, and must carry nothing else.
  #
  # Guarded with `|| return 1` BEFORE the printf below: the orchestrator runs
  # every reconcile_* step under `set +e` (infra-foundation-setup.sh), so a
  # failed put here would otherwise still fall through to `printf` and hand
  # the caller a password that was never persisted. database_url/
  # migrator_database_url would then get composed from — and BWS would store
  # — a value whose plaintext exists nowhere durable, and a re-run would
  # regenerate the (absent) password while skipping the (present) composed
  # URL that embeds the old one, permanently desyncing the two.
  run_mutation "put ${name}" bws_put_secret "$name" "$value" "$project_id" 1>&2 || return 1
  printf '%s' "$value"
}

# ensure_cipher_mirrored ENV_PROJECT_ID RESTORE_PROJECT_ID
# pgbackrest_cipher must exist byte-identically in BOTH the env project (read
# by the compose backup/postgres services) AND the restore-scoped project:
# restore-drill.sh renders it via `bws run --project-id <restore-scoped>` with
# a restore-scoped token that, by design, cannot read the env project, yet it
# decrypts the same pgBackRest repo so the value must match exactly. This
# obtains the single canonical value — generating it in the env project when
# absent, else reading the stored one back — then ensures the restore-project
# copy matches (put only if absent; never regenerate).
ensure_cipher_mirrored() {
  local env_project_id="$1" restore_project_id="$2" value
  if bws_secret_exists pgbackrest_cipher "$env_project_id"; then
    log_info "secret already present, skipping: pgbackrest_cipher"
    value="$(bws_get_secret_value pgbackrest_cipher "$env_project_id")"
  else
    value="$(gen_password)"
    run_mutation "put pgbackrest_cipher" bws_put_secret pgbackrest_cipher "$value" "$env_project_id" || return 1
  fi
  if bws_secret_exists pgbackrest_cipher "$restore_project_id"; then
    log_info "secret already present in restore project, skipping: pgbackrest_cipher"
  else
    run_mutation "put pgbackrest_cipher (restore project)" \
      bws_put_secret pgbackrest_cipher "$value" "$restore_project_id" || return 1
  fi
}

# ensure_composed_url NAME PROJECT_ID VALUE SOURCE_PW SOURCE_NAME
# Stores the composed connection-string secret NAME=VALUE if absent. VALUE
# must already embed SOURCE_PW (the matching Postgres password generated
# earlier in this same run) so the two secrets can never desync.
ensure_composed_url() {
  local name="$1" project_id="$2" value="$3" source_pw="$4" source_name="$5"
  if bws_secret_exists "$name" "$project_id"; then
    log_info "secret already present, skipping: ${name}"
    return 0
  fi
  if [ -z "$source_pw" ]; then
    log_err "cannot compose ${name}: ${source_name} already exists in BWS but was not (re)generated this run, so its plaintext is unavailable to compose ${name} — resolve manually"
    return 1
  fi
  run_mutation "put ${name}" bws_put_secret "$name" "$value" "$project_id" || return 1
}

# ensure_age_keypair RESTORE_PROJECT_ID
# The age private key lives only in the restore-scoped project, never the
# env project (RUNBOOK.md §1.2). AGE_RECIPIENT (its public key) is exported
# unconditionally — even when the private key already existed and
# generation was skipped — by deriving it fresh via `age-keygen -y` from the
# stored (or just-generated) private key, so step 50 can read it from the
# environment within the same orchestrator run.
ensure_age_keypair() {
  local restore_project_id="$1" private_key
  if bws_secret_exists age_private_key "$restore_project_id"; then
    log_info "secret already present, skipping: age_private_key"
    private_key="$(bws_get_secret_value age_private_key "$restore_project_id")"
  else
    private_key="$(age_keygen)"
    run_mutation "put age_private_key" bws_put_secret age_private_key "$private_key" "$restore_project_id" 1>&2 || return 1
  fi
  AGE_RECIPIENT="$(printf '%s\n' "$private_key" | age_keygen -y)"
  export AGE_RECIPIENT
}

reconcile_secrets() {
  local missing=() bws_write_token="" project_id="" restore_project_id=""
  bws_write_token="$(require_cfg BWS_WRITE_TOKEN)" || missing+=(BWS_WRITE_TOKEN)
  project_id="$(require_cfg BWS_PROJECT_ID)" || missing+=(BWS_PROJECT_ID)
  restore_project_id="$(require_cfg BWS_RESTORE_PROJECT_ID)" || missing+=(BWS_RESTORE_PROJECT_ID)
  if [ "${#missing[@]}" -gt 0 ]; then
    need_manual "${missing[*]}" \
      "Create the ${ENV_NAME:-target} + restore-scoped Bitwarden Secrets Manager projects and a read-write machine-account token (web-vault action), then set: ${missing[*]}" \
      || return $?
  fi

  export BWS_ACCESS_TOKEN="$bws_write_token"

  # Every ensure_* call below is explicitly guarded with `|| return 1`: under
  # the orchestrator's `set +e`, a bare call's failure would otherwise be
  # swallowed and reconcile_secrets would fall through to the next
  # ensure_composed_url/ensure_age_keypair call (or return 0 "satisfied")
  # despite a partial write upstream.
  local postgres_app_pw postgres_migrator_pw pw_name
  postgres_app_pw="$(ensure_password postgres_app_pw "$project_id")" || return 1
  postgres_migrator_pw="$(ensure_password postgres_migrator_pw "$project_id")" || return 1
  for pw_name in postgres_superuser_pw postgres_backup_pw; do
    ensure_password "$pw_name" "$project_id" >/dev/null || return 1
  done

  ensure_cipher_mirrored "$project_id" "$restore_project_id" || return 1

  ensure_composed_url database_url "$project_id" \
    "postgres://peppercheck_app:${postgres_app_pw}@postgres:5432/peppercheck?sslmode=disable" \
    "$postgres_app_pw" postgres_app_pw || return 1

  ensure_composed_url migrator_database_url "$project_id" \
    "postgres://peppercheck_migrator:${postgres_migrator_pw}@postgres:5432/peppercheck?sslmode=disable" \
    "$postgres_migrator_pw" postgres_migrator_pw || return 1

  ensure_age_keypair "$restore_project_id" || return 1
}
