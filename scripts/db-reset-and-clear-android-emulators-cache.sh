#!/bin/bash
set -euo pipefail

PACKAGE_NAME="dev.cloveclove.peppercheck"

echo "==> Resetting Supabase database..."
supabase db reset

echo "==> Clearing app data on all Android emulators..."
emulators=$(adb devices | grep emulator | cut -f1)

if [ -z "$emulators" ]; then
  echo "No running emulators found. Skipping cache clear."
  exit 0
fi

for device in $emulators; do
  if ! adb -s "$device" shell pm list packages | grep -q "$PACKAGE_NAME"; then
    echo "  $PACKAGE_NAME is not installed on $device. Skipping."
    continue
  fi
  echo "  Clearing $PACKAGE_NAME on $device..."
  adb -s "$device" shell pm clear "$PACKAGE_NAME"
done

echo "==> Done!"
