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
