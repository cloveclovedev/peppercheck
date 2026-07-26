setup() {
  ROOT="$(cd "$(dirname "$BATS_TEST_FILENAME")" && pwd)"
  # shellcheck disable=SC1091
  source "$ROOT/lib.sh"
}

@test "need_manual returns the sentinel and prints the key" {
  run need_manual GHCR_TOKEN "Create a read-only PAT"
  [ "$status" -eq 75 ]
  [[ "$output" == *"GHCR_TOKEN"* ]]
  [[ "$output" == *"Create a read-only PAT"* ]]
}

@test "require_tools exits 1 and names a missing tool" {
  run require_tools definitely_not_a_real_tool_xyz
  [ "$status" -eq 1 ]
  [[ "$output" == *"definitely_not_a_real_tool_xyz"* ]]
}

@test "cfg reads a value from the environment" {
  export CFG_TEST_KEY=hello
  run cfg CFG_TEST_KEY
  [ "$status" -eq 0 ]
  [ "$output" = "hello" ]
}

@test "run_mutation echoes in dry-run and does not execute" {
  DRY_RUN=1
  run run_mutation "would create bucket" touch "$BATS_TEST_TMPDIR/sentinel"
  [ "$status" -eq 0 ]
  [[ "$output" == *"[dry-run] would create bucket"* ]]
  [ ! -e "$BATS_TEST_TMPDIR/sentinel" ]
}

@test "run_mutation executes when not dry-run" {
  DRY_RUN=0
  run run_mutation "create file" touch "$BATS_TEST_TMPDIR/sentinel"
  [ "$status" -eq 0 ]
  [ -e "$BATS_TEST_TMPDIR/sentinel" ]
}

@test "_json_escape emits tab/newline/CR as escape sequences, not raw control chars" {
  run _json_escape "$(printf 'a\tb\nc\rd')"
  [ "$status" -eq 0 ]
  [[ "$output" == *'\t'* ]]
  [[ "$output" == *'\n'* ]]
  [[ "$output" == *'\r'* ]]
  # No raw control chars survived: printf %q renders any literal control char
  # as a $'…' sequence, so its %q rendering must contain no $' at all. This
  # assertion FAILS (glob !=) if a raw control char leaked through.
  q="$(printf '%q' "$output")"
  [[ "$q" != *"\$'"* ]]
}

@test "require_known_step rejects an unknown step and names it and the valid list" {
  run require_known_step only bogus_step secrets bws tailscale
  [ "$status" -eq 2 ]
  [[ "$output" == *"bogus_step"* ]]
  [[ "$output" == *"secrets"* ]]
}

@test "require_known_step accepts a known step" {
  run require_known_step from bws secrets bws tailscale
  [ "$status" -eq 0 ]
}

# --- shared wrappers: order-independent GitHub Environment creation --------
# ensure_gh_environment lives in lib.sh so it can fire from gh_secret_set/
# gh_var_set regardless of which step runs first under --only/--from (env
# secrets are set by steps 20/60, vars by step 50). Only gh_api is stubbed
# below; `command gh secret/variable set` itself is NOT stubbed (there is no
# way to intercept a `command`-invoked external binary from a bash
# function), so it runs for real and fails in this jq/gh-less bats image --
# harmless here since the assertion only needs ensure_gh_environment's PUT to
# have already landed in the log before that failure.
@test "gh_secret_set ensures the GitHub Environment before setting the secret" {
  export ENV_NAME=staging
  calls_log="$BATS_TEST_TMPDIR/gh_api.log"
  : > "$calls_log"
  gh_api() { printf '%s\n' "$*" >> "$calls_log"; }
  run gh_secret_set SOME_SECRET some-value
  grep -q -- "--method PUT repos/{owner}/{repo}/environments/staging" "$calls_log"
}

@test "gh_var_set ensures the GitHub Environment before setting the variable" {
  export ENV_NAME=staging
  calls_log="$BATS_TEST_TMPDIR/gh_api.log"
  : > "$calls_log"
  gh_api() { printf '%s\n' "$*" >> "$calls_log"; }
  run gh_var_set SOME_VAR some-value
  grep -q -- "--method PUT repos/{owner}/{repo}/environments/staging" "$calls_log"
}

@test "ensure_gh_environment sends a plain (no-body) PUT" {
  export ENV_NAME=production
  calls_log="$BATS_TEST_TMPDIR/gh_api.log"
  : > "$calls_log"
  gh_api() { printf '%s\n' "$*" >> "$calls_log"; }
  run ensure_gh_environment
  [ "$status" -eq 0 ]
  grep -q -- "--method PUT repos/{owner}/{repo}/environments/production" "$calls_log"
}

@test "gen_password yields a 32+ char token with no shell-unsafe chars" {
  source "$ROOT/steps/10-secrets.sh"
  run gen_password
  [ "$status" -eq 0 ]
  [ "${#output}" -ge 32 ]
  [[ ! "$output" =~ [\'\"\`\$\\] ]]
}

@test "reconcile_secrets is a no-op when all secrets already exist in BWS" {
  source "$ROOT/steps/10-secrets.sh"
  bws_cli() { echo '[{"key":"database_url"},{"key":"postgres_app_pw"}]'; }  # list returns everything
  bws_secret_exists() { return 0; }  # stub: all present
  # Present even though generation is skipped: the age-key re-run-safety
  # path always derives AGE_RECIPIENT from the (here: stubbed) stored
  # private key, regardless of whether anything else was regenerated.
  bws_get_secret_value() { echo "AGE-SECRET-KEY-STUB"; }
  age_keygen() { echo "age1stubpublickey"; }
  # `run` executes reconcile_secrets in a subshell, so a plain variable set
  # inside this stub would not survive back here — log any put to a file and
  # assert the file stays empty (real no-op verification).
  puts_log="$BATS_TEST_TMPDIR/puts.log"
  : > "$puts_log"
  bws_put_secret() { printf '%s\n' "$1" >> "$puts_log"; }
  export BWS_WRITE_TOKEN=x BWS_PROJECT_ID=p BWS_RESTORE_PROJECT_ID=r
  run reconcile_secrets
  [ "$status" -eq 0 ]
  [ ! -s "$puts_log" ]  # nothing regenerated
}

@test "reconcile_secrets stops with NEEDS_MANUAL when the BWS write token is absent" {
  source "$ROOT/steps/10-secrets.sh"
  unset BWS_WRITE_TOKEN || true
  run reconcile_secrets
  [ "$status" -eq 75 ]
  [[ "$output" == *"BWS_WRITE_TOKEN"* ]]
}

@test "reconcile_secrets stops with NEEDS_MANUAL when the BWS project IDs are absent" {
  source "$ROOT/steps/10-secrets.sh"
  export BWS_WRITE_TOKEN=x
  unset BWS_PROJECT_ID BWS_RESTORE_PROJECT_ID || true
  run reconcile_secrets
  [ "$status" -eq 75 ]
  [[ "$output" == *"BWS_PROJECT_ID"* ]]
  [[ "$output" == *"BWS_RESTORE_PROJECT_ID"* ]]
}

@test "reconcile_secrets composes database_url with the exact freshly-generated postgres_app_pw" {
  source "$ROOT/steps/10-secrets.sh"
  bws_secret_exists() { return 1; }  # nothing exists yet
  puts_log="$BATS_TEST_TMPDIR/puts.log"
  : > "$puts_log"
  bws_put_secret() { printf '%s=%s\n' "$1" "$2" >> "$puts_log"; }
  age_keygen() {
    if [ "${1:-}" = "-y" ]; then echo "age1stubpublickey"; else echo "AGE-SECRET-KEY-STUB"; fi
  }
  export BWS_WRITE_TOKEN=x BWS_PROJECT_ID=p BWS_RESTORE_PROJECT_ID=r
  run reconcile_secrets
  [ "$status" -eq 0 ]
  app_pw="$(grep '^postgres_app_pw=' "$puts_log" | cut -d= -f2)"
  [ -n "$app_pw" ]
  grep -q "^database_url=postgres://peppercheck_app:${app_pw}@postgres:5432/peppercheck?sslmode=disable$" "$puts_log"
}

@test "reconcile_secrets writes pgbackrest_cipher into both the env and restore projects with the same value" {
  source "$ROOT/steps/10-secrets.sh"
  bws_secret_exists() { return 1; }  # nothing exists yet
  puts_log="$BATS_TEST_TMPDIR/puts.log"
  : > "$puts_log"
  # Log which project id each put targeted alongside the name and value.
  bws_put_secret() { printf '%s\t%s\t%s\n' "$1" "$2" "$3" >> "$puts_log"; }
  age_keygen() {
    if [ "${1:-}" = "-y" ]; then echo "age1stubpublickey"; else echo "AGE-SECRET-KEY-STUB"; fi
  }
  export BWS_WRITE_TOKEN=x BWS_PROJECT_ID=envproj BWS_RESTORE_PROJECT_ID=restoreproj
  run reconcile_secrets
  [ "$status" -eq 0 ]
  # Fields are name<TAB>value<TAB>project; select cipher rows by name (f1) and
  # project (f3), read the value (f2).
  env_val="$(awk -F'\t' '$1=="pgbackrest_cipher" && $3=="envproj" {print $2}' "$puts_log")"
  restore_val="$(awk -F'\t' '$1=="pgbackrest_cipher" && $3=="restoreproj" {print $2}' "$puts_log")"
  [ -n "$env_val" ]
  [ -n "$restore_val" ]
  [ "$env_val" = "$restore_val" ]
}

# --- step 20: reconcile_bws -------------------------------------------------
# Common env for the "past the first gate" tests below: a write token +
# project ids, the project-reachability wrapper stubbed ok, and GHCR_TOKEN
# present (its gate sits between reachability and the runtime-token gate, so
# every test that must reach a later gate has to clear it first).
_bws_setup_reachable_project() {
  export BWS_WRITE_TOKEN=wt BWS_PROJECT_ID=p BWS_RESTORE_PROJECT_ID=r GHCR_TOKEN=ghcr-pat
  bws_project_exists() { return 0; }
  # Benign defaults so a test that only cares about a later gate still clears
  # the ghcr_token put (real bws_secret_exists/bws_put_secret call bws+jq,
  # absent from the bats image). Tests that assert on puts override these.
  bws_secret_exists() { return 1; }
  bws_put_secret() { :; }
  gh_secret_set() { :; }
}

@test "reconcile_bws stops with NEEDS_MANUAL when BWS_WRITE_TOKEN is absent" {
  source "$ROOT/steps/20-bws.sh"
  unset BWS_WRITE_TOKEN BWS_PROJECT_ID BWS_RESTORE_PROJECT_ID || true
  run reconcile_bws
  [ "$status" -eq 75 ]
  [[ "$output" == *"BWS_WRITE_TOKEN"* ]]
}

@test "reconcile_bws returns 1 when the configured BWS project is not reachable" {
  source "$ROOT/steps/20-bws.sh"
  export BWS_WRITE_TOKEN=wt BWS_PROJECT_ID=p BWS_RESTORE_PROJECT_ID=r
  bws_project_exists() { return 1; }
  run reconcile_bws
  [ "$status" -eq 1 ]
}

@test "reconcile_bws stops with NEEDS_MANUAL naming GHCR_TOKEN when it is absent" {
  source "$ROOT/steps/20-bws.sh"
  _bws_setup_reachable_project
  unset GHCR_TOKEN || true
  run reconcile_bws
  [ "$status" -eq 75 ]
  [[ "$output" == *"GHCR_TOKEN"* ]]
}

@test "reconcile_bws puts ghcr_token into the env project, not the restore project" {
  source "$ROOT/steps/20-bws.sh"
  _bws_setup_reachable_project
  export GHCR_TOKEN=ghcr-pat-xyz
  export BWS_RUNTIME_TOKEN=ro-token-123
  export FIREBASE_TEST_API_KEY=k FIREBASE_TEST_EMAIL=e@example.com FIREBASE_TEST_PASSWORD=pw
  bws_secret_exists() { return 1; }  # nothing exists yet
  puts_log="$BATS_TEST_TMPDIR/puts.log"
  : > "$puts_log"
  bws_put_secret() { printf '%s\t%s\t%s\n' "$1" "$2" "$3" >> "$puts_log"; }
  run reconcile_bws
  [ "$status" -eq 0 ]
  # ghcr_token landed in the env project (p) with the exact value, never in
  # the restore project (r).
  grep -q "^ghcr_token	ghcr-pat-xyz	p$" "$puts_log"
  ! grep -q "^ghcr_token	.*	r$" "$puts_log"
}

@test "reconcile_bws stops with NEEDS_MANUAL naming BWS_RUNTIME_TOKEN when it is absent" {
  source "$ROOT/steps/20-bws.sh"
  _bws_setup_reachable_project
  unset BWS_RUNTIME_TOKEN || true
  run reconcile_bws
  [ "$status" -eq 75 ]
  [[ "$output" == *"BWS_RUNTIME_TOKEN"* ]]
}

@test "reconcile_bws pushes the runtime token to GH secret BWS_TOKEN exactly once" {
  source "$ROOT/steps/20-bws.sh"
  _bws_setup_reachable_project
  export BWS_RUNTIME_TOKEN=ro-token-123
  export FIREBASE_TEST_API_KEY=k FIREBASE_TEST_EMAIL=e@example.com FIREBASE_TEST_PASSWORD=pw
  bws_secret_exists() { return 1; }  # nothing exists yet in the restore project
  bws_put_secret() { :; }
  # `run` captures this in a subshell, so a plain variable counter incremented
  # inside gh_secret_set would not survive back to this test — log calls to a
  # file instead (same pattern the step-10 puts_log tests use).
  calls_log="$BATS_TEST_TMPDIR/gh_secret_set.log"
  : > "$calls_log"
  gh_secret_set() { printf '%s\t%s\n' "$1" "$2" >> "$calls_log"; }
  run reconcile_bws
  [ "$status" -eq 0 ]
  [ "$(wc -l < "$calls_log")" -eq 1 ]
  grep -q "^BWS_TOKEN	ro-token-123$" "$calls_log"
}

@test "reconcile_bws stops with NEEDS_MANUAL when a Firebase test credential is absent" {
  source "$ROOT/steps/20-bws.sh"
  _bws_setup_reachable_project
  export BWS_RUNTIME_TOKEN=ro-token-123
  gh_secret_set() { :; }
  export FIREBASE_TEST_API_KEY=k FIREBASE_TEST_EMAIL=e@example.com
  unset FIREBASE_TEST_PASSWORD || true
  run reconcile_bws
  [ "$status" -eq 75 ]
  [[ "$output" == *"FIREBASE_TEST_PASSWORD"* ]]
}

@test "reconcile_bws puts the 3 Firebase test credentials into the restore project under the exact secret names" {
  source "$ROOT/steps/20-bws.sh"
  _bws_setup_reachable_project
  export BWS_RUNTIME_TOKEN=ro-token-123
  gh_secret_set() { :; }
  export FIREBASE_TEST_API_KEY=test-api-key FIREBASE_TEST_EMAIL=drill@example.com FIREBASE_TEST_PASSWORD=hunter2
  bws_secret_exists() { return 1; }  # nothing exists yet
  puts_log="$BATS_TEST_TMPDIR/puts.log"
  : > "$puts_log"
  bws_put_secret() { printf '%s\t%s\t%s\n' "$1" "$2" "$3" >> "$puts_log"; }
  run reconcile_bws
  [ "$status" -eq 0 ]
  grep -q "^firebase_test_api_key	test-api-key	r$" "$puts_log"
  grep -q "^firebase_test_email	drill@example.com	r$" "$puts_log"
  grep -q "^firebase_test_password	hunter2	r$" "$puts_log"
}

@test "reconcile_bws skips a Firebase test credential that already exists in the restore project" {
  source "$ROOT/steps/20-bws.sh"
  _bws_setup_reachable_project
  export BWS_RUNTIME_TOKEN=ro-token-123
  gh_secret_set() { :; }
  export FIREBASE_TEST_API_KEY=k FIREBASE_TEST_EMAIL=e@example.com FIREBASE_TEST_PASSWORD=pw
  bws_secret_exists() { return 0; }  # already present
  # See the gh_secret_set test above for why this is a file, not a variable.
  puts_log="$BATS_TEST_TMPDIR/puts.log"
  : > "$puts_log"
  bws_put_secret() { echo "$1" >> "$puts_log"; }
  run reconcile_bws
  [ "$status" -eq 0 ]
  [ ! -s "$puts_log" ]
}

# --- step 30: reconcile_tailscale -------------------------------------------
# acl_satisfied itself calls real jq (verified separately against fixtures
# with a local jq — the bats/bats:latest image has no jq binary, matching
# steps 10/20's convention of never invoking real jq inside a bats test; see
# bws_secret_exists/bws_project_exists, always stubbed rather than exercised
# for real). So reconcile_tailscale tests below stub acl_satisfied directly,
# the same way reconcile_bws tests stub bws_project_exists rather than
# feeding bws_cli real listing output through real jq.

@test "reconcile_tailscale stops with NEEDS_MANUAL when TS_API_KEY is absent" {
  source "$ROOT/steps/30-tailscale.sh"
  unset TS_API_KEY TS_CLIENT_ID TS_AUDIENCE TS_TAG || true
  run reconcile_tailscale
  [ "$status" -eq 75 ]
  [[ "$output" == *"TS_API_KEY"* ]]
}

@test "reconcile_tailscale stops with NEEDS_MANUAL naming TS_CLIENT_ID and TS_AUDIENCE when absent" {
  source "$ROOT/steps/30-tailscale.sh"
  export TS_API_KEY=ts-api-key-x
  unset TS_CLIENT_ID TS_AUDIENCE || true
  run reconcile_tailscale
  [ "$status" -eq 75 ]
  [[ "$output" == *"TS_CLIENT_ID"* ]]
  [[ "$output" == *"TS_AUDIENCE"* ]]
}

@test "reconcile_tailscale proceeds past a satisfied ACL and mints an auth key" {
  source "$ROOT/steps/30-tailscale.sh"
  export TS_API_KEY=ts-api-key-x TS_CLIENT_ID=c TS_AUDIENCE=a TS_TAG=tag:pc-staging
  calls_log="$BATS_TEST_TMPDIR/ts_api.log"
  : > "$calls_log"
  ts_api() {
    printf '%s %s\n' "$1" "$2" >> "$calls_log"
    case "$1 $2" in
      "GET /tailnet/-/acl") echo '{"tagOwners":{"tag:ci-deploy":["autogroup:admin"]}}' ;;
      "POST /tailnet/-/keys") echo '{"key":"tskey-xyz"}' ;;
    esac
  }
  acl_satisfied() { return 0; }  # stub: ACL already has the required tags+grant
  run reconcile_tailscale
  [ "$status" -eq 0 ]
  grep -q "^GET /tailnet/-/acl$" "$calls_log"
  grep -q "^POST /tailnet/-/keys$" "$calls_log"
}

@test "reconcile_tailscale stops with NEEDS_MANUAL naming TAILSCALE_ACL when the grant is missing, without minting a key" {
  source "$ROOT/steps/30-tailscale.sh"
  export TS_API_KEY=ts-api-key-x TS_CLIENT_ID=c TS_AUDIENCE=a TS_TAG=tag:pc-staging
  calls_log="$BATS_TEST_TMPDIR/ts_api.log"
  : > "$calls_log"
  ts_api() {
    printf '%s %s\n' "$1" "$2" >> "$calls_log"
    case "$1 $2" in
      "GET /tailnet/-/acl") echo '{"tagOwners":{}}' ;;
      "POST /tailnet/-/keys") echo '{"key":"tskey-xyz"}' ;;
    esac
  }
  acl_satisfied() { return 1; }  # stub: ACL is missing required tags/grant
  run reconcile_tailscale
  [ "$status" -eq 75 ]
  [[ "$output" == *"TAILSCALE_ACL"* ]]
  ! grep -q "^POST /tailnet/-/keys$" "$calls_log"
}

@test "mint_tailscale_auth_key exports TS_AUTH_KEY (not the request body) after a successful mint" {
  source "$ROOT/steps/30-tailscale.sh"
  DRY_RUN=0
  ts_api() { echo '{"key":"tskey-abc123"}'; }
  mint_tailscale_auth_key tag:pc-staging
  [ -n "${TS_AUTH_KEY:-}" ]
  [ "$TS_AUTH_KEY" = "tskey-abc123" ]
}

@test "mint_tailscale_auth_key fails closed when the API response has no key" {
  source "$ROOT/steps/30-tailscale.sh"
  DRY_RUN=0
  ts_api() { echo '{}'; }
  run mint_tailscale_auth_key tag:pc-staging
  [ "$status" -ne 0 ]
}

@test "mint_tailscale_auth_key does not call ts_api in dry-run" {
  source "$ROOT/steps/30-tailscale.sh"
  DRY_RUN=1
  calls_log="$BATS_TEST_TMPDIR/ts_api.log"
  : > "$calls_log"
  ts_api() { echo "called" >> "$calls_log"; echo '{"key":"tskey-abc123"}'; }
  run mint_tailscale_auth_key tag:pc-staging
  [ "$status" -eq 0 ]
  [ ! -s "$calls_log" ]
}

# --- step 40: reconcile_b2 ---------------------------------------------------
# Common env for the "past the gate" tests below: all 6 gate vars present,
# `b2 account authorize` stubbed ok, and both BWS projects reporting the key
# as already present (real key-create/put-secret path opted into per-test).
_b2_setup_gated() {
  export B2_APPLICATION_KEY_ID=master-key-id B2_APPLICATION_KEY=master-key \
    B2_BUCKET=pc-staging-backups BWS_WRITE_TOKEN=wt BWS_PROJECT_ID=envproj \
    BWS_RESTORE_PROJECT_ID=restoreproj ENV_NAME=staging
  b2_cli() { :; }
  bws_secret_exists() { return 0; }  # default: nothing left to create
  bws_put_secret() { :; }
}

@test "reconcile_b2 stops with NEEDS_MANUAL when a gate var is absent" {
  source "$ROOT/steps/40-b2.sh"
  unset B2_APPLICATION_KEY_ID B2_APPLICATION_KEY B2_BUCKET BWS_WRITE_TOKEN \
    BWS_PROJECT_ID BWS_RESTORE_PROJECT_ID || true
  run reconcile_b2
  [ "$status" -eq 75 ]
  [[ "$output" == *"B2_APPLICATION_KEY_ID"* ]]
  [[ "$output" == *"B2_BUCKET"* ]]
  [[ "$output" == *"BWS_RESTORE_PROJECT_ID"* ]]
}

# The bucket-update assertions below lock the backup-immutability config: the
# `bucket update` call MUST keep governance retention and MUST NOT gain an
# age-based `daysFromUploadingToHiding` (which would delete LIVE backups
# pgBackRest still needs). A regression that weakens either would otherwise
# pass a bare `grep "^bucket update"`.
_assert_bucket_update_safety() {
  local log="$1"
  grep -q "^bucket update ${B2_BUCKET} " "$log"
  grep -q -- "--default-retention-mode governance" "$log"
  grep -q -- "--default-retention-period 7 days" "$log"
  grep -q -- 'daysFromHidingToDeleting' "$log"
  # Never an age-based delete of live versions.
  ! grep -q -- 'daysFromUploadingToHiding' "$log"
}

@test "reconcile_b2 does not create the bucket when it already exists" {
  source "$ROOT/steps/40-b2.sh"
  _b2_setup_gated
  calls_log="$BATS_TEST_TMPDIR/b2_cli.log"
  : > "$calls_log"
  b2_cli() {
    printf '%s\n' "$*" >> "$calls_log"
    case "$1 $2" in
      "bucket get") return 0 ;;      # bucket already exists
    esac
    return 0
  }
  run reconcile_b2
  [ "$status" -eq 0 ]
  ! grep -q "^bucket create" "$calls_log"
  _assert_bucket_update_safety "$calls_log"
}

@test "reconcile_b2 creates the bucket with --file-lock-enabled when absent" {
  source "$ROOT/steps/40-b2.sh"
  _b2_setup_gated
  calls_log="$BATS_TEST_TMPDIR/b2_cli.log"
  : > "$calls_log"
  b2_cli() {
    printf '%s\n' "$*" >> "$calls_log"
    case "$1 $2" in
      "bucket get") return 1 ;;      # bucket absent
    esac
    return 0
  }
  run reconcile_b2
  [ "$status" -eq 0 ]
  grep -q "^bucket create ${B2_BUCKET} allPrivate --file-lock-enabled$" "$calls_log"
  _assert_bucket_update_safety "$calls_log"
}

@test "reconcile_b2 mints both keys with distinct, non-bypassGovernance capability lists, into the correct BWS projects" {
  source "$ROOT/steps/40-b2.sh"
  _b2_setup_gated
  bws_secret_exists() { return 1; }  # neither project has a key yet
  key_calls_log="$BATS_TEST_TMPDIR/key_create.log"
  : > "$key_calls_log"
  puts_log="$BATS_TEST_TMPDIR/puts.log"
  : > "$puts_log"
  b2_cli() {
    case "$1 $2" in
      "bucket get") return 0 ;;
      "key create")
        shift 2
        printf '%s\n' "$*" >> "$key_calls_log"
        # args: --bucket BUCKET keyName capabilities
        case "$3" in
          *-backup) echo "backupKeyId123"; echo "backupKeySecretXYZ" ;;
          *-restore) echo "restoreKeyId456"; echo "restoreKeySecretABC" ;;
        esac
        ;;
    esac
    return 0
  }
  bws_put_secret() { printf '%s\t%s\t%s\n' "$1" "$2" "$3" >> "$puts_log"; }
  run reconcile_b2
  [ "$status" -eq 0 ]

  # Capability lists never include bypassGovernance.
  ! grep -q "bypassGovernance" "$key_calls_log"
  # Runtime key: read/write, into the env project.
  grep -q "pc-staging-backup listBuckets,listFiles,readFiles,writeFiles,deleteFiles$" "$key_calls_log"
  # Restore key: read-only, into the restore project.
  grep -q "pc-staging-restore listBuckets,listFiles,readFiles$" "$key_calls_log"

  grep -q "^b2_key_id	backupKeyId123	envproj$" "$puts_log"
  grep -q "^b2_key_secret	backupKeySecretXYZ	envproj$" "$puts_log"
  grep -q "^b2_key_id	restoreKeyId456	restoreproj$" "$puts_log"
  grep -q "^b2_key_secret	restoreKeySecretABC	restoreproj$" "$puts_log"
}

@test "reconcile_b2 warns that Object Lock cannot be enabled retroactively on a pre-existing bucket" {
  source "$ROOT/steps/40-b2.sh"
  _b2_setup_gated
  b2_cli() { case "$1 $2" in "bucket get") return 0 ;; esac; return 0; }  # exists
  run reconcile_b2
  [ "$status" -eq 0 ]
  [[ "$output" == *"CANNOT be enabled retroactively"* ]]
}

@test "reconcile_b2 does not warn about retroactive Object Lock when it creates the bucket" {
  source "$ROOT/steps/40-b2.sh"
  _b2_setup_gated
  b2_cli() { case "$1 $2" in "bucket get") return 1 ;; esac; return 0; }  # absent
  run reconcile_b2
  [ "$status" -eq 0 ]
  [[ "$output" != *"CANNOT be enabled retroactively"* ]]
}

@test "reconcile_b2 hard-fails (does not mint a pc-unknown key) when ENV_NAME is empty" {
  source "$ROOT/steps/40-b2.sh"
  _b2_setup_gated
  unset ENV_NAME || true
  key_calls_log="$BATS_TEST_TMPDIR/key_create.log"
  : > "$key_calls_log"
  b2_cli() {
    case "$1 $2" in
      "bucket get") return 0 ;;
      "key create") shift 2; printf '%s\n' "$*" >> "$key_calls_log" ;;
    esac
    return 0
  }
  bws_secret_exists() { return 1; }
  run reconcile_b2
  [ "$status" -eq 1 ]
  [ ! -s "$key_calls_log" ]  # never reached key creation
}

@test "reconcile_b2 is a no-op for key creation when both BWS projects already have b2_key_id" {
  source "$ROOT/steps/40-b2.sh"
  _b2_setup_gated
  bws_secret_exists() { return 0; }  # both projects already have a key
  calls_log="$BATS_TEST_TMPDIR/b2_cli.log"
  : > "$calls_log"
  b2_cli() {
    printf '%s\n' "$*" >> "$calls_log"
    case "$1 $2" in
      "bucket get") return 0 ;;
    esac
    return 0
  }
  run reconcile_b2
  [ "$status" -eq 0 ]
  ! grep -q "^key create" "$calls_log"
}

# --- step 50: reconcile_github_env -------------------------------------------
# gh_api/gh_env_var_exists/gh_var_set are stubbed directly in every test
# below (no real gh CLI or jq call inside a bats test), the same convention
# steps 10/20/40 use for bws_secret_exists/bws_project_exists.
_github_env_setup_satisfied() {
  export ENV_NAME=staging API_PORT=8765 FIREBASE_PROJECT_ID=fb-proj \
    PGBACKREST_REPO1_S3_ENDPOINT=https://s3.us-west-002.backblazeb2.com \
    B2_BUCKET=pc-staging-backups B2_REGION=us-west-002 \
    TS_CLIENT_ID=ts-client-id TS_AUDIENCE=ts-audience \
    AGE_RECIPIENT=age1existingrecipient
  unset GH_PRODUCTION_REVIEWER_ID || true
  gh_api() { :; }
  gh_env_var_exists() { return 0; }  # default: everything already present
  gh_var_set() { :; }
}

@test "reconcile_github_env (staging, all 8 vars present) sets no vars and never PUTs a reviewer" {
  source "$ROOT/steps/50-github-env.sh"
  _github_env_setup_satisfied
  put_calls_log="$BATS_TEST_TMPDIR/gh_api_put.log"
  : > "$put_calls_log"
  gh_api() { printf '%s\n' "$*" >> "$put_calls_log"; }
  var_calls_log="$BATS_TEST_TMPDIR/gh_var_set.log"
  : > "$var_calls_log"
  gh_var_set() { printf '%s\t%s\n' "$1" "$2" >> "$var_calls_log"; }
  run reconcile_github_env
  [ "$status" -eq 0 ]
  [ ! -s "$var_calls_log" ]
  ! grep -q "reviewers" "$put_calls_log"
  ! grep -q "environments/production" "$put_calls_log"
}

@test "reconcile_github_env (staging) sets exactly the absent vars, skipping present ones" {
  source "$ROOT/steps/50-github-env.sh"
  _github_env_setup_satisfied
  # Only API_PORT and AGE_RECIPIENT are absent; the rest already exist.
  gh_env_var_exists() {
    case "$1" in
      API_PORT | AGE_RECIPIENT) return 1 ;;
      *) return 0 ;;
    esac
  }
  var_calls_log="$BATS_TEST_TMPDIR/gh_var_set.log"
  : > "$var_calls_log"
  gh_var_set() { printf '%s\t%s\n' "$1" "$2" >> "$var_calls_log"; }
  run reconcile_github_env
  [ "$status" -eq 0 ]
  [ "$(wc -l < "$var_calls_log")" -eq 2 ]
  grep -q "^API_PORT	8765$" "$var_calls_log"
  grep -q "^AGE_RECIPIENT	age1existingrecipient$" "$var_calls_log"
}

@test "reconcile_github_env stops with NEEDS_MANUAL naming a missing non-secret config value" {
  source "$ROOT/steps/50-github-env.sh"
  _github_env_setup_satisfied
  unset FIREBASE_PROJECT_ID || true
  run reconcile_github_env
  [ "$status" -eq 75 ]
  [[ "$output" == *"FIREBASE_PROJECT_ID"* ]]
}

@test "reconcile_github_env (production) stops with NEEDS_MANUAL naming GH_PRODUCTION_REVIEWER_ID when absent" {
  source "$ROOT/steps/50-github-env.sh"
  _github_env_setup_satisfied
  export ENV_NAME=production
  run reconcile_github_env
  [ "$status" -eq 75 ]
  [[ "$output" == *"GH_PRODUCTION_REVIEWER_ID"* ]]
}

@test "reconcile_github_env (production) PUTs the required-reviewer body with the configured user id" {
  source "$ROOT/steps/50-github-env.sh"
  _github_env_setup_satisfied
  export ENV_NAME=production GH_PRODUCTION_REVIEWER_ID=123456
  put_calls_log="$BATS_TEST_TMPDIR/gh_api_put.log"
  : > "$put_calls_log"
  gh_api() {
    printf '%s\n' "$*" >> "$put_calls_log"
    if [[ "$*" == *"--input -"* ]]; then
      cat >> "$put_calls_log"
      printf '\n' >> "$put_calls_log"
    fi
  }
  run reconcile_github_env
  [ "$status" -eq 0 ]
  grep -q "environments/production" "$put_calls_log"
  grep -q '"reviewers"' "$put_calls_log"
  grep -q '"id":123456' "$put_calls_log"
}

@test "reconcile_github_env (production, all 8 vars ABSENT) re-asserts the reviewer on EVERY env PUT so the last PUT never leaves it wiped" {
  source "$ROOT/steps/50-github-env.sh"
  _github_env_setup_satisfied
  export ENV_NAME=production GH_PRODUCTION_REVIEWER_ID=123456
  # All 8 vars absent → each ensure_gh_var fires a post-reviewer gh_var_set,
  # and the REAL lib.sh wiring has gh_var_set call ensure_gh_environment
  # again. This test proves those later PUTs still carry the reviewer (the
  # security hazard: a no-body PUT after the reviewer was set could wipe it).
  gh_env_var_exists() { return 1; }  # every var absent → every var gets set
  put_calls_log="$BATS_TEST_TMPDIR/gh_api_put.log"
  : > "$put_calls_log"
  # Log each gh_api call's args + (if a body was piped) the body, one line
  # per PUT, so we can assert every production PUT line carries "reviewers".
  gh_api() {
    local body=""
    [[ "$*" == *"--input -"* ]] && body="$(cat)"
    printf '%s %s\n' "$*" "$body" >> "$put_calls_log"
  }
  # Mirror the real lib.sh gh_var_set wiring (ensure_gh_environment first),
  # minus the real `command gh variable set` (no gh binary in the bats image).
  gh_var_set() { ensure_gh_environment; :; }
  run reconcile_github_env
  [ "$status" -eq 0 ]
  # More than one production env PUT happened (top-of-fn ensure + the
  # post-reviewer var-set PUTs) ...
  [ "$(grep -c 'environments/production' "$put_calls_log")" -ge 2 ]
  # ... and NOT ONE of them omitted the reviewer (no production PUT line
  # without "reviewers" — this is the assertion that would fail if a later
  # no-body PUT wiped the gate).
  ! grep 'environments/production' "$put_calls_log" | grep -qv 'reviewers'
  grep -q '"id":123456' "$put_calls_log"
}

@test "reconcile_github_env derives AGE_RECIPIENT from the restore project's age_private_key when the env var is unset" {
  source "$ROOT/steps/50-github-env.sh"
  _github_env_setup_satisfied
  unset AGE_RECIPIENT || true
  export BWS_RESTORE_PROJECT_ID=restoreproj BWS_WRITE_TOKEN=wt
  gh_env_var_exists() {
    case "$1" in
      AGE_RECIPIENT) return 1 ;;
      *) return 0 ;;
    esac
  }
  bws_get_secret_value() {
    if [ "$1" = "age_private_key" ] && [ "$2" = "restoreproj" ]; then
      echo "AGE-SECRET-KEY-STUB"
    fi
  }
  age_keygen() {
    [ "${1:-}" = "-y" ] && echo "age1derivedrecipient"
  }
  var_calls_log="$BATS_TEST_TMPDIR/gh_var_set.log"
  : > "$var_calls_log"
  gh_var_set() { printf '%s\t%s\n' "$1" "$2" >> "$var_calls_log"; }
  run reconcile_github_env
  [ "$status" -eq 0 ]
  grep -q "^AGE_RECIPIENT	age1derivedrecipient$" "$var_calls_log"
}

@test "reconcile_github_env fails (does not set an empty var) when age-keygen -y yields no recipient" {
  source "$ROOT/steps/50-github-env.sh"
  _github_env_setup_satisfied
  unset AGE_RECIPIENT || true
  export BWS_RESTORE_PROJECT_ID=restoreproj BWS_WRITE_TOKEN=wt
  gh_env_var_exists() {
    case "$1" in
      AGE_RECIPIENT) return 1 ;;
      *) return 0 ;;
    esac
  }
  bws_get_secret_value() { echo "AGE-SECRET-KEY-STUB"; }  # private key present
  age_keygen() { :; }  # -y derivation produces nothing (failure path)
  var_calls_log="$BATS_TEST_TMPDIR/gh_var_set.log"
  : > "$var_calls_log"
  gh_var_set() { printf '%s\t%s\n' "$1" "$2" >> "$var_calls_log"; }
  run reconcile_github_env
  [ "$status" -ne 0 ]
  [ "$status" -ne 75 ]  # a hard error, not a manual gate
  [[ "$output" == *"AGE_RECIPIENT"* ]]
  [[ "$output" == *"invalid"* ]]
  # Never set AGE_RECIPIENT (or any var) to an empty/invalid value.
  ! grep -q "^AGE_RECIPIENT" "$var_calls_log"
}

@test "reconcile_github_env stops with NEEDS_MANUAL naming BWS_RESTORE_PROJECT_ID when AGE_RECIPIENT must be derived but the restore project id is absent" {
  source "$ROOT/steps/50-github-env.sh"
  _github_env_setup_satisfied
  unset AGE_RECIPIENT BWS_RESTORE_PROJECT_ID || true
  export BWS_WRITE_TOKEN=wt
  run reconcile_github_env
  [ "$status" -eq 75 ]
  [[ "$output" == *"BWS_RESTORE_PROJECT_ID"* ]]
}

@test "reconcile_github_env stops with NEEDS_MANUAL naming BWS_WRITE_TOKEN when AGE_RECIPIENT must be derived but no write token is available (--only github-env, no earlier step this session)" {
  source "$ROOT/steps/50-github-env.sh"
  _github_env_setup_satisfied
  unset AGE_RECIPIENT BWS_WRITE_TOKEN || true
  export BWS_RESTORE_PROJECT_ID=restoreproj
  run reconcile_github_env
  [ "$status" -eq 75 ]
  [[ "$output" == *"BWS_WRITE_TOKEN"* ]]
}

# --- step 60: reconcile_droplet ---------------------------------------------
# doctl_cli/ssh_keygen/ssh_keyscan/gh_secret_set are stubbed directly (same
# convention as every other step's provider wrapper). The bats Docker image
# mounts ONLY backend/deploy/provision/, not the wider repo, so the real
# backend/scripts/ helper scripts bootstrap.sh installs do not exist inside
# it — BACKEND_SCRIPTS_DIR (read at 60-droplet.sh source time) is pointed at
# fixture scripts under $BATS_TEST_TMPDIR instead. bootstrap.sh itself IS
# reachable for real (it lives directly under the mounted provision/ dir).
_droplet_setup_absent_gated() {
  export ENV_NAME=staging DO_TOKEN=do-token-x TS_AUTH_KEY=tskey-ephemeral \
    DO_REGION=sgp1 DO_SIZE=s-1vcpu-1gb SSH_HOST=pc-staging TS_TAG=tag:pc-staging
  export BACKEND_SCRIPTS_DIR="$BATS_TEST_TMPDIR/backend-scripts"
  mkdir -p "$BACKEND_SCRIPTS_DIR"
  for f in switch-deployment.sh write-secret.sh rollback.sh; do
    printf '#!/usr/bin/env bash\necho fixture-%s\n' "$f" >"$BACKEND_SCRIPTS_DIR/$f"
  done
  : >"$BATS_TEST_TMPDIR/doctl.log"
  : >"$BATS_TEST_TMPDIR/gh_secret_set.log"
  doctl_cli() {
    printf '%s\n' "$*" >>"$BATS_TEST_TMPDIR/doctl.log"
    case "$1 $2 $3" in
      "compute droplet list") return 0 ;; # empty list -> unambiguously absent
      "compute droplet create")
        # Capture the --user-data-file content while it still exists — the
        # real step deletes its tmp file right after this call returns.
        shift 3
        local f=""
        while [ "$#" -gt 0 ]; do
          case "$1" in
            --user-data-file)
              f="$2"
              shift 2
              ;;
            *) shift ;;
          esac
        done
        [ -n "$f" ] && cp "$f" "$BATS_TEST_TMPDIR/captured-user-data.yaml"
        return 0
        ;;
    esac
    return 0
  }
  ssh_keygen() {
    local out=""
    while [ "$#" -gt 0 ]; do
      case "$1" in
        -f)
          out="$2"
          shift 2
          ;;
        -t | -N | -C)
          shift 2
          ;;
        *) shift ;;
      esac
    done
    printf 'FAKE-PRIVATE-KEY\n' >"$out"
    printf 'ssh-ed25519 AAAAFAKEKEY deploy@peppercheck-ci\n' >"${out}.pub"
  }
  gh_secret_set() { printf '%s\t%s\n' "$1" "$2" >>"$BATS_TEST_TMPDIR/gh_secret_set.log"; }
  ssh_keyscan() { printf 'pc-staging ssh-ed25519 AAAAHOSTKEY\n'; }
}

@test "reconcile_droplet stops with NEEDS_MANUAL naming DO_TOKEN when absent" {
  source "$ROOT/steps/60-droplet.sh"
  export ENV_NAME=staging
  unset DO_TOKEN || true
  run reconcile_droplet
  [ "$status" -eq 75 ]
  [[ "$output" == *"DO_TOKEN"* ]]
}

@test "reconcile_droplet is SATISFIED (no create, no keypair, no secret writes) when the Droplet already exists" {
  source "$ROOT/steps/60-droplet.sh"
  export ENV_NAME=staging DO_TOKEN=do-token-x
  calls_log="$BATS_TEST_TMPDIR/doctl.log"
  : >"$calls_log"
  doctl_cli() {
    printf '%s\n' "$*" >>"$calls_log"
    case "$1 $2 $3" in
      "compute droplet list")
        printf 'some-other-droplet\npc-staging\nyet-another\n' # name present
        return 0
        ;;
    esac
    return 1
  }
  keygen_calls_log="$BATS_TEST_TMPDIR/keygen.log"
  : >"$keygen_calls_log"
  ssh_keygen() { echo "called" >>"$keygen_calls_log"; }
  secret_calls_log="$BATS_TEST_TMPDIR/gh_secret_set.log"
  : >"$secret_calls_log"
  gh_secret_set() { printf '%s\n' "$1" >>"$secret_calls_log"; }
  run reconcile_droplet
  [ "$status" -eq 0 ]
  grep -q "^compute droplet list --format Name --no-header$" "$calls_log"
  ! grep -q "^compute droplet create" "$calls_log"
  [ ! -s "$keygen_calls_log" ]
  [ ! -s "$secret_calls_log" ]
}

@test "reconcile_droplet fails closed (aborts, no create) when the Droplet list query itself fails, rather than risking a duplicate" {
  source "$ROOT/steps/60-droplet.sh"
  export ENV_NAME=staging DO_TOKEN=do-token-x TS_AUTH_KEY=tskey-ephemeral \
    DO_REGION=sgp1 DO_SIZE=s-1vcpu-1gb SSH_HOST=pc-staging TS_TAG=tag:pc-staging
  calls_log="$BATS_TEST_TMPDIR/doctl.log"
  : >"$calls_log"
  doctl_cli() {
    printf '%s\n' "$*" >>"$calls_log"
    case "$1 $2 $3" in
      "compute droplet list") return 1 ;; # transient failure (token/network)
    esac
    return 0
  }
  keygen_calls_log="$BATS_TEST_TMPDIR/keygen.log"
  : >"$keygen_calls_log"
  ssh_keygen() { echo "called" >>"$keygen_calls_log"; }
  run reconcile_droplet
  # A hard error, NOT a NEEDS_MANUAL gate and NOT a silent success.
  [ "$status" -ne 0 ]
  [ "$status" -ne 75 ]
  # Never proceeded to create a (duplicate) Droplet, never minted a keypair.
  ! grep -q "^compute droplet create" "$calls_log"
  [ ! -s "$keygen_calls_log" ]
}

@test "reconcile_droplet stops with NEEDS_MANUAL naming TS_AUTH_KEY when the Droplet is absent and no auth key was minted this run" {
  source "$ROOT/steps/60-droplet.sh"
  export ENV_NAME=staging DO_TOKEN=do-token-x
  unset TS_AUTH_KEY || true
  doctl_cli() { case "$1 $2 $3" in "compute droplet list") return 0 ;; esac; return 1; }
  run reconcile_droplet
  [ "$status" -eq 75 ]
  [[ "$output" == *"TS_AUTH_KEY"* ]]
}

@test "reconcile_droplet stops with NEEDS_MANUAL naming missing non-secret config (DO_REGION/DO_SIZE/SSH_HOST/TS_TAG)" {
  source "$ROOT/steps/60-droplet.sh"
  export ENV_NAME=staging DO_TOKEN=do-token-x TS_AUTH_KEY=tskey-ephemeral
  unset DO_REGION DO_SIZE SSH_HOST TS_TAG || true
  doctl_cli() { case "$1 $2 $3" in "compute droplet list") return 0 ;; esac; return 1; }
  run reconcile_droplet
  [ "$status" -eq 75 ]
  [[ "$output" == *"DO_REGION"* ]]
  [[ "$output" == *"SSH_HOST"* ]]
  [[ "$output" == *"TS_TAG"* ]]
}

@test "reconcile_droplet aborts (no create, no SSH_DEPLOY_KEY) when ssh-keygen fails" {
  source "$ROOT/steps/60-droplet.sh"
  _droplet_setup_absent_gated
  # ssh-keygen fails: since the orchestrator runs steps under set +e,
  # ensure_deploy_keypair's `return 1` only aborts the step because the call
  # site guards it with `|| return 1`. Without that guard the step would go on
  # to create a real Droplet with an empty DEPLOY_SSH_PUBLIC_KEY.
  ssh_keygen() { return 1; }
  run reconcile_droplet
  [ "$status" -ne 0 ]
  [ "$status" -ne 75 ]
  ! grep -q "^compute droplet create" "$BATS_TEST_TMPDIR/doctl.log"
  ! grep -q "^SSH_DEPLOY_KEY" "$BATS_TEST_TMPDIR/gh_secret_set.log"
}

@test "reconcile_droplet creates the Droplet with --user-data-file, generates+stores the deploy keypair, and captures+stores the host key" {
  source "$ROOT/steps/60-droplet.sh"
  _droplet_setup_absent_gated
  run reconcile_droplet
  [ "$status" -eq 0 ]

  # Deploy keypair generated; ONLY the private half is stored, under the
  # exact secret name deploy-vps.yml reads.
  grep -q "^SSH_DEPLOY_KEY	FAKE-PRIVATE-KEY$" "$BATS_TEST_TMPDIR/gh_secret_set.log"
  ! grep -q "AAAAFAKEKEY" "$BATS_TEST_TMPDIR/gh_secret_set.log"

  # Droplet created with region/size/image/--user-data-file/--wait.
  grep -q "^compute droplet create pc-staging --region sgp1 --size s-1vcpu-1gb --image ubuntu-24-04-x64" "$BATS_TEST_TMPDIR/doctl.log"
  grep -q -- "--user-data-file" "$BATS_TEST_TMPDIR/doctl.log"
  grep -q -- "--wait" "$BATS_TEST_TMPDIR/doctl.log"

  # The rendered cloud-init user-data (captured by the doctl_cli stub before
  # the real step deletes its tmp file) references bootstrap.sh and carries
  # the 3 bootstrap env vars.
  ud="$BATS_TEST_TMPDIR/captured-user-data.yaml"
  [ -s "$ud" ]
  grep -q "bootstrap.sh" "$ud"
  grep -q "TAILSCALE_TAG=tag:pc-staging" "$ud"
  grep -q "TAILSCALE_AUTH_KEY=tskey-ephemeral" "$ud"
  grep -q "DEPLOY_SSH_PUBLIC_KEY=ssh-ed25519 AAAAFAKEKEY deploy@peppercheck-ci" "$ud"

  # Host key captured (stubbed ssh-keyscan) and stored under the exact
  # secret name deploy-vps.yml reads.
  grep -q "^SSH_HOST_KEY	pc-staging ssh-ed25519 AAAAHOSTKEY$" "$BATS_TEST_TMPDIR/gh_secret_set.log"
}

@test "reconcile_droplet fails clearly (not hanging) when ssh-keyscan cannot reach the tailnet host within the poll window" {
  source "$ROOT/steps/60-droplet.sh"
  _droplet_setup_absent_gated
  export SSH_HOST_KEY_POLL_TIMEOUT=2 SSH_HOST_KEY_POLL_INTERVAL=1
  ssh_keyscan() { return 1; } # never resolves
  run reconcile_droplet
  [ "$status" -eq 1 ]
  [[ "$output" == *"tailnet"* ]]
  # The Droplet + deploy keypair were still created/stored before the poll
  # gave up; only the host-key secret is missing.
  grep -q "^SSH_DEPLOY_KEY" "$BATS_TEST_TMPDIR/gh_secret_set.log"
  ! grep -q "^SSH_HOST_KEY" "$BATS_TEST_TMPDIR/gh_secret_set.log"
}

@test "reconcile_droplet in dry-run does not create the Droplet, store secrets, or attempt host-key capture" {
  source "$ROOT/steps/60-droplet.sh"
  _droplet_setup_absent_gated
  DRY_RUN=1
  ssh_keyscan() { echo "should not be called" >>"$BATS_TEST_TMPDIR/keyscan-called.log"; }
  run reconcile_droplet
  [ "$status" -eq 0 ]
  ! grep -q "^compute droplet create" "$BATS_TEST_TMPDIR/doctl.log"
  [ ! -e "$BATS_TEST_TMPDIR/keyscan-called.log" ]
  [ ! -s "$BATS_TEST_TMPDIR/gh_secret_set.log" ]
}

@test "reconcile_droplet leaves no plaintext-auth-key cloud-init file (or private key) on disk when the create fails mid-flight" {
  source "$ROOT/steps/60-droplet.sh"
  _droplet_setup_absent_gated
  # Point mktemp at a controlled root so the RETURN-trap cleanup is checkable;
  # both the deploy-key dir and the cloud-init dir are created under here.
  export TMPDIR="$BATS_TEST_TMPDIR/tmproot"
  mkdir -p "$TMPDIR"
  # Make the Droplet create fail AFTER render_cloud_init has already written
  # the user-data file (which embeds the plaintext ephemeral auth key).
  doctl_cli() {
    printf '%s\n' "$*" >>"$BATS_TEST_TMPDIR/doctl.log"
    case "$1 $2 $3" in
      "compute droplet list") return 0 ;;   # absent
      "compute droplet create") return 1 ;; # fails mid-flight
    esac
    return 0
  }
  run reconcile_droplet
  [ "$status" -ne 0 ]
  # The trap cleaned both temp dirs: no cloud-init user-data file and no
  # private key material survive anywhere under the controlled TMPDIR.
  ! grep -rq "tskey-ephemeral" "$TMPDIR" 2>/dev/null
  ! grep -rq "FAKE-PRIVATE-KEY" "$TMPDIR" 2>/dev/null
  [ -z "$(find "$TMPDIR" -type f 2>/dev/null)" ]
}
