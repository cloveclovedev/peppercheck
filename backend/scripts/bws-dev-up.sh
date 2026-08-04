#!/usr/bin/env bash
# Starts the local Compose stack with real dev secrets injected from Bitwarden
# Secrets Manager (bws). See docs/development/bws-development.md.
set -euo pipefail

if [ "$#" -gt 1 ]; then
  echo "usage: $0 [BWS project ID]" >&2
  echo "  (with no argument, auto-resolves the shared 'development' project)" >&2
  exit 2
fi

if ! command -v bws >/dev/null 2>&1; then
  echo "bws is not installed; install the Bitwarden Secrets Manager CLI first (see docs/development/bws-development.md)" >&2
  exit 127
fi

if ! command -v jq >/dev/null 2>&1; then
  echo "jq is not installed; required to resolve the bws project (brew install jq)" >&2
  exit 127
fi

if [ -z "${BWS_ACCESS_TOKEN:-}" ] && command -v security >/dev/null 2>&1; then
  # This machine account's token is shared across repos that read the same
  # BWS `development` project (see docs/development/bws-development.md). The
  # value is read only into this process tree, never written to disk here.
  BWS_ACCESS_TOKEN="$(security find-generic-password -a "$(id -un)" -s "bws-local-access-token" -w 2>/dev/null || true)"
  export BWS_ACCESS_TOKEN
fi

if [ -z "${BWS_ACCESS_TOKEN:-}" ]; then
  echo "BWS_ACCESS_TOKEN is required; add bws-local-access-token to macOS Keychain or set it for this one command" >&2
  exit 2
fi

PROJECT_ID="${1:-}"
if [ -z "$PROJECT_ID" ]; then
  # The project ID is not secret, and this machine account can only ever see
  # the one shared 'development' project (see docs/development/bws-development.md)
  # — resolve it by name instead of requiring every operator to look it up
  # and pass it on every invocation.
  PROJECT_ID="$(bws project list | jq -r '
    [.[] | select(.name == "development")] as $matches
    | if ($matches | length) == 1 then $matches[0].id
      elif ($matches | length) == 0 then "MISSING"
      else "AMBIGUOUS" end
  ')"
  case "$PROJECT_ID" in
    MISSING)
      echo "no bws project named 'development' visible to this access token" >&2
      exit 2 ;;
    AMBIGUOUS)
      echo "multiple bws projects named 'development' are visible; pass one explicitly: $0 <project-id>" >&2
      exit 2 ;;
  esac
fi

# bws injects only this project's secret values (e.g. R2_ACCESS_KEY_ID,
# R2_SECRET_ACCESS_KEY) into Compose's process environment; BWS_ACCESS_TOKEN
# itself is never listed in compose.yaml or passed to a container. .env is
# still loaded as normal -- Compose gives process-environment variables
# precedence over .env, so the bws-injected values override the .env
# dummies for the keys bws actually provides, while every other variable
# (non-secret config and required-but-non-secret variables such as
# POSTGRES_PASSWORD and API_PORT) keeps coming from .env.
exec bws run --project-id "$PROJECT_ID" -- docker compose up -d --build
