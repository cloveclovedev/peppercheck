#!/bin/bash
# Bootstrap ios/Flutter/Secrets/*.secrets.xcconfig with the production OAuth client ID.
# All three flavors share the production client until per-env OAuth clients land in #427;
# expect dev/staging Google Sign-In to fail with a bundle-ID mismatch until then.
set -euo pipefail
cd "$(dirname "$0")/../../peppercheck_flutter/ios/Flutter"
mkdir -p Secrets

GID_CLIENT_ID="768821537635-ltijulfn8brsvv3lm7fe5b51s3i1up6r.apps.googleusercontent.com"
GID_REVERSED="com.googleusercontent.apps.768821537635-ltijulfn8brsvv3lm7fe5b51s3i1up6r"

for FLAVOR in Dev Staging Production; do
  cat > "Secrets/$FLAVOR.secrets.xcconfig" <<EOF
GID_CLIENT_ID = $GID_CLIENT_ID
GID_REVERSED_CLIENT_ID = $GID_REVERSED
EOF
done
echo "Wrote 3 secrets xcconfigs in $(pwd)/Secrets/"
