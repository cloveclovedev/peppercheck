#!/usr/bin/env bash
# Wire the iOS "Sign in with Apple" capability into the Flutter Runner project
# WITHOUT touching the fragile project.pbxproj or needing the xcodeproj gem.
#
# How: create a shared Runner.entitlements declaring com.apple.developer.applesignin,
# then point CODE_SIGN_ENTITLEMENTS at it from each flavor's base xcconfig
# (Dev/Staging/Production.xcconfig) — each is #included by that flavor's
# Debug/Profile/Release configs, so all 9 build configurations pick it up.
#
# This is the PROJECT side only. You must ALSO enable "Sign in with Apple" on
# each App ID in the Apple Developer portal (and the Firebase Apple provider)
# before a *signed* build/upload will succeed — see
# docs/operations/phase2-auth-operator-checklist.md steps 4-6.
#
# Idempotent: safe to re-run. Prints a diff-style summary of what it changed.
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
IOS_DIR="$REPO_ROOT/peppercheck_flutter/ios"
ENTITLEMENTS="$IOS_DIR/Runner/Runner.entitlements"
FLAVOR_CONFIGS=(
  "$IOS_DIR/Flutter/Dev.xcconfig"
  "$IOS_DIR/Flutter/Staging.xcconfig"
  "$IOS_DIR/Flutter/Production.xcconfig"
)
ENTITLEMENTS_SETTING='CODE_SIGN_ENTITLEMENTS = Runner/Runner.entitlements'

changed=0

# 1) Create the shared entitlements file (only the Apple capability; push/other
#    managed capabilities are left to Xcode automatic signing).
if [ -f "$ENTITLEMENTS" ]; then
  if grep -q 'com.apple.developer.applesignin' "$ENTITLEMENTS"; then
    echo "= $ENTITLEMENTS already declares applesignin (unchanged)"
  else
    echo "! $ENTITLEMENTS exists but has NO applesignin key."
    echo "  Add this to its top-level <dict> manually, then re-run:"
    echo '    <key>com.apple.developer.applesignin</key><array><string>Default</string></array>'
    exit 1
  fi
else
  cat > "$ENTITLEMENTS" <<'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
	<key>com.apple.developer.applesignin</key>
	<array>
		<string>Default</string>
	</array>
</dict>
</plist>
PLIST
  echo "+ created $ENTITLEMENTS"
  changed=1
fi

# 2) Point each flavor base xcconfig at the entitlements file.
for cfg in "${FLAVOR_CONFIGS[@]}"; do
  if [ ! -f "$cfg" ]; then
    echo "! missing expected xcconfig: $cfg" >&2
    exit 1
  fi
  if grep -q '^[[:space:]]*CODE_SIGN_ENTITLEMENTS[[:space:]]*=' "$cfg"; then
    echo "= $(basename "$cfg") already sets CODE_SIGN_ENTITLEMENTS (unchanged)"
  else
    printf '\n// Sign in with Apple capability (shared entitlements, all build configs)\n%s\n' \
      "$ENTITLEMENTS_SETTING" >> "$cfg"
    echo "+ appended CODE_SIGN_ENTITLEMENTS to $(basename "$cfg")"
    changed=1
  fi
done

echo
if [ "$changed" -eq 1 ]; then
  echo "Done. Review the changes:  git -C '$REPO_ROOT' diff -- peppercheck_flutter/ios"
else
  echo "Nothing to change — already wired."
fi
cat <<'NEXT'

Next (operator, before a signed build/TestFlight upload):
  1. Apple Developer portal -> Identifiers -> each App ID
     (dev.cloveclove.peppercheck[.dev|.staging]) -> enable "Sign in with Apple".
  2. Firebase console -> each project -> Authentication -> Sign-in method ->
     enable Apple (Services ID + key).  (see the operator checklist doc)
  3. Sanity-check the project side compiles (no signing needed):
       cd peppercheck_flutter && flutter build ios --no-codesign --flavor dev -t lib/main_dev.dart
  4. Then a signed build on a real device to verify Apple sign-in end-to-end.
NEXT
