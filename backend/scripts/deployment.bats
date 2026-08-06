#!/usr/bin/env bats
# Tests for switch-deployment.sh and write-secret.sh (Task 6, Phase 7-A
# infra/ops foundation -- design doc §5.3/§5.4/§6.5).
#
# Runs against a throwaway temp workspace (never the real /opt/peppercheck)
# with a fake `deployments/<id>/` layout, so it is safe to run anywhere,
# including via the Dockerized bats/bats image:
#   docker run --rm -v "$PWD/backend/scripts":/code -w /code bats/bats:latest deployment.bats

setup() {
  SCRIPT_DIR="$(cd "$(dirname "$BATS_TEST_FILENAME")" && pwd)"
  WORKDIR="$(mktemp -d)"
  cd "$WORKDIR" || return 1
  mkdir -p deployments/dep-a deployments/dep-b
}

teardown() {
  cd / || true
  rm -rf "$WORKDIR"
}

# --- switch-deployment.sh ----------------------------------------------

@test "switch-deployment: first deploy sets current, no previous exists" {
  run "$SCRIPT_DIR/switch-deployment.sh" dep-a
  [ "$status" -eq 0 ]
  [ -L current ]
  [ "$(readlink current)" = "deployments/dep-a" ]
  [ ! -e previous ]
}

@test "switch-deployment: second switch records the prior id in previous" {
  "$SCRIPT_DIR/switch-deployment.sh" dep-a

  run "$SCRIPT_DIR/switch-deployment.sh" dep-b
  [ "$status" -eq 0 ]
  [ "$(readlink current)" = "deployments/dep-b" ]
  [ -f previous ]
  [ "$(cat previous)" = "dep-a" ]
}

@test "switch-deployment: a third switch overwrites previous with the second id" {
  "$SCRIPT_DIR/switch-deployment.sh" dep-a
  "$SCRIPT_DIR/switch-deployment.sh" dep-b
  mkdir -p deployments/dep-c

  run "$SCRIPT_DIR/switch-deployment.sh" dep-c
  [ "$status" -eq 0 ]
  [ "$(readlink current)" = "deployments/dep-c" ]
  [ "$(cat previous)" = "dep-b" ]
}

@test "switch-deployment: rejects a target id whose deployments dir does not exist" {
  run "$SCRIPT_DIR/switch-deployment.sh" dep-missing
  [ "$status" -ne 0 ]
  [ ! -e current ]
}

@test "switch-deployment: rejects a path-traversal id" {
  run "$SCRIPT_DIR/switch-deployment.sh" "../evil"
  [ "$status" -ne 0 ]
  [ ! -e current ]
}

@test "switch-deployment: rejects a missing id argument" {
  run "$SCRIPT_DIR/switch-deployment.sh"
  [ "$status" -ne 0 ]
}

# --- write-secret.sh -----------------------------------------------------

@test "write-secret: writes an allowlisted secret with 0600 perms, deploy-owned" {
  export DEPLOY_SECRET_DIR="$WORKDIR/secrets"
  run bash -c "printf %s 'sekrit-value' | '$SCRIPT_DIR/write-secret.sh' database_url"
  [ "$status" -eq 0 ]
  [ -f "$DEPLOY_SECRET_DIR/database_url" ]
  [ "$(cat "$DEPLOY_SECRET_DIR/database_url")" = "sekrit-value" ]

  perms="$(stat -c '%a' "$DEPLOY_SECRET_DIR/database_url" 2>/dev/null || stat -f '%Lp' "$DEPLOY_SECRET_DIR/database_url")"
  [ "$perms" = "600" ]

  owner="$(stat -c '%u' "$DEPLOY_SECRET_DIR/database_url" 2>/dev/null || stat -f '%u' "$DEPLOY_SECRET_DIR/database_url")"
  [ "$owner" = "$(id -u)" ]
}

@test "write-secret: accepts every allowlisted name" {
  export DEPLOY_SECRET_DIR="$WORKDIR/secrets"
  for name in database_url postgres_superuser_pw postgres_app_pw postgres_migrator_pw \
    postgres_backup_pw migrator_database_url pgbackrest_cipher b2_key_id b2_key_secret \
    web_form_signing_key firebase_service_account ghcr_token; do
    run bash -c "printf %s 'x' | '$SCRIPT_DIR/write-secret.sh' '$name'"
    [ "$status" -eq 0 ]
    [ -f "$DEPLOY_SECRET_DIR/$name" ]
  done
}

@test "write-secret: rejects a name outside the allowlist" {
  export DEPLOY_SECRET_DIR="$WORKDIR/secrets"
  run bash -c "printf %s 'x' | '$SCRIPT_DIR/write-secret.sh' not_a_real_secret"
  [ "$status" -ne 0 ]
  [ ! -e "$DEPLOY_SECRET_DIR/not_a_real_secret" ]
}

@test "write-secret: rejects a path-traversal name and writes nothing outside the dir" {
  export DEPLOY_SECRET_DIR="$WORKDIR/secrets"
  run bash -c "printf %s 'x' | '$SCRIPT_DIR/write-secret.sh' '../evil'"
  [ "$status" -ne 0 ]
  [ ! -e "$WORKDIR/evil" ]
  [ ! -e "$DEPLOY_SECRET_DIR/../evil" ]
}

@test "write-secret: rejects a name containing a slash" {
  export DEPLOY_SECRET_DIR="$WORKDIR/secrets"
  run bash -c "printf %s 'x' | '$SCRIPT_DIR/write-secret.sh' 'a/b'"
  [ "$status" -ne 0 ]
  [ ! -e "$WORKDIR/secrets/a" ]
}

@test "write-secret: rejects an empty name" {
  export DEPLOY_SECRET_DIR="$WORKDIR/secrets"
  run bash -c "printf %s 'x' | '$SCRIPT_DIR/write-secret.sh' ''"
  [ "$status" -ne 0 ]
}
