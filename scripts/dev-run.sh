#!/usr/bin/env bash
# One-shot local dev stack for hands-on Phase 2 auth testing (macOS).
#   1. starts the backend (Go api + Postgres + Caddy) via docker compose,
#      pinning FIREBASE_PROJECT_ID so real Firebase tokens verify, and waits
#      until GET /api/v1/me responds
#   2. boots the iOS Simulator and/or an Android emulator
#   3. runs the Flutter dev flavor on each — a single platform runs in the
#      foreground (interactive hot reload); both platforms each get their own
#      Terminal window so hot reload keeps working in each
#
# Usage:
#   scripts/dev-run.sh                       # both iOS + Android (default)
#   scripts/dev-run.sh --ios                 # iOS only
#   scripts/dev-run.sh --android             # Android only
#   scripts/dev-run.sh --no-backend          # skip starting the backend
#   scripts/dev-run.sh --avd NAME            # Android AVD (default below; see: flutter emulators)
#   scripts/dev-run.sh --firebase-project ID # api token audience (default peppercheck-dev)
set -euo pipefail

REPO="$(cd "$(dirname "$0")/.." && pwd)"
FLUTTER_DIR="$REPO/peppercheck_flutter"
BACKEND_DIR="$REPO/backend"
API_HEALTH_URL="http://127.0.0.1/api/v1/me"
FLUTTER_RUN="flutter run --flavor dev -t lib/main_dev.dart"

RUN_IOS=0 RUN_ANDROID=0 EXPLICIT=0 START_BACKEND=1
AVD="Medium_Phone_API_36.1"
FIREBASE_PROJECT="peppercheck-dev"

while [ $# -gt 0 ]; do
  case "$1" in
    --ios)      RUN_IOS=1; EXPLICIT=1 ;;
    --android)  RUN_ANDROID=1; EXPLICIT=1 ;;
    --no-backend) START_BACKEND=0 ;;
    --avd)      AVD="${2:?}"; shift ;;
    --firebase-project) FIREBASE_PROJECT="${2:?}"; shift ;;
    -h|--help)  sed -n '2,20p' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;;
    *) echo "unknown arg: $1" >&2; exit 2 ;;
  esac
  shift
done
[ "$EXPLICIT" -eq 1 ] || { RUN_IOS=1; RUN_ANDROID=1; }

IOS_DEVICE="" ANDROID_DEVICE=""

start_backend() {
  echo "==> Starting backend (FIREBASE_PROJECT_ID=$FIREBASE_PROJECT)"
  if ! ( cd "$BACKEND_DIR" && FIREBASE_PROJECT_ID="$FIREBASE_PROJECT" make up ); then
    echo
    echo "backend failed to start. If compose reported a missing variable"
    echo "(e.g. API_PORT), your backend/.env predates a template change and"
    echo "make up won't overwrite it. Refresh it (values are throwaway dev-only)"
    echo "and retry:   cp backend/.env.example backend/.env"
    exit 1
  fi
  printf '==> Waiting for %s ' "$API_HEALTH_URL"
  for i in $(seq 1 60); do
    code="$(curl -s -o /dev/null -w '%{http_code}' "$API_HEALTH_URL" || true)"
    if [ -n "$code" ] && [ "$code" != "000" ]; then
      printf ' ready (HTTP %s — 401 is expected)\n' "$code"; return 0
    fi
    printf '.'; sleep 2
  done
  printf ' TIMEOUT\n'; echo "backend not responding — check: (cd backend && make logs)"; exit 1
}

boot_ios() {
  echo "==> Booting iOS Simulator"
  open -a Simulator || true
  for i in $(seq 1 20); do
    IOS_DEVICE="$(xcrun simctl list devices booted 2>/dev/null | grep -Eo '[0-9A-Fa-f-]{36}' | head -1 || true)"
    [ -n "$IOS_DEVICE" ] && { echo "    iOS device: $IOS_DEVICE"; return 0; }
    [ "$i" -eq 5 ] && { flutter emulators --launch apple_ios_simulator >/dev/null 2>&1 || true; }
    sleep 2
  done
  echo "    No booted iOS simulator. Open one in Simulator.app, then retry." >&2; exit 1
}

boot_android() {
  command -v adb >/dev/null || { echo "adb not found (Android SDK platform-tools not on PATH)"; exit 1; }
  ANDROID_DEVICE="$(adb devices | awk '$2=="device" && $1 ~ /^emulator-/ {print $1; exit}')"
  if [ -z "$ANDROID_DEVICE" ]; then
    echo "==> Launching Android emulator ($AVD)"
    flutter emulators --launch "$AVD" >/dev/null 2>&1 \
      || { echo "could not launch AVD '$AVD' (see: flutter emulators)"; exit 1; }
  fi
  printf '==> Waiting for Android boot '
  adb wait-for-device
  for i in $(seq 1 60); do
    [ "$(adb shell getprop sys.boot_completed 2>/dev/null | tr -d '\r')" = "1" ] && break
    printf '.'; sleep 2
  done
  ANDROID_DEVICE="$(adb devices | awk '$2=="device" && $1 ~ /^emulator-/ {print $1; exit}')"
  printf ' ready (%s)\n' "$ANDROID_DEVICE"
}

open_terminal() { # $1 = shell command to run in a new Terminal window
  osascript >/dev/null <<OSA
tell application "Terminal"
  activate
  do script "$1"
end tell
OSA
}

run_in_dir() { echo "cd '$FLUTTER_DIR' && $FLUTTER_RUN -d $1"; }

# --- main ---
[ "$START_BACKEND" -eq 1 ] && start_backend
[ "$RUN_IOS" -eq 1 ] && boot_ios
[ "$RUN_ANDROID" -eq 1 ] && boot_android

if [ "$RUN_IOS" -eq 1 ] && [ "$RUN_ANDROID" -eq 1 ]; then
  echo "==> Launching both platforms in separate Terminal windows"
  open_terminal "$(run_in_dir "$IOS_DEVICE")"
  open_terminal "$(run_in_dir "$ANDROID_DEVICE")"
  cat <<DONE
Two Terminal windows opened (iOS + Android); press 'r' in each for hot reload.
Backend stays up; stop it with:  (cd backend && make down)
DONE
elif [ "$RUN_IOS" -eq 1 ]; then
  cd "$FLUTTER_DIR"; exec $FLUTTER_RUN -d "$IOS_DEVICE"
else
  cd "$FLUTTER_DIR"; exec $FLUTTER_RUN -d "$ANDROID_DEVICE"
fi
