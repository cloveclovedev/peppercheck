#!/usr/bin/env bash
# Run an isolated local stack for the current Git worktree.
#
# Usage:
#   scripts/worktree/dev.sh backend-up
#   scripts/worktree/dev.sh flutter-run --device <device-id>
#   scripts/worktree/dev.sh backend-test
#   scripts/worktree/dev.sh settings
#   scripts/worktree/dev.sh status
#
# The optional --instance and port flags make the same worktree identity
# repeatable. Defaults are derived from its absolute path.
set -euo pipefail

usage() {
  cat <<'EOF'
Usage:
  scripts/worktree/dev.sh backend-up
  scripts/worktree/dev.sh backend-down [--volumes]
  scripts/worktree/dev.sh flutter-run --device <device-id>
  scripts/worktree/dev.sh backend-test
  scripts/worktree/dev.sh settings
  scripts/worktree/dev.sh status

  backend-down stops the stack but keeps its volumes so a later backend-up
  resumes with the same data. Add --volumes (-v) to also remove the volumes
  (Postgres data, the local WAL archive, and Caddy state) for a full teardown.
EOF
}

repo_root="$(git rev-parse --show-toplevel)"
instance=""
caddy_port=""
https_port=""
postgres_port=""
test_postgres_port=""
device_id=""
caddy_port_explicit=0
https_port_explicit=0
postgres_port_explicit=0
test_postgres_port_explicit=0
remove_volumes=0
command=""

# Options and the command may appear in any order, so the documented
# `dev.sh flutter-run --device <id>` form works as well as options-first.
while [ "$#" -gt 0 ]; do
  case "$1" in
    --instance)
      instance="${2:?--instance requires a value}"
      shift
      ;;
    --caddy-port)
      caddy_port="${2:?--caddy-port requires a value}"
      caddy_port_explicit=1
      shift
      ;;
    --https-port)
      https_port="${2:?--https-port requires a value}"
      https_port_explicit=1
      shift
      ;;
    --postgres-port)
      postgres_port="${2:?--postgres-port requires a value}"
      postgres_port_explicit=1
      shift
      ;;
    --test-postgres-port)
      test_postgres_port="${2:?--test-postgres-port requires a value}"
      test_postgres_port_explicit=1
      shift
      ;;
    --device)
      device_id="${2:?--device requires a device ID}"
      shift
      ;;
    --volumes|-v)
      remove_volumes=1
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    --*)
      echo "unknown option: $1" >&2
      usage >&2
      exit 2
      ;;
    *)
      if [ -n "$command" ]; then
        echo "unexpected argument: $1" >&2
        usage >&2
        exit 2
      fi
      command="$1"
      ;;
  esac
  shift
done

command="${command:-status}"

if [ "$remove_volumes" -eq 1 ] && [ "$command" != "backend-down" ]; then
  echo "--volumes is only valid with backend-down" >&2
  exit 2
fi

if [ -z "$instance" ]; then
  instance="$(basename "$repo_root")"
fi
instance="$(printf '%s' "$instance" | tr '[:upper:]' '[:lower:]' | tr -cs 'a-z0-9_-' '-')"
instance="${instance#-}"
instance="${instance%-}"
[ -n "$instance" ] || { echo "--instance must contain a letter or digit" >&2; exit 2; }

# Start probing from a stable path-derived slot. The selected backend ports are
# persisted in this worktree's Git administrative directory, not in the work
# tree, so later lifecycle commands use the same stack.
worktree_hash="$(printf '%s' "$repo_root" | cksum | awk '{print $1}')"
initial_slot="$((worktree_hash % 100))"
state_file="$(git rev-parse --git-path peppercheck-worktree-dev.env)"
case "$state_file" in
  /*) ;;
  *) state_file="$repo_root/$state_file" ;;
esac
compose_project="pc_${instance}_${worktree_hash}"
test_container="pc-${instance}-${worktree_hash}-test"

state_caddy_port=""
state_https_port=""
state_postgres_port=""

load_state() {
  [ -f "$state_file" ] || return 0

  while IFS='=' read -r key value; do
    case "$key" in
      CADDY_HTTP_PORT) state_caddy_port="$value" ;;
      CADDY_HTTPS_PORT) state_https_port="$value" ;;
      POSTGRES_HOST_PORT) state_postgres_port="$value" ;;
    esac
  done < "$state_file"
}

is_numeric_port() {
  case "$1" in
    ''|*[!0-9]*) return 1 ;;
    *) return 0 ;;
  esac
}

require_lsof() {
  command -v lsof >/dev/null 2>&1 || {
    echo "lsof is required to select an available local port" >&2
    exit 1
  }
}

port_is_available() {
  ! lsof -nP -iTCP:"$1" -sTCP:LISTEN -t >/dev/null 2>&1
}

backend_ports_are_available() {
  port_is_available "$caddy_port" \
    && port_is_available "$https_port" \
    && port_is_available "$postgres_port"
}

select_backend_ports() {
  require_lsof

  for offset in $(seq 0 99); do
    slot="$(((initial_slot + offset) % 100))"
    candidate_caddy="${caddy_port:-$((18000 + slot))}"
    candidate_https="${https_port:-$((19000 + slot))}"
    candidate_postgres="${postgres_port:-$((15432 + slot))}"

    if port_is_available "$candidate_caddy" \
      && port_is_available "$candidate_https" \
      && port_is_available "$candidate_postgres"; then
      caddy_port="$candidate_caddy"
      https_port="$candidate_https"
      postgres_port="$candidate_postgres"
      return 0
    fi
  done

  echo "could not find an available Caddy HTTP/HTTPS and Postgres port set" >&2
  exit 1
}

select_test_postgres_port() {
  require_lsof

  for offset in $(seq 0 99); do
    slot="$(((initial_slot + offset) % 100))"
    candidate_test_postgres="${test_postgres_port:-$((16432 + slot))}"
    if port_is_available "$candidate_test_postgres"; then
      test_postgres_port="$candidate_test_postgres"
      return 0
    fi
  done

  echo "could not find an available test Postgres port" >&2
  exit 1
}

write_state() {
  umask 077
  mkdir -p "$(dirname "$state_file")"
  cat > "$state_file" <<EOF
CADDY_HTTP_PORT=$caddy_port
CADDY_HTTPS_PORT=$https_port
POSTGRES_HOST_PORT=$postgres_port
EOF
}

stack_is_running() {
  docker ps --filter "label=com.docker.compose.project=$compose_project" --quiet \
    | grep -q .
}

load_state
caddy_port="${caddy_port:-${state_caddy_port:-$((18000 + initial_slot))}}"
https_port="${https_port:-${state_https_port:-$((19000 + initial_slot))}}"
postgres_port="${postgres_port:-${state_postgres_port:-$((15432 + initial_slot))}}"
test_postgres_port="${test_postgres_port:-$((16432 + initial_slot))}"

for port in "$caddy_port" "$https_port" "$postgres_port" "$test_postgres_port"; do
  is_numeric_port "$port" || { echo "port must be numeric: $port" >&2; exit 2; }
done

backend_make() {
  COMPOSE_PROJECT_NAME="$compose_project" \
  CADDY_HTTP_PORT="$caddy_port" \
  CADDY_HTTPS_PORT="$https_port" \
  POSTGRES_HOST_PORT="$postgres_port" \
  make -C "$repo_root/backend" "$@"
}

print_settings() {
  cat <<EOF
worktree:        $repo_root
compose project: $compose_project
Caddy HTTP:      http://127.0.0.1:$caddy_port
Caddy HTTPS:     https://127.0.0.1:$https_port
Postgres:        127.0.0.1:$postgres_port
test Postgres:   127.0.0.1:$test_postgres_port
EOF
}

case "$command" in
  backend-up)
    if ! stack_is_running; then
      if ! backend_ports_are_available; then
        if { [ "$caddy_port_explicit" -eq 1 ] && ! port_is_available "$caddy_port"; } \
          || { [ "$https_port_explicit" -eq 1 ] && ! port_is_available "$https_port"; } \
          || { [ "$postgres_port_explicit" -eq 1 ] && ! port_is_available "$postgres_port"; }; then
          echo "an explicitly selected backend port is already in use" >&2
          exit 1
        fi
        [ "$caddy_port_explicit" -eq 1 ] || caddy_port=""
        [ "$https_port_explicit" -eq 1 ] || https_port=""
        [ "$postgres_port_explicit" -eq 1 ] || postgres_port=""
        select_backend_ports
      fi
      write_state
    fi
    backend_make up
    print_settings
    ;;
  backend-down)
    if [ "$remove_volumes" -eq 1 ]; then
      backend_make down-v
      rm -f "$state_file"
    else
      backend_make down
    fi
    ;;
  backend-logs)
    backend_make logs
    ;;
  backend-test)
    require_lsof
    if ! port_is_available "$test_postgres_port"; then
      if [ "$test_postgres_port_explicit" -eq 1 ]; then
        echo "the explicitly selected test Postgres port is already in use" >&2
        exit 1
      fi
      test_postgres_port=""
      select_test_postgres_port
    fi
    make -C "$repo_root/backend" test \
      TEST_CONTAINER_NAME="$test_container" \
      TEST_POSTGRES_PORT="$test_postgres_port"
    ;;
  flutter-run)
    [ -n "$device_id" ] || { echo "flutter-run requires --device <device-id>" >&2; exit 2; }
    (
      cd "$repo_root/peppercheck_flutter"
      exec flutter run --flavor dev -t lib/main_dev.dart \
        --dart-define="DEV_API_PORT=$caddy_port" -d "$device_id"
    )
    ;;
  settings)
    print_settings
    ;;
  status)
    print_settings
    backend_make ps
    ;;
  *)
    echo "unknown command: $command" >&2
    usage >&2
    exit 2
    ;;
esac
