#!/usr/bin/env bash
#
# Guided setup for the PepperCheck debug Stripe sandbox.
#
# What this does:
#   1. Confirms the debug sandbox has been created in the Stripe Dashboard.
#   2. Runs `stripe login --project-name=peppercheck-debug` (browser-based).
#   3. Runs `stripe listen --project-name=peppercheck-debug --print-secret`
#      and prints the resulting webhook signing secret.
#   4. Prints the two .env lines the operator should paste into
#      supabase/functions/.env, plus verification commands.
#
# What this does NOT do:
#   - Edit any .env file. The operator pastes secrets themselves.
#   - Create or modify anything in the Stripe sandbox itself.
#
# Spec: docs/superpowers/specs/2026-05-31-stripe-debug-sandbox-design.md

set -euo pipefail

if ! command -v stripe >/dev/null 2>&1; then
  echo "Error: the 'stripe' CLI is not on PATH." >&2
  echo "Install it with: brew install stripe/stripe-cli/stripe" >&2
  exit 1
fi
