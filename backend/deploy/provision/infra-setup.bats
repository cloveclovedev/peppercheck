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
  created=0; bws_put_secret() { created=1; }
  export BWS_WRITE_TOKEN=x BWS_PROJECT_ID=p BWS_RESTORE_PROJECT_ID=r
  run reconcile_secrets
  [ "$status" -eq 0 ]
  [ "$created" -eq 0 ]  # nothing regenerated
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
# project ids, with the project-reachability wrapper stubbed to report ok.
_bws_setup_reachable_project() {
  export BWS_WRITE_TOKEN=wt BWS_PROJECT_ID=p BWS_RESTORE_PROJECT_ID=r
  bws_project_exists() { return 0; }
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
