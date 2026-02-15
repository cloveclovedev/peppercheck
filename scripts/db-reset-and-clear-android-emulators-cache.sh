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
  echo "  Clearing $PACKAGE_NAME on $device..."
  adb -s "$device" shell pm clear "$PACKAGE_NAME"
done

echo "==> Done!"
