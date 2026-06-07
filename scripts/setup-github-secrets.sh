#!/usr/bin/env bash
# Set GitHub Secrets for peppercheck CI/CD from a config file.
#
# Usage:
#   ./scripts/setup-github-secrets.sh                    # uses scripts/github-secrets
#   ./scripts/setup-github-secrets.sh path/to/file       # uses custom file
#
# Binary/file secrets must be set separately. The full list of file-style
# secrets and their gh-secret-set invocations is documented at the bottom
# of scripts/github-secrets.example. This script also prints a summary
# after the text-secret pass.

set -euo pipefail

SECRETS_FILE="${1:-scripts/github-secrets}"

if [[ ! -f "$SECRETS_FILE" ]]; then
  echo "Error: $SECRETS_FILE not found."
  echo "Copy scripts/github-secrets.example to scripts/github-secrets and fill in the values."
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
echo "  # Phase 1 Firebase + Android per-flavor secrets (after bootstrap-peppercheck-staging-sa.sh):"
echo "  scripts/setup/setup-deploy-secrets.sh ~/.config/peppercheck-secrets/peppercheck-staging-sa.json"
echo ""
echo "  # Phase 1 production-side service account (FCM only)"
echo "  gh secret set PROD_FIREBASE_SERVICE_ACCOUNT_JSON < /path/to/peppercheck-sa.json"
echo ""
echo "  # Google Play Developer API service accounts (RTDN)"
echo "  gh secret set BETA_GOOGLE_PLAY_SERVICE_ACCOUNT_JSON < /path/to/play-developer-sa.json"
echo "  gh secret set PROD_GOOGLE_PLAY_SERVICE_ACCOUNT_JSON < /path/to/play-developer-sa.json"
echo ""
echo "Verify with: gh secret list"
