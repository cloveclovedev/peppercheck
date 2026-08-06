#!/usr/bin/env bash
#
# Guided setup for the PepperCheck dev Stripe sandbox.
#
# What this does:
#   1. Confirms the dev sandbox has been created in the Stripe Dashboard.
#   2. Runs `stripe login --project-name=cloveclove-dev` (browser-based).
#   3. Runs `stripe listen --project-name=cloveclove-dev --print-secret`
#      and prints the resulting webhook signing secret.
#   4. Prints the two .env lines the operator should paste into
#      supabase/functions/.env, plus verification commands.
#
# What this does NOT do:
#   - Edit any .env file. The operator pastes secrets themselves.
#   - Create or modify anything in the Stripe sandbox itself.
#
set -euo pipefail

if ! command -v stripe >/dev/null 2>&1; then
  echo "Error: the 'stripe' CLI is not on PATH." >&2
  echo "Install it with: brew install stripe/stripe-cli/stripe" >&2
  exit 1
fi

cat <<'EOF'

Before continuing, in the Stripe Dashboard:

  1. Create a new sandbox dedicated to local dev.
     URL: https://dashboard.stripe.com/test/sandboxes
  2. Enable Stripe Connect for that sandbox
     (Settings > Connect > Get started, in the new sandbox).
  3. Note the sandbox-scoped sk_test_... key from
     Developers > API keys (visible only after selecting the sandbox).

EOF

read -r -p "Have you created the dev sandbox and enabled Connect? [y/N]: " answer
case "${answer:-N}" in
  y|Y|yes|YES) ;;
  *)
    echo "Aborting. Re-run this script after creating the sandbox." >&2
    exit 1
    ;;
esac

echo
echo "Setting up the 'cloveclove-dev' Stripe CLI profile."
echo "A browser window will open — approve the pairing and SELECT THE DEV SANDBOX"
echo "(not the staging sandbox or live mode)."
echo
stripe login --project-name=cloveclove-dev

echo
echo "Fetching the local webhook signing secret..."
webhook_secret=$(stripe listen --project-name=cloveclove-dev --print-secret)

if [[ -z "${webhook_secret}" ]]; then
  echo "Error: stripe listen --print-secret returned empty output." >&2
  echo "Check that the cloveclove-dev profile was set up correctly." >&2
  exit 1
fi

cat <<EOF

------------------------------------------------------------
Setup complete. Next steps for the operator:
------------------------------------------------------------

1. Open supabase/functions/.env (create it from supabase/functions/.env.example
   if it does not exist) and add or update these two lines with the dev
   sandbox values:

   STRIPE_SECRET_KEY=<paste your sk_test_... from the Dashboard>
   STRIPE_WEBHOOK_SECRET=${webhook_secret}

2. Start the local Supabase Edge Function (in one terminal):

   supabase functions serve handle-stripe-webhook \\
     --env-file supabase/functions/.env

3. Start the webhook forwarder (in a second terminal):

   stripe listen --project-name=cloveclove-dev \\
     --forward-to http://localhost:54321/functions/v1/handle-stripe-webhook

4. Trigger a test event (in a third terminal):

   stripe trigger account.updated --project-name=cloveclove-dev

5. Verify in the 'supabase functions serve' logs that the event arrived
   with a 200 response and signature verification passed.

EOF
