#!/usr/bin/env bash
# Local pgBackRest smoke test.
#
# Brings up MinIO + the custom peppercheck-postgres image (compose.test.yaml,
# isolated under the "peppercheck-test" Compose project) and proves
# pgBackRest can stanza-create, push WAL, take a full backup, and pass
# `check` against an S3-compatible repo. Prints "pgbackrest local smoke OK"
# on success.
#
# pgBackRest's S3 driver requires TLS (see compose.test.yaml's TLS note), so
# this script generates a throwaway self-signed cert for MinIO before
# bringing the stack up. The cert directory is gitignored and regenerated
# every run.
set -euo pipefail

cd "$(dirname "${BASH_SOURCE[0]}")/.."

readonly PROJECT="peppercheck-test"
readonly COMPOSE_FILE="compose.test.yaml"
readonly CERT_DIR="deploy/test-fixtures/minio-certs"

compose() {
  docker compose -f "$COMPOSE_FILE" -p "$PROJECT" "$@"
}

# `compose exec` attaches a fresh process to the container's *declared*
# environment (image ENV + compose `environment:`) -- it does NOT see the
# PGBACKREST_REPO1_CIPHER_PASS / _S3_KEY / _S3_KEY_SECRET vars that
# entrypoint.sh exports at PID 1 startup only for its own exec'd child tree
# (postgres and, transitively, archive_command). So every out-of-band
# `pgbackrest` invocation here re-derives those three from the same
# /run/secrets/* files entrypoint.sh reads, inside the exec'd shell.
pgbackrest_exec() {
  # -u postgres: the container's default exec user is root (the image never
  # drops to postgres via USER; only the entrypoint's own gosu-based
  # docker-entrypoint.sh does that for the main process), and pgBackRest
  # refuses to run stanza-create/backup/etc as root by default.
  # shellcheck disable=SC2016 # single-quoted on purpose: this expands inside
  # the container's exec'd shell, not the host shell running this script.
  compose exec -T -u postgres postgres bash -c '
    export PGBACKREST_REPO1_CIPHER_PASS="$(tr -d "\n" < /run/secrets/pgbackrest_cipher)"
    export PGBACKREST_REPO1_S3_KEY="$(tr -d "\n" < /run/secrets/b2_key_id)"
    export PGBACKREST_REPO1_S3_KEY_SECRET="$(tr -d "\n" < /run/secrets/b2_key_secret)"
    exec pgbackrest "$@"
  ' bash "$@"
}

cleanup() {
  local status=$?
  echo "==> Tearing down ${PROJECT} stack"
  compose down -v --remove-orphans || true
  exit "$status"
}
trap cleanup EXIT

echo "==> Generating throwaway self-signed TLS cert for MinIO"
rm -rf "$CERT_DIR"
mkdir -p "$CERT_DIR"
openssl req -x509 -nodes -newkey rsa:2048 \
  -keyout "$CERT_DIR/private.key" \
  -out "$CERT_DIR/public.crt" \
  -days 3650 \
  -subj "/CN=minio" \
  -addext "subjectAltName=DNS:minio,DNS:localhost,IP:127.0.0.1" \
  >/dev/null 2>&1

echo "==> Bringing up MinIO + createbucket + postgres (project ${PROJECT})"
compose up -d --build

echo "==> Waiting for postgres to become healthy"
for i in $(seq 1 30); do
  status="$(docker inspect -f '{{.State.Health.Status}}' "$(compose ps -q postgres)" 2>/dev/null || echo "starting")"
  if [ "$status" = "healthy" ]; then
    break
  fi
  if [ "$i" -eq 30 ]; then
    echo "postgres never became healthy" >&2
    compose logs postgres >&2
    exit 1
  fi
  sleep 2
done

echo "==> pgbackrest stanza-create"
pgbackrest_exec --stanza=main stanza-create

echo "==> Forcing a WAL switch (exercises archive_command -> archive-push)"
compose exec -T postgres psql -U postgres -d peppercheck -c "select pg_switch_wal();"

echo "==> Waiting for the switched WAL segment to reach the repo"
for i in $(seq 1 15); do
  if pgbackrest_exec --stanza=main info --output=json | grep -q '"min"'; then
    break
  fi
  sleep 2
done

echo "==> pgbackrest full backup"
pgbackrest_exec --stanza=main --type=full backup

echo "==> pgbackrest check"
pgbackrest_exec --stanza=main check

echo "pgbackrest local smoke OK"
