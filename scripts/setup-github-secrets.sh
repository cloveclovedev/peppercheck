#!/usr/bin/env bash
# Set GitHub Secrets for peppercheck CI/CD from a config file.
#
# Usage:
#   ./scripts/setup-github-secrets.sh                    # uses scripts/github-secrets
#   ./scripts/setup-github-secrets.sh path/to/file       # uses custom file
#
# Binary/file secrets must be set separately:
#   base64 < /path/to/upload-keystore.jks | gh secret set ANDROID_KEYSTORE_BASE64
#   gh secret set FIREBASE_SERVICE_ACCOUNT_JSON < /path/to/firebase-service-account.json

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
echo "Remaining manual steps:"
echo "  base64 < /path/to/upload-keystore.jks | gh secret set ANDROID_KEYSTORE_BASE64"
echo "  gh secret set FIREBASE_SERVICE_ACCOUNT_JSON < /path/to/firebase-service-account.json"
echo ""
echo "Verify with: gh secret list"
