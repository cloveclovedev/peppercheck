#!/usr/bin/env bash
# Set GitHub Secrets for peppercheck CI/CD from a config file.
#
# Usage:
#   ./scripts/setup-github-secrets.sh                    # uses ~/.config/peppercheck/github-secrets
#   ./scripts/setup-github-secrets.sh path/to/file       # uses custom file
#
# Binary/file secrets must be set separately. The full list of file-style
# secrets and their gh-secret-set invocations is documented at the bottom
# of scripts/github-secrets.example. This script also prints a summary
# after the text-secret pass.
#
# To keep ~/.config/peppercheck/github-secrets in sync with template
# updates, run scripts/sync-github-secrets.sh.

set -euo pipefail

SECRETS_FILE="${1:-${HOME}/.config/peppercheck/github-secrets}"

if [[ ! -f "$SECRETS_FILE" ]]; then
  echo "Error: $SECRETS_FILE not found."
  echo "Copy scripts/github-secrets.example to ~/.config/peppercheck/github-secrets and fill in the values."
  echo "(Legacy scripts/github-secrets path was moved out of the repo; mkdir -p ~/.config/peppercheck && chmod 700 ~/.config/peppercheck && mv scripts/github-secrets ~/.config/peppercheck/github-secrets && chmod 600 ~/.config/peppercheck/github-secrets if migrating.)"
  exit 1
fi

# Check gh CLI is available
if ! command -v gh &>/dev/null; then
  echo "Error: gh CLI not found. Install from https://cli.github.com/"
  exit 1
fi

# Verify gh is authenticated
if ! gh auth status &>/dev/null; then
  echo "Error: gh CLI not authenticated. Run 'gh auth login' first."
  exit 1
fi

echo "Setting GitHub Secrets from $SECRETS_FILE..."
echo ""

count=0
errors=0

while IFS= read -r line; do
  # Skip comments and blank lines
  [[ "$line" =~ ^[[:space:]]*# ]] && continue
  [[ -z "${line// /}" ]] && continue

  # Parse key=value
  key="${line%%=*}"
  value="${line#*=}"

  # Skip if no value
  if [[ -z "$value" ]]; then
    echo "  SKIP  $key (empty value)"
    continue
  fi

  # Set the secret
  if printf '%s' "$value" | gh secret set "$key" 2>/dev/null; then
    echo "  SET   $key"
    ((count++))
  else
    echo "  FAIL  $key"
    ((errors++))
  fi
done < "$SECRETS_FILE"

echo ""
echo "Done: $count secrets set, $errors errors."
echo ""
echo "Remaining manual steps (binary/file secrets — see scripts/github-secrets.example for details):"
echo "  # Android upload keystore"
echo "  base64 < /path/to/upload-keystore.jks | gh secret set ANDROID_KEYSTORE_BASE64"
echo ""
echo "  # Sets 4 secrets at once:"
echo "  #   BETA_FIREBASE_SERVICE_ACCOUNT_JSON  (verbatim contents of the SA JSON)"
echo "  #   BETA_FIREBASE_APP_ID                (auto-resolved via firebase apps:list)"
echo "  #   BETA_GOOGLE_SERVICES_JSON           (staging Android Firebase config)"
echo "  #   PROD_GOOGLE_SERVICES_JSON           (production Android Firebase config)"
echo "  # Pre-req: scripts/setup/bootstrap-peppercheck-staging-sa.sh produced the SA JSON"
echo "  # and scripts/setup/register-firebase-apps.sh {staging,production} populated"
echo "  # the per-flavor google-services.json files locally."
echo "  scripts/setup/setup-deploy-secrets.sh ~/.config/peppercheck/peppercheck-staging-sa.json"
echo ""
echo "  # Production-side service account (FCM only)"
echo "  gh secret set PROD_FIREBASE_SERVICE_ACCOUNT_JSON < /path/to/peppercheck-sa.json"
echo ""
echo "  # Google Play Developer API service accounts (RTDN)"
echo "  gh secret set BETA_GOOGLE_PLAY_SERVICE_ACCOUNT_JSON < /path/to/play-developer-sa.json"
echo "  gh secret set PROD_GOOGLE_PLAY_SERVICE_ACCOUNT_JSON < /path/to/play-developer-sa.json"
echo ""
echo "Verify with: gh secret list"
