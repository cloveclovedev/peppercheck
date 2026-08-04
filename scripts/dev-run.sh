#!/usr/bin/env bash
# One-shot local dev stack for hands-on Firebase auth testing (macOS, primary
# worktree / single stack). For running several isolated backends in parallel
# worktrees, use scripts/worktree/dev.sh instead — see docs/development/git-worktrees.md.
#   1. ensures the backend (Go api + Postgres + Caddy) is up via docker compose,
#      pinning FIREBASE_PROJECT_ID so real Firebase tokens verify, and waits
#      until GET /api/v1/me responds
#   2. boots the iOS Simulator or Android emulator (Android: also checks
#      /data free space and trims app caches if it's tight — the default AVD
#      data partition is only 6G, and Play Store/GMS auto-updates plus repeat
#      debug-build reinstalls can fill it, failing the install with
#      INSTALL_FAILED_INSUFFICIENT_STORAGE)
#   3. execs the Flutter dev flavor in the foreground (interactive hot reload:
#      press r / R / q) — one platform at a time
#
# Backend handling:
#   --ios / --android      ensure the backend is up (start it only if it is not
#                          already answering on --caddy-port), then run the app
#   --backend              force `make up` (rebuild changed images + recreate
#                          changed containers) — use after editing backend code
#   --backend --android    rebuild/restart the backend AND run the app, one shot
#   --backend              (alone) bring the backend up without running an app
#   --bws                  inject real dev secrets (currently R2 credentials)
#                          from Bitwarden Secrets Manager instead of the .env
#                          dummies — see docs/development/bws-development.md.
#                          Off by default: most flows don't need it, and a
#                          fresh clone with no Bitwarden access should always
#                          work. Forces a backend restart even if one is
#                          already running, since secrets are injected only
#                          at `docker compose up` time.
# For a full reset incl. the local DB, use `cd backend && make reset` instead.
#
# --build compiles a debug Android APK (JDK pin + --flavor dev) as a
# non-interactive compile check — no backend, no emulator. Use it (rather than a
# bare `flutter build apk`) so the JDK-21 pin and flavor are always applied.
#
# Usage (pass at least one of --backend, --ios, --android, --build; --build is standalone):
#   scripts/dev-run.sh --android             # ensure backend, run Android
#   scripts/dev-run.sh --ios                 # ensure backend, run iOS
#   scripts/dev-run.sh --backend             # (re)build/restart backend only
#   scripts/dev-run.sh --backend --android   # rebuild backend, then run Android
#   scripts/dev-run.sh --backend --bws       # restart backend with real bws dev secrets
#   scripts/dev-run.sh --build               # Android debug APK compile check
#   scripts/dev-run.sh --avd NAME            # Android AVD (default below; see: flutter emulators)
#   scripts/dev-run.sh --caddy-port N        # host ingress port (default 80) when 80 is taken
#   scripts/dev-run.sh --postgres-port N     # host Postgres port (default 5432) when 5432 is taken
#   scripts/dev-run.sh --firebase-project ID # api token audience (default peppercheck-dev)
#
# Interactive hot reload works only when you run this yourself in a terminal:
# it execs `flutter run` in the foreground. An agent invoking it as a captured
# command cannot relay keystrokes — let a human drive the app, or use
# `scripts/dev-run.sh --build` for a compile check.
#
# --caddy-port is the single source of truth for the ingress: it publishes the
# backend Caddy on that host port AND tells the app (via --dart-define) to use
# it, so both always agree. See docs/operations/local-ports.md for the port map.
set -euo pipefail

REPO="$(cd "$(dirname "$0")/.." && pwd)"
FLUTTER_DIR="$REPO/peppercheck_flutter"
BACKEND_DIR="$REPO/backend"
FLUTTER_RUN_BASE="flutter run --flavor dev -t lib/main_dev.dart"

RUN_IOS=0 RUN_ANDROID=0 FORCE_BACKEND=0 DO_BUILD=0 USE_BWS=0
AVD="Medium_Phone_API_36.1"
FIREBASE_PROJECT="peppercheck-dev"
CADDY_PORT=80       # host ingress port (backend CADDY_HTTP_PORT + app DEV_API_PORT)
PG_PORT=5432        # host Postgres port (backend POSTGRES_HOST_PORT), host tools only

while [ $# -gt 0 ]; do
  case "$1" in
    --ios)      RUN_IOS=1 ;;
    --android)  RUN_ANDROID=1 ;;
    --backend)  FORCE_BACKEND=1 ;;
    --bws)      USE_BWS=1 ;;
    --build)    DO_BUILD=1 ;;
    --avd)      AVD="${2:?}"; shift ;;
    --caddy-port)    CADDY_PORT="${2:?}"; shift ;;
    --postgres-port) PG_PORT="${2:?}"; shift ;;
    --firebase-project) FIREBASE_PROJECT="${2:?}"; shift ;;
    -h|--help)  sed -n '2,56p' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;;
    *) echo "unknown arg: $1" >&2; exit 2 ;;
  esac
  shift
done
[ "$RUN_IOS" -eq 1 ] || [ "$RUN_ANDROID" -eq 1 ] || [ "$FORCE_BACKEND" -eq 1 ] || [ "$DO_BUILD" -eq 1 ] || {
  echo "specify at least one of --backend, --ios, --android, --build" >&2; exit 2
}
if [ "$DO_BUILD" -eq 1 ] && { [ "$RUN_IOS" -eq 1 ] || [ "$RUN_ANDROID" -eq 1 ] || [ "$FORCE_BACKEND" -eq 1 ]; }; then
  echo "--build is a standalone Android compile check; don't combine it with --backend/--ios/--android" >&2
  exit 2
fi
if [ "$RUN_IOS" -eq 1 ] && [ "$RUN_ANDROID" -eq 1 ]; then
  echo "run one platform at a time (--ios or --android): flutter run holds the terminal for hot reload" >&2
  exit 2
fi

# The ingress port is the single source of truth: the backend publishes Caddy
# on it and the app is told the same value, so they always agree.
API_HEALTH_URL="http://127.0.0.1:${CADDY_PORT}/api/v1/me"
FLUTTER_RUN="$FLUTTER_RUN_BASE --dart-define=DEV_API_PORT=$CADDY_PORT"

IOS_DEVICE="" ANDROID_DEVICE=""

backend_healthy() { # true only for the PepperCheck API's expected unauthenticated 401
  # A bare 2xx/3xx/4xx isn't enough: Caddy up but the api down returns 502, and
  # an unrelated service on this port could return anything. Require the exact
  # 401 that GET /api/v1/me gives without a token so we never skip startup for,
  # or launch the app against, a broken or unrelated backend.
  [ "$(curl -s -o /dev/null -w '%{http_code}' "$API_HEALTH_URL" 2>/dev/null || true)" = "401" ]
}

ensure_backend() { # idempotent: start the backend only if it is not already up.
  # --bws always restarts even if a backend is already up: bws secrets are
  # injected only at `docker compose up` time, so an already-running backend
  # (started without --bws) would otherwise silently keep the .env dummies.
  if [ "$USE_BWS" -eq 0 ] && backend_healthy; then
    echo "==> Backend already up on :$CADDY_PORT (skipping; pass --backend to rebuild/restart)"
    return 0
  fi
  start_backend
}

start_backend() {
  local bws_project_id="" bws_note=""
  if [ "$USE_BWS" -eq 1 ]; then
    bws_project_id="auto"
    bws_note=", bws dev secrets"
  fi
  echo "==> Starting backend (FIREBASE_PROJECT_ID=$FIREBASE_PROJECT, Caddy :$CADDY_PORT, Postgres :$PG_PORT$bws_note)"
  if ! ( cd "$BACKEND_DIR" \
      && FIREBASE_PROJECT_ID="$FIREBASE_PROJECT" \
         CADDY_HTTP_PORT="$CADDY_PORT" POSTGRES_HOST_PORT="$PG_PORT" \
         BWS_PROJECT_ID="$bws_project_id" make up ); then
    echo
    echo "backend failed to start. If compose reported a missing variable"
    echo "(e.g. API_PORT), your backend/.env predates a template change and"
    echo "make up won't overwrite it. Refresh it (values are throwaway dev-only)"
    echo "and retry:   cp backend/.env.example backend/.env"
    exit 1
  fi
  printf '==> Waiting for %s ' "$API_HEALTH_URL"
  for i in $(seq 1 60); do
    if backend_healthy; then
      printf ' ready (HTTP 401 as expected)\n'; return 0
    fi
    printf '.'; sleep 2
  done
  printf ' TIMEOUT\n'; echo "backend not responding — check: (cd backend && make logs)"; exit 1
}

# Local Android builds pin JDK 21: the pinned Gradle 8.14 + AGP 8.11 toolchain
# can't run on the JDK 25/26 that Android Studio / Homebrew now ship (KT-83610),
# and Flutter uses Android Studio's bundled JBR unless --jdk-dir overrides it.
# See docs/development/flutter/android-jdk.md.
# AGP 8.11 requires JDK 17+, and the pinned Gradle 8.14 can't run on JDK 22+,
# so a usable Android build JDK must be in the 17-21 range.
ANDROID_JDK_MIN=17
ANDROID_JDK_MAX=21

jdk_major() { # $1 = JDK home; echoes the major version (e.g. 21), or nothing
  "$1/bin/java" -version 2>&1 | sed -n '1s/.*version "\([0-9][0-9]*\).*/\1/p'
}

jdk_supported() { # $1 = major version; true when within [ANDROID_JDK_MIN, ANDROID_JDK_MAX]
  [ -n "$1" ] && [ "$1" -ge "$ANDROID_JDK_MIN" ] && [ "$1" -le "$ANDROID_JDK_MAX" ]
}

compatible_jdk() { # echoes a JDK home whose major is in the supported range, or nothing
  local c
  for c in \
    "$(brew --prefix openjdk@21 2>/dev/null)/libexec/openjdk.jdk/Contents/Home" \
    "$(brew --prefix openjdk@17 2>/dev/null)/libexec/openjdk.jdk/Contents/Home" \
    "$(/usr/libexec/java_home -v 21 2>/dev/null)" \
    "$(/usr/libexec/java_home -v 17 2>/dev/null)"; do
    [ -x "$c/bin/java" ] || continue
    jdk_supported "$(jdk_major "$c")" && { echo "$c"; return 0; }
  done
  return 1
}

ensure_android_jdk() {
  local configured major jdk
  configured="$(flutter config --machine 2>/dev/null \
    | sed -n 's/.*"jdk-dir"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p')"
  if [ -n "$configured" ] && [ -x "$configured/bin/java" ]; then
    major="$(jdk_major "$configured")"
    if jdk_supported "$major"; then
      echo "==> Android build JDK: $configured (JDK $major, via flutter --jdk-dir)"
      return 0
    fi
    echo "==> Flutter's configured JDK ($configured, JDK ${major:-?}) is outside the supported ${ANDROID_JDK_MIN}-${ANDROID_JDK_MAX} range for the pinned Gradle 8.14 + AGP 8.11 toolchain."
  fi
  if jdk="$(compatible_jdk)"; then
    echo "==> Pinning Flutter Android build JDK to $jdk"
    echo "    (reset with: flutter config --jdk-dir=\"\"; see docs/development/flutter/android-jdk.md)"
    flutter config --jdk-dir="$jdk" >/dev/null
  else
    cat >&2 <<'EOF'
==> No JDK 17 or 21 found. The pinned Gradle 8.14 + AGP 8.11 toolchain cannot run
    on the JDK 25/26 that Android Studio / Homebrew now ship. Install one and retry:
        brew install openjdk@21
    See docs/development/flutter/android-jdk.md for the full rationale.
EOF
    exit 1
  fi
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
  ensure_android_storage
}

# APK install fails with INSTALL_FAILED_INSUFFICIENT_STORAGE on the small
# (6G) default AVD data partition once Play Store/GMS auto-updates and a few
# debug-build reinstalls accumulate. `pm trim-caches` is safe and reversible
# (it only reclaims cache, never app data or account state), so run it
# automatically; below that, freeing more space means removing app data,
# which is a per-developer call — print instructions instead of doing it.
ANDROID_STORAGE_MIN_KB=1048576 # 1G headroom for the APK + Gradle install overhead

ensure_android_storage() {
  local avail
  avail="$(adb -s "$ANDROID_DEVICE" shell df /data 2>/dev/null \
    | awk 'NR==2 {print $4}' | tr -d '\r')"
  [ -n "$avail" ] || return 0 # df parsing failed; don't block on a soft check
  if [ "$avail" -ge "$ANDROID_STORAGE_MIN_KB" ]; then
    return 0
  fi
  echo "==> Low storage on $ANDROID_DEVICE ($((avail / 1024))M free on /data) — trimming app caches"
  adb -s "$ANDROID_DEVICE" shell pm trim-caches 4G >/dev/null 2>&1 || true
  avail="$(adb -s "$ANDROID_DEVICE" shell df /data 2>/dev/null \
    | awk 'NR==2 {print $4}' | tr -d '\r')"
  [ -n "$avail" ] && [ "$avail" -ge "$ANDROID_STORAGE_MIN_KB" ] && {
    echo "    freed enough via cache trim ($((avail / 1024))M free now)"; return 0
  }
  cat >&2 <<EOF
    still low on space ($((avail / 1024))M free) after trimming caches.
    Free more by removing non-essential preinstalled apps for this user only
    (reversible with 'pm install-existing <package>'; does not touch the
    signed-in Google account, which lives in com.google.android.gms):
      adb -s $ANDROID_DEVICE shell pm uninstall --user 0 com.google.android.youtube
      adb -s $ANDROID_DEVICE shell pm uninstall --user 0 com.google.android.apps.youtube.music
      adb -s $ANDROID_DEVICE shell pm uninstall --user 0 com.google.android.apps.maps
      adb -s $ANDROID_DEVICE shell pm uninstall --user 0 com.google.android.apps.photos
      adb -s $ANDROID_DEVICE shell pm uninstall --user 0 com.google.android.apps.docs
      adb -s $ANDROID_DEVICE shell pm uninstall --user 0 com.google.android.calendar
    If this AVD is chronically tight on space, its data partition is a small
    default (6G) — recreate it with a larger one via Android Studio's Device
    Manager or 'flutter emulators --create'.
EOF
}

# --- main ---
# --build: JDK-pinned, flavored debug APK compile check. No backend, no emulator.
if [ "$DO_BUILD" -eq 1 ]; then
  ensure_android_jdk
  cd "$FLUTTER_DIR"
  exec flutter build apk --debug --flavor dev -t lib/main_dev.dart
fi

# Fail fast on the Android JDK before touching the backend or emulator.
[ "$RUN_ANDROID" -eq 1 ] && ensure_android_jdk

# --backend forces a (re)build/restart; a bare platform run only ensures the
# backend is up (leaving an already-running one — and its data — untouched).
if [ "$FORCE_BACKEND" -eq 1 ]; then
  start_backend
elif [ "$RUN_IOS" -eq 1 ] || [ "$RUN_ANDROID" -eq 1 ]; then
  ensure_backend
fi

[ "$RUN_IOS" -eq 1 ] && boot_ios
[ "$RUN_ANDROID" -eq 1 ] && boot_android

# exec into the interactive foreground flutter run (hot reload: r / R / q).
if [ "$RUN_IOS" -eq 1 ]; then
  cd "$FLUTTER_DIR"; exec $FLUTTER_RUN -d "$IOS_DEVICE"
elif [ "$RUN_ANDROID" -eq 1 ]; then
  cd "$FLUTTER_DIR"; exec $FLUTTER_RUN -d "$ANDROID_DEVICE"
else
  echo "==> Backend ready on :$CADDY_PORT. Run the app with: scripts/dev-run.sh --android | --ios"
fi
