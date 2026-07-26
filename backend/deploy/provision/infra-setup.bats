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
