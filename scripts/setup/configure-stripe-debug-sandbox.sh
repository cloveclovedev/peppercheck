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

cat <<'EOF'

Before continuing, in the Stripe Dashboard:

  1. Create a new sandbox dedicated to local debug.
     URL: https://dashboard.stripe.com/test/sandboxes
  2. Enable Stripe Connect for that sandbox
     (Settings > Connect > Get started, in the new sandbox).
  3. Note the sandbox-scoped sk_test_... key from
     Developers > API keys (visible only after selecting the sandbox).

EOF

read -r -p "Have you created the debug sandbox and enabled Connect? [y/N]: " answer
case "${answer:-N}" in
  y|Y|yes|YES) ;;
  *)
    echo "Aborting. Re-run this script after creating the sandbox." >&2
    exit 1
    ;;
esac

echo
echo "Setting up the 'peppercheck-debug' Stripe CLI profile."
echo "A browser window will open — approve the pairing and SELECT THE DEBUG SANDBOX"
echo "(not the staging sandbox or live mode)."
echo
stripe login --project-name=peppercheck-debug

echo
echo "Fetching the local webhook signing secret..."
webhook_secret=$(stripe listen --project-name=peppercheck-debug --print-secret)

if [[ -z "${webhook_secret}" ]]; then
  echo "Error: stripe listen --print-secret returned empty output." >&2
  echo "Check that the peppercheck-debug profile was set up correctly." >&2
  exit 1
fi
